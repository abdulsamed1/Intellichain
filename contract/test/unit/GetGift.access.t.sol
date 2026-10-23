// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {GetGift} from "../../src/GetGift.sol";
import {GetGiftBase} from "../utilites/GetGift.utils.t.sol";
/**
 * @title GetGiftAccessTest
 * @notice Tests for GetGift contract access control
 */

contract GetGiftAccessTest is GetGiftBase {
    /// @notice Test that owner has access by default
    function test_OwnerHasAccess() public {
        vm.prank(owner);
        // Owner should be able to add to allowlist, proving they have access
        getGift.addToAllowList(address(0x123));
    }

    /// @notice Test that non-allowlisted addresses are not allowed
    function test_StrangerNoAccess() public {
        vm.startPrank(stranger);
        vm.expectRevert("you do not have permission to call the function");
        getGift.addToAllowList(address(0x123));
        vm.stopPrank();
    }

    /// @notice Test adding an address to allowlist by owner
    function test_AddToAllowList_ByOwner() public {
        vm.prank(owner);
        getGift.addToAllowList(stranger);
        
        // Now stranger should be able to add others, proving they're on allowlist
        vm.prank(stranger);
        getGift.addToAllowList(address(0x123));
    }

    /// @notice Test that non-owner cannot add to allowlist
    function test_AddToAllowList_RevertIfNotOwner() public {
        vm.prank(stranger);
        vm.expectRevert("you do not have permission to call the function");
        getGift.addToAllowList(stranger);
    }

    /// @notice Test removing from allowlist
    function test_RemoveFromAllowList() public {
        // First add stranger to allowlist
        vm.prank(owner);
        getGift.addToAllowList(stranger);
        
        // Stranger removes themselves
        vm.prank(stranger);
        getGift.removeFromAllowList();
        
        // Verify they can no longer add others
        vm.expectRevert("you do not have permission to call the function");
        vm.prank(stranger);
        getGift.addToAllowList(address(0x123));
    }

    /// @notice Test adding multiple addresses to allowlist
    function test_AddToAllowList_MultipleUsers() public {
        address user2 = address(4);
        address user3 = address(5);

        vm.startPrank(owner);
        getGift.addToAllowList(user);
        getGift.addToAllowList(user2);
        getGift.addToAllowList(user3);
        vm.stopPrank();

        // Verify each user can perform allowlisted actions
        vm.prank(user);
        getGift.addToAllowList(address(0x123));
        
        vm.prank(user2);
        getGift.addToAllowList(address(0x124));
        
        vm.prank(user3);
        getGift.addToAllowList(address(0x125));
    }

    /// @notice Test that re-adding an already allowlisted user has no effect
    function test_AddToAllowList_AlreadyAllowed() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        // User should be able to add others
        vm.stopPrank();
        
        vm.prank(user);
        getGift.addToAllowList(address(0x123));
        
        // Re-add user to allowlist
        vm.prank(owner);
        getGift.addToAllowList(user);
        
        // User should still be able to add others
        vm.prank(user);
        getGift.addToAllowList(address(0x124));
    }

    /// @notice Test removing address that is not in allowlist
    function test_RemoveFromAllowList_NotInList() public {
        vm.prank(user);
        vm.expectRevert("you do not have permission to call the function");
        getGift.removeFromAllowList();
    }

    /// @notice Test that removed address cannot add others to allowlist
    function test_RemovedAddressCannotAddOthers() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.prank(user);
        getGift.removeFromAllowList();

        vm.prank(user);
        vm.expectRevert("you do not have permission to call the function");
        getGift.addToAllowList(stranger);
    }
}
