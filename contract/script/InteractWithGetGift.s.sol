// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GetGift} from "../src/GetGift.sol";
import {HelperConfig} from "script/utility/HelperConfig.sol";
import {NetworkConfigLibrary} from "script/utility/NetworkConfigLibrary.sol";

/**
 * @title InteractWithGetGift
 * @author Claude
 * @notice Script to interact with the deployed GetGift contract
 * @dev Uses HelperConfig to get network-specific configuration
 */
contract InteractWithGetGift is Script {
    // Error codes
    error InteractWithGetGift__NoContractAddressProvided();
    
    /**
     * @notice Sends a request to redeem a gift code
     * @param getGiftAddress The address of the deployed GetGift contract
     * @param giftCode The gift code to redeem
     * @param donHostedSecretsSlotID The slot ID for DON hosted secrets
     * @param donHostedSecretsVersion The version for DON hosted secrets
     */
    function redeemGiftCode(
        address getGiftAddress,
        string memory giftCode,
        uint8 donHostedSecretsSlotID,
        uint64 donHostedSecretsVersion
    ) external {
        if (getGiftAddress == address(0)) {
            revert InteractWithGetGift__NoContractAddressProvided();
        }
        
        // Get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        NetworkConfigLibrary.NetworkConfig memory config = helperConfig.getActiveConfig();
        
        // Create the arguments array
        string[] memory args = new string[](1);
        args[0] = giftCode;
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        GetGift getGift = GetGift(getGiftAddress);
        
        console.log("Sending gift code redemption request:");
        console.log("Contract Address: ", getGiftAddress);
        console.log("Gift Code: ", giftCode);
        console.log("Subscription ID: ", config.subscriptionId);
        
        // Send the request
        bytes32 requestId = getGift.sendRequest(
            donHostedSecretsSlotID,
            donHostedSecretsVersion,
            args,
            config.subscriptionId,
            msg.sender
        );
        
        console.log("Request sent with ID: ", vm.toString(requestId));
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Adds a new gift type to the contract
     * @param getGiftAddress The address of the deployed GetGift contract
     * @param giftName The name of the gift
     * @param tokenUri The IPFS URI for the gift's metadata
     */
    function addGift(
        address getGiftAddress,
        string memory giftName,
        string memory tokenUri
    ) external {
        if (getGiftAddress == address(0)) {
            revert InteractWithGetGift__NoContractAddressProvided();
        }
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        GetGift getGift = GetGift(getGiftAddress);
        
        console.log("Adding new gift type:");
        console.log("Gift Name: ", giftName);
        console.log("Token URI: ", tokenUri);
        
        // Add the gift
        getGift.addGift(giftName, tokenUri);
        
        console.log("Gift added successfully");
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Adds an address to the allow list
     * @param getGiftAddress The address of the deployed GetGift contract
     * @param addressToAdd The address to add to the allow list
     */
    function addToAllowList(
        address getGiftAddress,
        address addressToAdd
    ) external {
        if (getGiftAddress == address(0)) {
            revert InteractWithGetGift__NoContractAddressProvided();
        }
        
        // Start broadcasting transactions
        vm.startBroadcast();
        
        GetGift getGift = GetGift(getGiftAddress);
        
        console.log("Adding address to allow list:");
        console.log("Address: ", addressToAdd);
        
        // Add to allow list
        getGift.addToAllowList(addressToAdd);
        
        console.log("Address added to allow list successfully");
        
        vm.stopBroadcast();
    }
    
    /**
     * @notice Gets the current token ID (for minting tracking)
     * @param getGiftAddress The address of the deployed GetGift contract
     * @return The current token ID
     */
    function getTokenId(address getGiftAddress) external view returns (uint256) {
        if (getGiftAddress == address(0)) {
            revert InteractWithGetGift__NoContractAddressProvided();
        }
        
        GetGift getGift = GetGift(getGiftAddress);
        return getGift.tokenId();
    }
}