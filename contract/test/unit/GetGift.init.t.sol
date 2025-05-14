// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {GetGiftBase} from "../utilites/GetGift.utils.t.sol";

/**
 * @title GetGiftInitTest
 * @notice Tests for GetGift contract constructor and initialization
 */
contract GetGiftInitTest is GetGiftBase {
    /// @notice Test that the contract properly initializes upon deployment
    function test_Constructor_InitializesCorrectly() public view {
        assertEq(getGift.ROUTER_ADDR(), ROUTER_ADDR, "Router address should match");
        assertEq(getGift.DON_ID(), DON_ID, "DON ID should match");
    }

    /// @notice Test that test state is properly initialized in setup
    function test_SetUpState() public view {
        assertTrue(address(getGift) != address(0), "GetGift contract should be initialized");
        assertEq(SUBSCRIPTION_ID, 1, "Subscription ID should be 1");
    }
}
