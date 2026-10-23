// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "script/utility/HelperConfig.sol";
import {NetworkConfigLibrary} from "script/utility/NetworkConfigLibrary.sol";
import {LinkTokenInterface} from "lib/chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsRouter} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsRouter.sol";

/**
 * @title CreateSubscription
 * @author abdulsamed1
 * @notice Script to create a Chainlink Functions subscription
 * @dev Uses HelperConfig to get network-specific configuration
 */
contract CreateSubscription is Script {
    /**
     * @notice Creates a new Chainlink Functions subscription
     * @return The subscription ID
     */
    function createSubscription() external returns (uint64) {
        // Get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        NetworkConfigLibrary.NetworkConfig memory config = helperConfig.getActiveConfig();
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        console.log("Creating Chainlink Functions subscription on router: ", config.router);
        
        // Create subscription
        FunctionsRouter router = FunctionsRouter(config.router);
        uint64 subscriptionId = router.createSubscription();
        
        console.log("Subscription created with ID: ", subscriptionId);
        
        vm.stopBroadcast();
        
        return subscriptionId;
    }
    
    /**
     * @notice Funds an existing Chainlink Functions subscription with LINK tokens
     * @param subscriptionId The ID of the subscription to fund
     * @param fundAmount The amount of LINK to fund (in Juels, 1e18 Juels = 1 LINK)
     */
    function fundSubscription(uint64 subscriptionId, uint96 fundAmount) external {
        // Get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        NetworkConfigLibrary.NetworkConfig memory config = helperConfig.getActiveConfig();
        
        if (subscriptionId == 0) {
            subscriptionId = config.subscriptionId;
        }
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        console.log("Funding subscription ID: ", subscriptionId);
        console.log("Fund amount (Juels): ", fundAmount);
        
        // Fund with LINK token
        LinkTokenInterface linkToken = LinkTokenInterface(config.linkToken);
        linkToken.transferAndCall(
            config.router,
            fundAmount,
            abi.encode(subscriptionId)
        );
        
        console.log("Subscription funded successfully");
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Adds a consumer contract to an existing subscription
     * @param subscriptionId The ID of the subscription
     * @param consumerAddress The address of the consumer contract
     */
    function addConsumer(uint64 subscriptionId, address consumerAddress) external {
        // Get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        NetworkConfigLibrary.NetworkConfig memory config = helperConfig.getActiveConfig();
        
        if (subscriptionId == 0) {
            subscriptionId = config.subscriptionId;
        }
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        console.log("Adding consumer to subscription ID: ", subscriptionId);
        console.log("Consumer address: ", consumerAddress);
        
        // Add consumer
        FunctionsRouter router = FunctionsRouter(config.router);
        router.addConsumer(subscriptionId, consumerAddress);
        
        console.log("Consumer added successfully");
        
        vm.stopBroadcast();
    }
}