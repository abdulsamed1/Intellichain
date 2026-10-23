// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {GetGiftBase} from "../utilites/GetGift.utils.t.sol";
import {GetGift} from "../../src/GetGift.sol";

/// @dev has runtime code but implements no ERC-721 receiver hook: OZ's
/// safeMint acceptance check reverts — the exact recipient-contract case
/// that used to brick the fulfillment invariant
contract NoReceiverContract {
    uint256 public junk = 1; // forces code at the address
}

/**
 * @title GetGiftShieldTest
 * @notice Fulfillment shield + stuck-request recovery (final-review fix pass)
 * @dev The Router consumes a pending Functions request even when the consumer
 *      callback reverts, and its rollback undoes EVERY change in
 *      fulfillRequest — so before the shield, one reverting receiver or one
 *      malformed response left requestIdInFlight stuck true and the claimed
 *      code burned forever.
 */
contract GetGiftShieldTest is GetGiftBase {
    // Mirror of the GetGift events asserted with vm.expectEmit (sig-matched)
    event GiftRedeemed(
        bytes32 indexed requestId, address indexed recipient, string giftCode, string giftName, uint256 indexed tokenId
    );
    event GiftCodeReleased(string giftCode);
    event FulfillmentFailed(bytes32 indexed requestId, bytes reason);

    function _requestFor(address recipient) internal returns (bytes32 id, string[] memory a) {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        a = new string[](1);
        a[0] = validGiftCode;
        id = getGift.sendRequest(1, 1, a, SUBSCRIPTION_ID, recipient);
        vm.stopPrank();
    }

    /// @notice A recipient contract that reverts in the ERC-721 receiver check
    /// must NOT brick fulfillment: the handler succeeds, the code is released,
    /// no token is minted and the invariant is cleared
    function test_Fulfillment_RevertingReceiverDoesNotBrickHandler() public {
        address receiver = address(new NoReceiverContract());
        (bytes32 reqId,) = _requestFor(receiver);

        vm.startPrank(ROUTER_ADDR);
        // reason data is the receiver's/decode's revert blob: sig-only match
        vm.expectEmit(true, true, true, false);
        emit FulfillmentFailed(reqId, "");
        vm.expectEmit(true, true, true, true);
        emit GiftCodeReleased(validGiftCode);
        getGift.handleOracleFulfillment(reqId, abi.encode("100 discount"), new bytes(0));
        vm.stopPrank();

        assertEq(getGift.tokenId(), 0);
        assertFalse(getGift.requestIdInFlight());
    }

    /// @notice After a shielded release the same code is claimable again
    function test_Fulfillment_ReleasedCodeAfterShieldIsReRequestable() public {
        address receiver = address(new NoReceiverContract());
        (bytes32 reqId, string[] memory a) = _requestFor(receiver);

        vm.startPrank(ROUTER_ADDR);
        getGift.handleOracleFulfillment(reqId, abi.encode("100 discount"), new bytes(0));
        vm.stopPrank();

        vm.startPrank(user);
        bytes32 retryId = getGift.sendRequest(1, 1, a, SUBSCRIPTION_ID, user);
        assertTrue(retryId != bytes32(0));
        vm.stopPrank();
    }

    /// @notice A malformed oracle response (no error, undecodable response)
    /// used to revert the handler wholesale — now it releases the code
    function test_Fulfillment_MalformedResponseDoesNotBrickHandler() public {
        (bytes32 reqId, string[] memory a) = _requestFor(user);

        // both empty -> err path misses, "not found" check misses, decode
        // of a uint256 payload as string reverts inside the shield
        vm.startPrank(ROUTER_ADDR);
        getGift.handleOracleFulfillment(reqId, abi.encode(uint256(7)), new bytes(0));
        vm.stopPrank();

        assertEq(getGift.tokenId(), 0);
        assertFalse(getGift.requestIdInFlight());

        vm.startPrank(user);
        bytes32 retryId = getGift.sendRequest(1, 1, a, SUBSCRIPTION_ID, user);
        assertTrue(retryId != bytes32(0));
        vm.stopPrank();
    }

    /// @notice A code released by the shield cannot be stolen by a late
    /// fulfillment replaying the same request id (bookkeeping was freed)
    function test_Fulfillment_LateReplayAfterReleaseCannotDoubleMint() public {
        address receiver = address(new NoReceiverContract());
        (bytes32 reqId, string[] memory a) = _requestFor(receiver);

        vm.startPrank(ROUTER_ADDR);
        getGift.handleOracleFulfillment(reqId, abi.encode("100 discount"), new bytes(0));
        vm.stopPrank();

        // retry claims the code again (fresh request, fresh bookkeeping) —
        // the shared mock router always returns id 1, so pin the retry to a
        // distinct id to keep replay semantics meaningful
        vm.mockCall(
            ROUTER_ADDR,
            abi.encodeWithSignature("sendRequest(uint64,bytes,uint16,uint32,bytes32)"),
            abi.encode(bytes32(uint256(2)))
        );
        vm.startPrank(user);
        bytes32 retryId = getGift.sendRequest(1, 1, a, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        // replaying the OLD fulfillment id reverts: its bookkeeping is gone
        vm.startPrank(ROUTER_ADDR);
        vm.expectRevert(abi.encodeWithSignature("UnexpectedRequestID(bytes32)", reqId));
        getGift.handleOracleFulfillment(reqId, abi.encode("100 discount"), new bytes(0));
        vm.stopPrank();
    }

    /// @notice When NOT in flight there is nothing stuck: revert explicitly
    function test_ResetStuckRequest_RevertsWhenNotStuck() public {
        vm.expectRevert(GetGift.RequestNotStuck.selector);
        vm.prank(owner);
        getGift.resetStuckRequest();
    }

    /// @notice Only allowlisted admins may reset
    function test_ResetStuckRequest_RevertsIfNotAllowlisted() public {
        vm.expectRevert(GetGift.CallerNotAllowlisted.selector);
        vm.prank(stranger);
        getGift.resetStuckRequest();
    }

    /// @notice Recovery: clears the invariant, releases the claimed code and
    /// invalidates the stuck request id so a late fulfillment cannot mint it
    function test_ResetStuckRequest_ReleasesCodeAndInvalidatesRequest() public {
        (bytes32 reqId, string[] memory a) = _requestFor(user);
        assertTrue(getGift.requestIdInFlight());

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit GiftCodeReleased(validGiftCode);
        getGift.resetStuckRequest();
        vm.stopPrank();

        assertFalse(getGift.requestIdInFlight());

        // the code is claimable again — pin the retry to a distinct id (the
        // shared mock router always returns id 1)
        vm.mockCall(
            ROUTER_ADDR,
            abi.encodeWithSignature("sendRequest(uint64,bytes,uint16,uint32,bytes32)"),
            abi.encode(bytes32(uint256(2)))
        );
        vm.startPrank(user);
        bytes32 retryId = getGift.sendRequest(1, 1, a, SUBSCRIPTION_ID, user);
        assertTrue(retryId != bytes32(0));
        vm.stopPrank();

        // a late fulfillment for the INVALIDATED request reverts: admin hatch
        // misuse (clearing a merely-pending request) cannot orphan a payment
        vm.startPrank(ROUTER_ADDR);
        vm.expectRevert(abi.encodeWithSignature("UnexpectedRequestID(bytes32)", reqId));
        getGift.handleOracleFulfillment(reqId, abi.encode("100 discount"), new bytes(0));
        vm.stopPrank();
    }
}
