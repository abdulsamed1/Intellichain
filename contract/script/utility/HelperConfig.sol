// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./NetworkConfigLibrary.sol";

/**
 * @title HelperConfig
 * @author Claude
 * @notice Contract that uses NetworkConfigLibrary to manage network configurations
 * @dev Implements a lightweight contract design pattern with minimized state variables
 */
contract HelperConfig {
    /**
     * @dev Custom error for unsupported networks
     * @param chainId The chain ID that is not supported
     */
    error HelperConfig__UnsupportedNetwork(uint256 chainId);

    /**
     * @dev Uses the NetworkConfigLibrary for its data structures
     */
    using NetworkConfigLibrary for uint256;
    
    /**
     * @dev The active network configuration for the current chain
     */
    NetworkConfigLibrary.NetworkConfig private s_activeNetworkConfig;
    
    /**
     * @dev Event emitted when the active network configuration is updated
     * @param chainId The chain ID of the updated network configuration
     */
    event ActiveNetworkUpdated(uint256 indexed chainId);

    /**
     * @notice Constructor sets the active network configuration based on current chain ID
     * @dev Reverts if the current network is not supported
     */
    constructor() {
        uint256 currentChainId = block.chainid;
        (NetworkConfigLibrary.NetworkConfig memory config, bool supported) = 
            NetworkConfigLibrary.getNetworkConfig(currentChainId);
        
        if (!supported) {
            revert HelperConfig__UnsupportedNetwork(currentChainId);
        }
        
        s_activeNetworkConfig = config;
        emit ActiveNetworkUpdated(currentChainId);
    }

    /**
     * @notice Gets the active network configuration for the current chain
     * @dev Returns the cached configuration to save gas
     * @return The active network configuration
     */
    function getActiveConfig() external view returns (NetworkConfigLibrary.NetworkConfig memory) {
        return s_activeNetworkConfig;
    }
    
    /**
     * @notice Gets the network configuration for a specific chain ID
     * @dev Uses the library to fetch configuration, reverts if network not supported
     * @param chainId The chain ID to get the configuration for
     * @return The network configuration for the specified chain ID
     */
    function getNetworkConfig(uint256 chainId) external pure returns (NetworkConfigLibrary.NetworkConfig memory) {
        (NetworkConfigLibrary.NetworkConfig memory config, bool supported) = 
            NetworkConfigLibrary.getNetworkConfig(chainId);
            
        if (!supported) {
            revert HelperConfig__UnsupportedNetwork(chainId);
        }
        
        return config;
    }
    
    /**
     * @notice Checks if a network is supported
     * @dev Forwards the call to the library function
     * @param chainId The chain ID to check
     * @return True if the network is supported, false otherwise
     */
    function isNetworkSupported(uint256 chainId) public pure returns (bool) {
        (, bool supported) = NetworkConfigLibrary.getNetworkConfig(chainId);
        return supported;
    }
}