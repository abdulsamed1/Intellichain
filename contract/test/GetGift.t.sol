// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {BaseTest} from "lib/chainlink/contracts/src/v0.8/functions/tests/v1_X/BaseTest.t.sol";
import {GetGift} from "../src/GetGift.sol";
import {FunctionsRequest} from "lib/chainlink/contracts/src/v0.8/functions/dev/v1_X/libraries/FunctionsRequest.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

abstract contract GetGiftTest is Test, BaseTest, IERC721 {
    GetGift internal s_getGift;
    uint64 internal s_subscriptionId = 1;
    bytes32 internal s_donId = "fun-avalanche-fuji-1";
    address internal constant SUPABASE_SIGNER = address(0x1234);
    string internal s_sourceCode = "return 'hello world';";

    function setUp() public virtual override {
        super.setUp();
        s_getGift = new GetGift();
        s_getGift.addToAllowList(OWNER_ADDRESS);
    }

    // ========================
    // 🔐 Access Control Tests
    // ========================

    function test_AddToAllowList_RestrictedToOwner() public {
        vm.startPrank(STRANGER_ADDRESS);
        vm.expectRevert("you do not have permission to call the function");
        s_getGift.addToAllowList(STRANGER_ADDRESS);
        vm.stopPrank();
    }

    function test_SendRequest_RestrictedToAllowlistedUser() public {
        vm.startPrank(STRANGER_ADDRESS);
        vm.expectRevert("the user is not in allow list");
        s_getGift.sendRequest(0, 0, new string[](1), s_subscriptionId, STRANGER_ADDRESS);
        vm.stopPrank();
    }

    // ========================
    // 🎁 Gift Code Redemption
    // ========================

    function test_SendRequest_InvalidArgs_Reverts() public {
        vm.startPrank(OWNER_ADDRESS);
        vm.expectRevert("args is empty");
        s_getGift.sendRequest(0, 0, new string[](0), s_subscriptionId, OWNER_ADDRESS);
        vm.stopPrank();
    }

    function test_GiftCodeRedeemed_OnceOnly() public {
        vm.startPrank(OWNER_ADDRESS);

        string[] memory args = new string[](1);
        args[0] = "gift-code-123";

        // First time should work
        s_getGift.sendRequest(0, 0, args, s_subscriptionId, OWNER_ADDRESS);
        assertTrue(!s_getGift.getgiftCodeRedeemed(args[0]));

        // Mock successful fulfillment
        bytes32 requestId = s_getGift.lastRequestId();
        bytes memory response = bytes("50 discount");
        bytes memory err = "";
        s_getGift.handleOracleFulfillment(requestId, response, err);

        // Should be marked as redeemed
        assertTrue(s_getGift.getgiftCodeRedeemed(args[0]));

        // Second attempt should revert
        vm.expectRevert("the code is redeemed");
        s_getGift.sendRequest(0, 0, args, s_subscriptionId, OWNER_ADDRESS);

        vm.stopPrank();
    }

    // ========================
    // 🧠 Chainlink Fulfillment
    // ========================

    function test_FulfillRequest_SuccessfulMint() public {
        vm.startPrank(OWNER_ADDRESS);

        string[] memory args = new string[](1);
        args[0] = "gift-code-456";

        s_getGift.sendRequest(0, 0, args, s_subscriptionId, OWNER_ADDRESS);
        bytes32 requestId = s_getGift.lastRequestId();

        bytes memory response = bytes("50 discount");
        bytes memory err = "";

        // Expect NFT minting
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), OWNER_ADDRESS, 0); // ERC721 mint event

        s_getGift.handleOracleFulfillment(requestId, response, err);

        assertEq(s_getGift.ownerOf(0), OWNER_ADDRESS);
        assertEq(s_getGift.tokenURI(0), "50 discount");

        vm.stopPrank();
    }

    function test_FulfillRequest_NotFound_NoMint() public {
        vm.startPrank(OWNER_ADDRESS);

        string[] memory args = new string[](1);
        args[0] = "gift-code-789";

        s_getGift.sendRequest(0, 0, args, s_subscriptionId, OWNER_ADDRESS);
        bytes32 requestId = s_getGift.lastRequestId();

        bytes memory response = bytes("not found");
        bytes memory err = "";

        // No minting expected
        s_getGift.handleOracleFulfillment(requestId, response, err);

        vm.expectRevert("ERC721: owner query for nonexistent token");
        s_getGift.ownerOf(0);

        vm.stopPrank();
    }

    function test_FulfillRequest_EmptyResponse_NoMint() public {
        vm.startPrank(OWNER_ADDRESS);

        string[] memory args = new string[](1);
        args[0] = "gift-code-789";

        s_getGift.sendRequest(0, 0, args, s_subscriptionId, OWNER_ADDRESS);
        bytes32 requestId = s_getGift.lastRequestId();

        bytes memory response = "";
        bytes memory err = "some error";

        // No minting expected
        s_getGift.handleOracleFulfillment(requestId, response, err);

        vm.expectRevert("ERC721: owner query for nonexistent token");
        s_getGift.ownerOf(0);

        vm.stopPrank();
    }
}
