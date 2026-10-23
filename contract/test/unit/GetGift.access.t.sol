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
    // Mirror of the GetGift events asserted with vm.expectEmit (sig-matched)
    event AllowListAdded(address indexed account);
    event AllowListRemoved(address indexed account);

    /// @notice Test that owner has access by default
    function test_OwnerHasAccess() public {
        vm.prank(owner);
        // Owner should be able to add to allowlist, proving they have access
        getGift.addToAllowList(address(0x123));
    }

    /// @notice Test that non-allowlisted addresses are not allowed
    function test_StrangerNoAccess() public {
        vm.startPrank(stranger);
        vm.expectRevert(GetGift.CallerNotAllowlisted.selector);
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
        vm.expectRevert(GetGift.CallerNotAllowlisted.selector);
        getGift.addToAllowList(stranger);
    }

    /// @notice Test removing from allowlist
    function test_RemoveFromAllowList() public {
        // First add stranger to allowlist
        vm.prank(owner);
        getGift.addToAllowList(stranger);

        // Stranger removes themselves (removal takes an explicit address)
        vm.prank(stranger);
        getGift.removeFromAllowList(stranger);

        // Verify they can no longer add others
        vm.expectRevert(GetGift.CallerNotAllowlisted.selector);
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

    /// @notice An allowlisted member may remove ANOTHER allowlisted member
    /// (previously only msg.sender could ever be removed)
    function test_RemoveFromAllowList_ByAddress() public {
        vm.prank(owner);
        getGift.addToAllowList(user);
        vm.prank(owner);
        getGift.addToAllowList(stranger);

        vm.prank(owner);
        getGift.removeFromAllowList(user);

        vm.expectRevert(GetGift.CallerNotAllowlisted.selector);
        vm.prank(user);
        getGift.addToAllowList(address(0x123));
    }

    /// @notice Removing the LAST allowlisted member would brick every admin
    /// path forever: it must revert
    function test_RemoveFromAllowList_CannotRemoveLastAdmin() public {
        vm.expectRevert(GetGift.CannotRemoveLastAllowlisted.selector);
        vm.prank(owner);
        getGift.removeFromAllowList(owner);
    }

    /// @notice Removing an address that is not on the list reverts explicitly
    function test_RemoveFromAllowList_RevertIfNotListed() public {
        vm.expectRevert(GetGift.AddressNotAllowlisted.selector);
        vm.prank(owner);
        getGift.removeFromAllowList(stranger);
    }

    /// @notice allowListCount tracks membership and duplicate adds do not
    /// double-count; the AllowListAdded event fires only on real state change
    function test_AddToAllowList_CountAndEvents() public {
        assertEq(getGift.allowListCount(), 1);

        vm.expectEmit(true, true, true, true);
        emit AllowListAdded(user);
        vm.prank(owner);
        getGift.addToAllowList(user);
        assertEq(getGift.allowListCount(), 2);

        // idempotent re-add: no new event, no count change
        vm.prank(owner);
        getGift.addToAllowList(user);
        assertEq(getGift.allowListCount(), 2);
    }

    /// @notice The zero address must never join the admin list: an allowlisted
    /// address(0) would inflate allowListCount and defeat the last-admin
    /// lockout guard (the last live admin could remove themselves)
    function test_AddToAllowList_RevertIfZeroAddress() public {
        vm.expectRevert(GetGift.InvalidRecipient.selector);
        vm.prank(owner);
        getGift.addToAllowList(address(0));
    }

    /// @notice Removal emits AllowListRemoved and decrements the count
    function test_RemoveFromAllowList_EmitsEvent() public {
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.expectEmit(true, true, true, true);
        emit AllowListRemoved(user);
        vm.prank(owner);
        getGift.removeFromAllowList(user);
        assertEq(getGift.allowListCount(), 1);
    }

    /// @notice Test removing address that is not in allowlist
    function test_RemoveFromAllowList_NotInList() public {
        vm.prank(user);
        vm.expectRevert(GetGift.CallerNotAllowlisted.selector);
        getGift.removeFromAllowList(user);
    }

    /// @notice Test that removed address cannot add others to allowlist
    function test_RemovedAddressCannotAddOthers() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.prank(user);
        getGift.removeFromAllowList(user);

        vm.prank(user);
        vm.expectRevert(GetGift.CallerNotAllowlisted.selector);
        getGift.addToAllowList(stranger);
    }
}
