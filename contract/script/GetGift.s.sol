// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {GetGift} from "../src/GetGift.sol";
import {FunctionsV1EventsMock} from "../test/./mocks/FunctionsV1EventsMock.sol";
import {FunctionsRouterMock} from "../test/./mocks/FunctionsRouterMock.sol";

/**
 * @title GetGiftScript
 * @notice Deployment script for the GetGift contract with optional post-deploy setup
 * @dev Uses Foundry's Script tool to deploy and configure the GetGift contract
 */
contract GetGiftScript is Script {
    /// @notice Instance of the deployed GetGift contract
    GetGift public getgift;

    /**
     * @notice Deploys the GetGift contract and optionally adds deployer to allowlist
     * @dev Can be used in both broadcasting and simulation mode
     */
    function run() public {
        // Start a broadcast session (remove if testing without sending txs)
        vm.startBroadcast();

        // Deploy the contract
        getgift = new GetGift();

        // Log deployment info
        console.log(" GetGift contract deployed at:", address(getgift));
        console.log("   Deployer:", msg.sender);

        // Optional: Add deployer to allowlist
        try getgift.addToAllowList(msg.sender) {
            console.log(" Deployer added to allowlist");
        } catch {
            console.log(" Failed to add deployer to allowlist (already in list?)");
        }

        // --- Efficient local testing: Uncomment below to configure mocks ---
        // FunctionsV1EventsMock mockEventsRouter = new FunctionsV1EventsMock();
        // FunctionsRouterMock mockRouter = new FunctionsRouterMock();
        // _configureMockRouter(mockEventsRouter, mockRouter, msg.sender);

        // End the broadcast session
        vm.stopBroadcast();
    }

   
}
