// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {GetGift} from "../src/GetGift.sol";
import {HelperConfig} from "script/utility/HelperConfig.sol";
import {NetworkConfigLibrary} from "script/utility/NetworkConfigLibrary.sol";

/**
 * @title DecodeResponse
 * @author abdulsamed1
 * @notice Script to decode the response from Chainlink Functions
 * @dev Uses HelperConfig to get network-specific configuration
 */
contract DecodeResponse is Script {
    /**
     * @notice Decodes and displays the last response from the contract
     * @param getGiftAddress The address of the deployed GetGift contract
     */
    function decodeLastResponse(address getGiftAddress) external view {
        GetGift getGift = GetGift(getGiftAddress);
        
        bytes memory lastResponse = getGift.s_lastResponse();
        bytes memory lastError = getGift.s_lastError();
        bytes32 lastRequestId = getGift.s_lastRequestId();
        
        console.log("Last Request ID: ", vm.toString(lastRequestId));
        
        if (lastError.length > 0) {
            console.log("Last Error:");
            console.logBytes(lastError);
            
            // Try to decode error as string
            string memory errorString = abi.decode(lastError, (string));
            console.log("Decoded Error: ", errorString);
        } else {
            console.log("No errors in last request");
        }
        
        if (lastResponse.length > 0) {
            console.log("Last Response:");
            console.logBytes(lastResponse);
            
            // Try to decode response as string
            string memory responseString = abi.decode(lastResponse, (string));
            console.log("Decoded Response: ", responseString);
            
            // Check if the gift was found
            if (keccak256(bytes(responseString)) == keccak256(bytes("not found"))) {
                console.log("Gift code was not found in the database");
            } else {
                console.log("Gift type received: ", responseString);
                
                // Check current token ID to see if NFT was minted
                uint256 tokenId = getGift.tokenId();
                console.log("Current token ID: ", tokenId);
            }
        } else {
            console.log("No response data available");
        }
    }
    
    /**
     * @notice Gets information about a specific NFT token
     * @param getGiftAddress The address of the deployed GetGift contract
     * @param tokenId The token ID to check
     */
    function getTokenInfo(address getGiftAddress, uint256 tokenId) external view {
        GetGift getGift = GetGift(getGiftAddress);
        
        try getGift.ownerOf(tokenId) returns (address owner) {
            console.log("Token ID: ", tokenId);
            console.log("Owner: ", owner);
            
            string memory tokenURI = getGift.tokenURI(tokenId);
            console.log("Token URI: ", tokenURI);
        } catch {
            console.log("Token ID ", tokenId, " does not exist");
        }
    }
}