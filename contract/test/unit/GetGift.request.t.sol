// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {GetGiftBase} from "../utilites/GetGift.utils.t.sol";
import {FunctionsRequest} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {GetGift} from "../../src/GetGift.sol";
import {FunctionsClient} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";

/**
 * @title GetGiftRequestTest
 * @notice Tests for request handling functionality in GetGift contract
 */
contract GetGiftRequestTest is GetGiftBase {
    using FunctionsRequest for FunctionsRequest.Request;
    /// @notice Test that the request is properly initialized
    /// @notice Test sending a valid gift code request

    function test_SendRequest_ValidGiftCode() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        assertTrue(requestId != bytes32(0), "Request ID should not be zero");
        vm.stopPrank();
    }

    /// @notice Test that request fails if gift code is already redeemed
    function test_SendRequest_RevertIfCodeRedeemed() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        // First request
        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        // Fulfill first request
        vm.startPrank(ROUTER_ADDR);
        bytes memory response = abi.encode("100 discount");
        getGift.handleOracleFulfillment(requestId, response, new bytes(0));
        vm.stopPrank();

        // Try to use the same code again
        vm.startPrank(user);
        vm.expectRevert("the code is redeemed");
        getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();
    }

    /// @notice Test that request fails if args are empty
    function test_SendRequest_RevertIfEmptyArgs() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory emptyArgs = new string[](0);
        vm.expectRevert(); // Will revert with array access error
        getGift.sendRequest(1, 1, emptyArgs, SUBSCRIPTION_ID, user);
        vm.stopPrank();
    }

    /// @notice Test that request fails if sender is not in allowlist
    function test_SendRequest_RevertIfNotInAllowList() public {
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        vm.startPrank(stranger);
        vm.expectRevert("you do not have permission to call the function");
        getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, stranger);
        vm.stopPrank();
    }

    /// @notice Test that request fails with invalid subscription ID
    function test_SendRequest_RevertIfInvalidSubscriptionId() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;

        // Mock the router to revert for invalid subscription ID
        vm.mockCallRevert(
            ROUTER_ADDR,
            abi.encodeWithSignature("sendRequest(uint64,bytes,uint16,uint32,bytes32)"),
            "Invalid subscription"
        );

        vm.expectRevert("Invalid subscription");
        getGift.sendRequest(1, 1, args, 0, user);
        vm.stopPrank();
    }

    /// @notice Test building a valid request with correct arguments
    function test_BuildValidRequest() public pure {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(SOURCE);
        req.addDONHostedSecrets(DON_HOSTED_SECRETS_SLOT, DON_HOSTED_SECRETS_VERSION);
        string[] memory testArgs = new string[](1);
        testArgs[0] = validGiftCode;
        req.setArgs(testArgs);

        bytes memory encodedRequest = req.encodeCBOR();
        assertTrue(encodedRequest.length > 0, "Request should be properly encoded");
    }

    /// @notice Test sending request with multiple arguments
    function test_RequestWithMultipleArgs() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](2);
        args[0] = validGiftCode;
        args[1] = "additional_param";
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        assertTrue(requestId != bytes32(0), "Request ID should not be zero");
        vm.stopPrank();
    }

    /// @notice Test that storage state is properly updated after fulfillment
    function test_RequestFulfillment_UpdatesStorage() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = validGiftCode;
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        vm.startPrank(ROUTER_ADDR);
        bytes memory response = abi.encode("100 discount");
        getGift.handleOracleFulfillment(requestId, response, new bytes(0));
        vm.stopPrank();

        // Try to reuse the same code - should revert
        vm.startPrank(user);
        vm.expectRevert("the code is redeemed");
        getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();
    }
}
