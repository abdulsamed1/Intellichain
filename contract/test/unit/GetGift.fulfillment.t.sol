// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {GetGiftBase} from "../utilites/GetGift.utils.t.sol";
import {FunctionsClient} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {GetGift} from "../../src/GetGift.sol";

/**
 * @title GetGiftFulfillmentTest
 * @notice Tests for request fulfillment functionality in GetGift contract
 */
contract GetGiftFulfillmentTest is GetGiftBase {
    /// @notice Test successful fulfillment with valid response
    function test_FulfillRequest_ValidResponse() public {
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

    /// @notice Test fulfillment with invalid response
    function test_FulfillRequest_InvalidResponse() public {
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

    /// @notice Test that fulfillment fails with unexpected request ID
    function test_FulfillRequest_RevertIfUnexpectedRequestId() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes32 wrongRequestId = bytes32(uint256(999));
        bytes memory response = abi.encode("100 discount");

        vm.startPrank(ROUTER_ADDR);
        vm.expectRevert(abi.encodeWithSignature("UnexpectedRequestID(bytes32)", wrongRequestId));
        getGift.handleOracleFulfillment(wrongRequestId, response, new bytes(0));
        vm.stopPrank();
    }

    /// @notice Test that fulfillment fails if not called by router
    function test_FulfillRequest_RevertIfNotRouter() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes memory response = abi.encode("100 discount");

        vm.startPrank(stranger);
        vm.expectRevert("OnlyRouterCanFulfill()");
        getGift.handleOracleFulfillment(requestId, response, new bytes(0));
        vm.stopPrank();
    }

    /// @notice Test successful fulfillment with empty error
    function test_FulfillRequest_Success_WithEmptyError() public {
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

    /// @notice Test fulfillment with error
    function test_FulfillRequest_Success_WithError() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes memory response = new bytes(0);
        bytes memory error = abi.encode("Test error");

        vm.startPrank(ROUTER_ADDR);
        getGift.handleOracleFulfillment(requestId, response, error);
        vm.stopPrank();
    }

    /// @notice Test handling different gift types in responses
    function test_FulfillRequest_DifferentGiftTypes() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        // Test gift code 1
        vm.startPrank(user);
        string[] memory args1 = new string[](1);
        args1[0] = "gift1";
        bytes32 reqId1 = getGift.sendRequest(1, 1, args1, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        uint256 expectedTokenId1 = getGift.tokenId();
        vm.startPrank(ROUTER_ADDR);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, expectedTokenId1);
        getGift.handleOracleFulfillment(reqId1, abi.encode("100 discount"), new bytes(0));
        vm.stopPrank();

        // Test gift code 2
        vm.startPrank(user);
        string[] memory args2 = new string[](1);
        args2[0] = "gift2";
        bytes32 reqId2 = getGift.sendRequest(1, 1, args2, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        uint256 expectedTokenId2 = getGift.tokenId();
        vm.startPrank(ROUTER_ADDR);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, expectedTokenId2);
        getGift.handleOracleFulfillment(reqId2, abi.encode("50 discount"), new bytes(0));
        vm.stopPrank();

        // Test gift code 3
        vm.startPrank(user);
        string[] memory args3 = new string[](1);
        args3[0] = "gift3";
        bytes32 reqId3 = getGift.sendRequest(1, 1, args3, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        uint256 expectedTokenId3 = getGift.tokenId();
        vm.startPrank(ROUTER_ADDR);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, expectedTokenId3);
        getGift.handleOracleFulfillment(reqId3, abi.encode("1-month premium"), new bytes(0));
        vm.stopPrank();

        // Verify NFT ownership and metadata
        assertEq(getGift.ownerOf(expectedTokenId1), user);
        assertEq(getGift.ownerOf(expectedTokenId2), user);
        assertEq(getGift.ownerOf(expectedTokenId3), user);

        assertEq(getGift.tokenURI(expectedTokenId1), ITEM_1_METADATA);
        assertEq(getGift.tokenURI(expectedTokenId2), ITEM_2_METADATA);
        assertEq(getGift.tokenURI(expectedTokenId3), ITEM_3_METADATA);
    }
}
