// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {GetGift} from "../src/GetGift.sol";

contract GetGiftScript is Script {
    GetGift public getgift;

    function setUp() public returns (GetGift) {
        // Deploy the contract
        vm.startBroadcast();
        getgift = new GetGift();
        vm.stopBroadcast();
        return getgift;
    }

    function run() public {
        vm.startBroadcast();

        getgift = new GetGift();

        vm.stopBroadcast();
        console.log("GetGift contract deployed at: ", address(getgift));
        vm.startBroadcast();
    }
}
