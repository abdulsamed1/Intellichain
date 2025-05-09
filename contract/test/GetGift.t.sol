// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";
import {GetGift} from "../src/GetGift.sol";
import {GetGiftScript} from "script/GetGift.s.sol";

contract GetGiftTest is Test {
    GetGift public getgift;
    address public constant COUNTER_ADDR = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    GetGift public counter = GetGift(COUNTER_ADDR);
    bytes32 public constant DON_ID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    function setUp() public {
        GetGiftScript script = new GetGiftScript();
        getgift = script.setUp();
    }

    function testGetGift() public {
        
        
    }

    function testGetGiftCode() public {
        
    }
}
