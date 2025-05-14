// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {GetGift} from "../../src/GetGift.sol";
import {FunctionsRouter} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsRouter.sol";
import {IFunctionsRouter} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/interfaces/IFunctionsRouter.sol";
import {FunctionsV1EventsMock} from
    "lib/chainlink/contracts/src/v0.8/functions/dev/v1_X/mocks/FunctionsV1EventsMock.sol";
import {FunctionsClient} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";

/**
 * @title GetGiftBase
 * @notice Base contract for GetGift tests containing shared setup and utility functions
 */
abstract contract GetGiftBase is Test {
    // Constants
    address constant ROUTER_ADDR = address(0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0);
    bytes32 constant DON_ID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;
    uint64 constant SUBSCRIPTION_ID = 1;
    uint32 constant CALLBACK_GAS_LIMIT = 300_000;

    // NFT Metadata Constants
    string constant ITEM_1_METADATA = "ipfs://QmaGqBNqHazCjSMNMuDk6VrgjNLMQKNZqaab1vfMHAwkoj";
    string constant ITEM_2_METADATA = "ipfs://QmfNhhpUezQLcyqXBGL4ehPwo7Gfbwk9yy3YcJqGgr9dPb";
    string constant ITEM_3_METADATA = "ipfs://QmNxq7GqehZf9SpCEFK7C4moxZTZPNwCer5yCAqCBNdk2a";

    // Additional test data
    bytes32 constant NODE_HASH = bytes32(uint256(1));
    uint96 constant COST = 0.1 ether;
    bytes constant DON_HOSTED_SECRETS = "test-secrets";
    string constant SUPABASE_ENDPOINT = "https://flofeywjrxcklrizkgdg.supabase.co/rest/v1/Gifts";

    // Test parameters
    uint8 constant DON_HOSTED_SECRETS_SLOT = 1;
    uint64 constant DON_HOSTED_SECRETS_VERSION = 1;
    uint32 constant GAS_LIMIT = 300000;
    uint64 internal subscriptionId;

    // Contract instances
    GetGift public getGift;

    // Mock routers for testing
    FunctionsV1EventsMock public mockEventsRouter;
    IFunctionsRouter public mockRouter;

    // Test accounts
    address owner = address(1);
    address stranger = address(2);
    address user = address(3);

    // Test data
    string[] public args;
    string constant validGiftCode = "100 discount";
    string constant invalidGiftCode = "invalid code";
    bytes32 requestId;
    string constant SOURCE = "testing source code";

    // Keep track of request mappings
    mapping(bytes32 => address) reqIdToAddr;
    mapping(bytes32 => string) reqIdToGiftCode;

    // Events
    event RequestSent(bytes32 indexed id);
    event RequestFulfilled(bytes32 indexed id);
    event RequestProcessed(
        bytes32 indexed requestId,
        uint64 indexed subscriptionId,
        uint96 totalCost,
        address transmitter,
        bytes response,
        bytes err,
        bytes ImmutableCalldata
    );
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function setUp() public virtual {
        vm.stopPrank();
        vm.clearMockedCalls();

        // Deploy GetGift contract with owner
        vm.startPrank(owner);
        getGift = new GetGift();
        vm.stopPrank();

        // Set up initial mock calls
        _setupMockCalls();

        // Initialize test data
        args = new string[](1);
    }

    function _setupMockCalls() internal {
        // Mock router calls
        vm.mockCall(
            ROUTER_ADDR,
            abi.encodeWithSignature("sendRequest(uint64,bytes,uint16,uint32,bytes32)"),
            abi.encode(bytes32(uint256(1)))
        );

        vm.mockCall(ROUTER_ADDR, abi.encodeWithSignature("fulfill(bytes,bytes)"), abi.encode());

        // Mock the secrets for testing
        vm.mockCall(
            ROUTER_ADDR,
            abi.encodeWithSignature("getSecretsKeys()"),
            abi.encode(bytes32("apikey"), bytes32("0x1234567890"))
        );
    }

    function _makeValidRequest() internal returns (bytes32) {
        _setupValidUser();

        vm.startPrank(user);
        args = new string[](1);
        args[0] = validGiftCode;
        bytes32 reqId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        reqIdToAddr[reqId] = user;
        reqIdToGiftCode[reqId] = args[0];

        return reqId;
    }

    function _setupValidUser() internal {
        vm.stopPrank();
        vm.prank(owner);
        getGift.addToAllowList(user);
    }

    function _encodeRequest(string memory giftCode, uint8 slotId, uint64 version)
        internal
        pure
        returns (bytes memory)
    {
        string[] memory _args = new string[](1);
        _args[0] = giftCode;
        return abi.encode(_args, slotId, version);
    }
}
