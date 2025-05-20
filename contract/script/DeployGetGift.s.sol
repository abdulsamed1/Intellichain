// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GetGift} from "../src/GetGift.sol";
import {HelperConfig} from "script/utility/HelperConfig.sol";
import {NetworkConfigLibrary} from "script/utility/NetworkConfigLibrary.sol";
import {FunctionsClient} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";

/**
 * @title DeployGetGift
 * @author abdulsamed1
 * @notice Script to deploy the GetGift contract
 * @dev Uses HelperConfig to get network-specific configuration
 */
contract DeployGetGift is Script {
    /**
     * @dev Main deployment function
     * @return The deployed GetGift contract instance
     */
    function run() external returns (GetGift) {
        // Get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        NetworkConfigLibrary.NetworkConfig memory config = helperConfig.getActiveConfig();
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Deploy the GetGift contract
        GetGift getGift = new GetGift();
        
        console.log("GetGift deployed at address: ", address(getGift));
        console.log("Router address: ", config.router);
        console.log("DON ID: ", vm.toString(config.donId));
        console.log("Callback Gas Limit: ", config.callbackGasLimit);
        
        vm.stopBroadcast();
        
        return getGift;
    }
}