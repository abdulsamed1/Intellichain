// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {GetGiftBase} from "../utilites/GetGift.utils.t.sol";
import {GetGift} from "../../src/GetGift.sol";

/// @title GetGiftGas Test Suite
/// @notice Gas optimization test suite for GetGift contract operations
/// @dev Extends Chainlink's gas test architecture with GetGift-specific test scenarios
/// @title Gas Tests: SendRequest
/// @notice Gas profiling for GetGift.sendRequest functionality
/// @dev Inherits GetGiftBase for test utilities and Gas_SendRequest for gas testing patterns
contract GetGiftGas_SendRequest is GetGiftBase {
    uint256 constant GAS_LIMIT_SEND_REQUEST = 300_000;

    /// @notice Sets up the test environment with necessary test data and contract state
    function setUp() public virtual override {
        GetGiftBase.setUp();
    }

    /// @notice Test gas consumption for sendRequest with maximum parameters
    function test_SendRequest_Maximum_Gas() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        bytes32 requestId = getGift.sendRequest(type(uint8).max, type(uint64).max, args, SUBSCRIPTION_ID, user);
        assertTrue(requestId != bytes32(0), "Request ID should not be zero");
        vm.stopPrank();
    }

    /// @notice Test gas consumption for sendRequest with minimum parameters
    function test_SendRequest_Minimum_Gas() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = "ABC";
        bytes32 requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        assertTrue(requestId != bytes32(0), "Request ID should not be zero");
        vm.stopPrank();
    }

    function test_SendRequest_MinimumGas_Custom() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = "ABC";
        bytes32 reqId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        assertTrue(reqId != bytes32(0), "Request ID should not be zero");
        vm.stopPrank();
    }

    function test_SendRequest_MaximumGas_Custom() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        bytes32 reqId = getGift.sendRequest(type(uint8).max, type(uint64).max, args, SUBSCRIPTION_ID, user);
        assertTrue(reqId != bytes32(0), "Request ID should not be zero");
        vm.stopPrank();
    }
}

/// @title Gas Tests: FulfillRequest
/// @notice Gas profiling for GetGift.fulfillRequest functionality
/// @dev Tests successful request fulfillment with maximum and minimum gas scenarios
contract GetGiftGas_FulfillRequest is GetGiftBase {
    uint256 constant GAS_LIMIT_FULFILL_REQUEST = 1_000_000;

    /// @notice Sets up test data and state for fulfillRequest gas tests
    /// @dev Initializes both base setup and chainlink-specific test data
    function setUp() public virtual override {
        GetGiftBase.setUp();
    }

    /// @notice Test gas consumption for fulfillRequest with maximum parameters
    /// @dev Measures gas usage for fulfilling a request with maximum data size and complexity
    function test_FulfillRequest_Maximum_Gas() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        bytes32 requestId = getGift.sendRequest(type(uint8).max, type(uint64).max, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        uint256 expectedTokenId = getGift.tokenId();
        vm.startPrank(ROUTER_ADDR);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user, expectedTokenId);
        bytes memory response = abi.encode("100 discount");
        getGift.handleOracleFulfillment(requestId, response, new bytes(0));
        vm.stopPrank();

        assertEq(getGift.ownerOf(expectedTokenId), user);
    }

    /// @notice Test gas consumption for fulfillRequest with minimum parameters
    /// @dev Measures gas usage for fulfilling a request with minimum viable data
    function test_FulfillRequest_Minimum_Gas() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        string[] memory args = new string[](1);
        args[0] = "ABC";
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
    }
}
