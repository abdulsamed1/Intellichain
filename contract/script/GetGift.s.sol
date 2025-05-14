// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {GetGift} from "../src/GetGift.sol";

contract DeployGetGift is Script {
    function run() external {
        vm.startBroadcast();
        GetGift getGift = new GetGift();
        console.log("GetGift deployed to:", address(getGift));
        vm.stopBroadcast();
    }
}
