// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {GetGift} from "../src/GetGift.sol";

/**
 * @title GetGiftScript
 * @notice Deployment script for the GetGift contract
 * @dev Uses Foundry's Script tool to deploy and configure the GetGift contract
 */
contract GetGiftScript is Script {
    /// @notice Instance of the deployed GetGift contract
    GetGift public getgift;

    /**
     * @notice Deploys the GetGift contract
     * @dev Main execution function that handles deployment and logging
     */
    function run() public {
        // Start a single broadcast session for efficiency
        vm.startBroadcast();

        // Deploy the contract
        getgift = new GetGift();

        // Log the deployed contract address
        console.log("GetGift contract deployed at: %s", address(getgift));

        // End the broadcast session
        vm.stopBroadcast();
        
    }
}
