// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FunctionsRouter} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsRouter.sol";
import {FunctionsClient} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {TermsOfServiceAllowList} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/accessControl/TermsOfServiceAllowList.sol";

contract AcceptTermsOfService is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address routerAddress = vm.envAddress("ROUTER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        FunctionsRouter router = FunctionsRouter(routerAddress);
        bytes32 allowListId = router.getAllowListId();
        address tosAddress = router.getContractById(allowListId);
        
        TermsOfServiceAllowList tos = TermsOfServiceAllowList(tosAddress);
        
        // Accept Terms of Service
        bool alreadyAccepted = tos.hasAccepted(vm.addr(deployerPrivateKey));
        if (!alreadyAccepted) {
            // Message to sign: "I accept the Chainlink Functions Terms of Service [version]"
            bytes memory message = bytes("I accept the Chainlink Functions Terms of Service v1.0.0");
            bytes32 hash = keccak256(message);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, hash);
            bytes memory signature = abi.encodePacked(r, s, v);
            
            tos.acceptTermsOfService(message, signature);
            
            console.log("Terms of Service accepted successfully");
        } else {
            console.log("Terms of Service were already accepted");
        }
        
        vm.stopBroadcast();
    }
}
