// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title NetworkConfigLibrary
 * @author abdulsamed1
 * @notice Library that provides network configurations with gas efficiency
 * @dev Contains pure functions that return network-specific configurations
 */
library NetworkConfigLibrary {
    /**
     * @dev Network configuration structure
     * @param router The address of the router contract for the network
     * @param donId The DON ID for Chainlink Functions
     * @param callbackGasLimit The gas limit for callback functions
     * @param linkToken The address of the LINK token on the network
     * @param subscriptionId The Chainlink subscription ID
     */
    struct NetworkConfig {
        address router;
        bytes32 donId;
        uint32 callbackGasLimit;
        address linkToken;
        uint64 subscriptionId;
    }

    /**
     * @notice Returns the configuration for a specific chain ID
     * @dev Uses pure functions to avoid state storage costs
     * @param chainId The ID of the blockchain network
     * @return config The network configuration
     * @return supported Whether the network is supported
     */
    function getNetworkConfig(uint256 chainId) internal pure returns (NetworkConfig memory config, bool supported) {
        if (chainId == 31337) {
            // Anvil local network
            return (
                NetworkConfig({
                    router: address(0xd5E230Caa7352F357E1dd3A34c5033F4a3e35f3D),
                    donId: bytes32(bytes("dev-anvil-don-id")),
                    callbackGasLimit: 300_000,
                    linkToken: address(0x94d3c68a91c5D02D28E9215eA12736eb5E8e432F),
                    subscriptionId: 1
                }),
                true
            );
        } else if (chainId == 11155111) {
            // Sepolia testnet
            return (
                NetworkConfig({
                    router: address(0xb83E47C2bC239B3bf370bc41e1459A34b41238D0),
                    donId: bytes32(bytes("fun-ethereum-sepolia-1")),
                    callbackGasLimit: 250_000,
                    linkToken: address(0x779877a7b0d9e8603169ddbd7836e478b4624789),
                    subscriptionId: 4952
                }),
                true
            );
        }else {
            // Return empty config with false flag for unsupported networks
            return (
                NetworkConfig({
                    router: address(0),
                    donId: bytes32(0),
                    callbackGasLimit: 0,
                    linkToken: address(0),
                    subscriptionId: 0
                }),
                false
            );
        }
    }
}
