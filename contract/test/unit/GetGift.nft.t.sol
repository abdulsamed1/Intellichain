// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {GetGiftBase} from "../utilites/GetGift.utils.t.sol";
import {GetGift} from "../../src/GetGift.sol";

/**
 * @title GetGiftNFTTest
 * @notice Tests for NFT-related functionality in GetGift contract
 */
contract GetGiftNFTTest is GetGiftBase {
    // Mirror of the GetGift event asserted with vm.expectEmit (sig-matched)
    event GiftAdded(string giftName, string tokenUri);

    /// @notice Admin registers a new gift type: a later fulfillment of that
    /// type mints with the newly registered metadata (previously it silently
    /// minted an empty-URI token)
    function test_AddGift_RegistersNewGiftType() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.expectEmit(true, true, true, true);
        emit GiftAdded("new item", "ipfs://new-item");
        getGift.addGift("new item", "ipfs://new-item");
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        uint256 expectedTokenId = getGift.tokenId();
        vm.startPrank(ROUTER_ADDR);
        getGift.handleOracleFulfillment(requestId, abi.encode("new item"), new bytes(0));
        vm.stopPrank();

        assertEq(getGift.ownerOf(expectedTokenId), user);
        assertEq(getGift.tokenURI(expectedTokenId), "ipfs://new-item");
    }

    /// @notice A gift definition without a name is rejected
    function test_AddGift_RevertIfEmptyName() public {
        vm.expectRevert(GetGift.InvalidGiftDefinition.selector);
        vm.prank(owner);
        getGift.addGift("", "ipfs://new-item");
    }

    /// @notice A gift definition without a token uri is rejected
    function test_AddGift_RevertIfEmptyUri() public {
        vm.expectRevert(GetGift.InvalidGiftDefinition.selector);
        vm.prank(owner);
        getGift.addGift("new item", "");
    }

    /// @notice Gift registry and redemption state are externally observable:
    /// the registered metadata getters return the defaults, and a claimed
    /// (in-flight) code reads redeemed=true until a failed fulfillment
    /// releases it (then false again)
    function test_GiftToTokenUri_PublicGetters() public {
        assertEq(getGift.giftToTokenUri(bytes("100 discount")), ITEM_1_METADATA);
        assertEq(getGift.giftToTokenUri(bytes("50 discount")), ITEM_2_METADATA);
        assertEq(getGift.giftToTokenUri(bytes("1-month premium")), ITEM_3_METADATA);

        assertFalse(getGift.giftCodeRedeemed(validGiftCode));

        vm.prank(owner);
        getGift.addToAllowList(user);
        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        assertTrue(getGift.giftCodeRedeemed(validGiftCode));

        vm.startPrank(ROUTER_ADDR);
        getGift.handleOracleFulfillment(requestId, new bytes(0), abi.encode("error"));
        vm.stopPrank();

        assertFalse(getGift.giftCodeRedeemed(validGiftCode));
    }

    function test_GetGiftCodeRedeemed() public {
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 reqId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes memory validResponse = abi.encode("100 discount");
        uint256 expectedTokenId = getGift.tokenId();

        vm.startPrank(ROUTER_ADDR);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, expectedTokenId);
        getGift.handleOracleFulfillment(reqId, validResponse, new bytes(0));
        vm.stopPrank();

        // Try to reuse the same code - should revert
        vm.startPrank(user);
        vm.expectRevert(GetGift.CodeAlreadyRedeemed.selector);
        getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();
    }

    function test_NFTMinting_AfterValidFulfillment() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        uint256 expectedTokenId = getGift.tokenId();
        vm.startPrank(ROUTER_ADDR);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, expectedTokenId);
        bytes memory response = abi.encode("100 discount");
        getGift.handleOracleFulfillment(requestId, response, new bytes(0));
        vm.stopPrank();

        assertEq(getGift.ownerOf(expectedTokenId), user);
        assertEq(getGift.tokenURI(expectedTokenId), ITEM_1_METADATA);
    }

    function test_NFTMinting_RevertIfInvalidGift() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        vm.startPrank(ROUTER_ADDR);
        bytes memory response = abi.encode("not found");
        getGift.handleOracleFulfillment(requestId, response, new bytes(0));
        vm.stopPrank();
    }

    function test_NFT_TokenURIMatchesGift() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        uint256 expectedTokenId = getGift.tokenId();
        vm.startPrank(ROUTER_ADDR);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, expectedTokenId);
        bytes memory response = abi.encode("100 discount");
        getGift.handleOracleFulfillment(requestId, response, new bytes(0));
        vm.stopPrank();

        assertEq(getGift.ownerOf(expectedTokenId), user);
        assertEq(getGift.tokenURI(expectedTokenId), ITEM_1_METADATA);
    }

    function test_NFT_BatchMinting() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        // First NFT
        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = "gift1";
        bytes32 reqId1 = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        uint256 expectedTokenId1 = getGift.tokenId();
        vm.startPrank(ROUTER_ADDR);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, expectedTokenId1);
        getGift.handleOracleFulfillment(reqId1, abi.encode("100 discount"), new bytes(0));
        vm.stopPrank();

        // Second NFT
        vm.startPrank(user);
        args[0] = "gift2";
        bytes32 reqId2 = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        uint256 expectedTokenId2 = getGift.tokenId();
        vm.startPrank(ROUTER_ADDR);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, expectedTokenId2);
        getGift.handleOracleFulfillment(reqId2, abi.encode("50 discount"), new bytes(0));
        vm.stopPrank();

        // Verify NFTs
        assertEq(getGift.ownerOf(expectedTokenId1), user);
        assertEq(getGift.ownerOf(expectedTokenId2), user);
        assertEq(getGift.tokenURI(expectedTokenId1), ITEM_1_METADATA);
        assertEq(getGift.tokenURI(expectedTokenId2), ITEM_2_METADATA);
    }
}
