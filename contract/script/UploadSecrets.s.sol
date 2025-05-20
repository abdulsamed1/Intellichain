// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HelperConfig} from "script/utility/HelperConfig.sol";
import {NetworkConfigLibrary} from "script/utility/NetworkConfigLibrary.sol";
import {FunctionsClient} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";

/**
 * @title UploadSecrets
 * @author Claude
 * @notice Script to upload secrets for DON-hosted encrypted secrets
 * @dev Uses HelperConfig to get network-specific configuration
 */
contract UploadSecrets is Script {
    /**
     * @notice Uploads a secret to the DON (Decentralized Oracle Network)
     * @dev This is a mock function since actual secret uploads are done off-chain
     * @dev In a real scenario, you would use the Chainlink Functions CLI for this
     */
    function uploadSecretsMock() external {
        // Get the network configuration
        HelperConfig helperConfig = new HelperConfig();
        NetworkConfigLibrary.NetworkConfig memory config = helperConfig.getActiveConfig();

        console.log("Mock function for uploading secrets to DON");
        console.log("In a real scenario, you would use the Chainlink Functions CLI");
        console.log("Example CLI command:");
        console.log("-----------------------------------------");
        console.log(
            "npx hardhat functions-upload-secrets --network [NETWORK_NAME] --slot [SLOT_ID] --environment [ENVIRONMENT_NAME]"
        );
        console.log("-----------------------------------------");
        console.log("Your secret JSON file should look like:");
        console.log("{");
        console.log("  \"apikey\": \"your-supabase-api-key\"");
        console.log("}");
        console.log("-----------------------------------------");
        console.log("Current network configuration:");
        console.log("Router address: ", config.router);
        console.log("DON ID: ", vm.toString(config.donId));
    }

    /**
     * @notice Helper function to create the .env file for uploading secrets
     * @param slotId The slot ID to use for the secret
     * @param supabaseApiKey The Supabase API key
     */
    function createEnvFileForSecrets(uint8 slotId, string memory supabaseApiKey) external {
        // Start broadcasting transactions (not actually sending, just for logging)
        vm.startBroadcast();

        string memory envContent = string(
            abi.encodePacked(
                "PRIVATE_KEY=your-wallet-private-key\n",
                "SUPABASE_API_KEY=",
                supabaseApiKey,
                "\n",
                "SLOT_ID=",
                vm.toString(slotId),
                "\n"
            )
        );

        console.log("Here's the content for your .env file:");
        console.log("-----------------------------------------");
        console.log(envContent);
        console.log("-----------------------------------------");
        console.log("Save this content to a .env file in your project root");
        console.log("Make sure to replace 'your-wallet-private-key' with your actual private key");

        vm.stopBroadcast();
    }

    /**
     * @notice Helper function to create the secrets.json file for uploading
     * @param supabaseApiKey The Supabase API key
     */
    function createSecretsJsonFile(string memory supabaseApiKey) external {
        // Start broadcasting transactions (not actually sending, just for logging)
        vm.startBroadcast();

        string memory secretsContent = string(abi.encodePacked("{\n", "  \"apikey\": \"", supabaseApiKey, "\"\n", "}"));

        console.log("Here's the content for your secrets.json file:");
        console.log("-----------------------------------------");
        console.log(secretsContent);
        console.log("-----------------------------------------");
        console.log("Save this content to a secrets.json file in your project root");

        vm.stopBroadcast();
    }
}
