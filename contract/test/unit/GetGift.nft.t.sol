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
        vm.expectRevert("the code is redeemed");
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
