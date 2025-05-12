// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {GetGift} from "../src/GetGift.sol";
import {GetGiftScript} from "script/GetGift.s.sol";
import {FunctionsClient} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRouter} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsRouter.sol";
import {FunctionsRequest} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsResponse} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsResponse.sol";
import {FunctionsV1EventsMock} from "./mocks/FunctionsV1EventsMock.sol";
import {FunctionsRouterMock} from "./mocks/FunctionsRouterMock.sol";

// Contract under test
contract GetGiftTest is Test {
    using FunctionsRequest for FunctionsRequest.Request;

    // Constants
    address constant ROUTER_ADDR = address(0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0);
    bytes32 constant DON_ID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;
    uint64 constant SUBSCRIPTION_ID = 1;
    uint32 constant CALLBACK_GAS_LIMIT = 300_000;

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

    // Contract instance
    GetGift public getGift;
    GetGiftScript public getGiftScript;

    // Mock routers for testing
    FunctionsV1EventsMock mockEventsRouter;
    FunctionsRouterMock mockRouter;

    function setUp() public {
        // Deploy mock routers first
        mockEventsRouter = new FunctionsV1EventsMock();
        mockRouter = new FunctionsRouterMock();

        // Deploy GetGiftScript
        getGiftScript = new GetGiftScript();

        // Deploy GetGift contract directly (not through script for testing)
        vm.startPrank(owner);
        getGift = new GetGift();
        vm.stopPrank();

        // Store mock router code at the router address
        vm.etch(ROUTER_ADDR, address(mockRouter).code);

        // Configure subscription and consumer
        vm.startPrank(owner);
        subscriptionId = mockRouter.createSubscription();
        mockRouter.addConsumer(subscriptionId, address(getGift));
        mockRouter.setSubscriptionValid(subscriptionId, true);
        vm.stopPrank();

        // Initialize test data
        args = new string[](1);

        // Mock the router's send request response
        vm.mockCall(
            ROUTER_ADDR, abi.encodeWithSelector(FunctionsRouter.sendRequest.selector), abi.encode(bytes32(uint256(1)))
        );
    }

    // Helper function to properly format router fulfillment data with event expectation
    function _fulfillRequest(bytes32 _requestId, bytes memory _response, bytes memory _err) internal {
        vm.startPrank(ROUTER_ADDR);

        // First emit the event through the events mock
        mockEventsRouter.emitRequestProcessed(_requestId, SUBSCRIPTION_ID, COST, ROUTER_ADDR, 0, _response, _err, "");

        // Then prepare the fulfillment call
        bytes memory payload =
            abi.encodeWithSignature("handleOracleFulfillment(bytes32,bytes,bytes)", _requestId, _response, _err);

        // Call the fulfillment function directly through the mock router
        bool success;
        bytes memory returnData;
        (success, returnData) = address(getGift).call(payload);

        // If the call fails with a revert reason, capture and handle it
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returnDataSize := mload(returnData)
                    revert(add(32, returnData), returnDataSize)
                }
            }
            revert("Fulfillment call failed without reason");
        }

        vm.stopPrank();
    }

    // Test accounts
    address owner = address(1);
    address stranger = address(2);
    address user = address(3);

    // Test data
    string[] args;
    string constant validGiftCode = "100 discount";
    string constant invalidGiftCode = "invalid code";
    bytes32 requestId;
    string constant SOURCE = "testing source code";

    // Events from FunctionsClient that we need to handle
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

    // ============ Constructor Tests ============
    function test_Constructor_InitializesCorrectly() public view {
        assertTrue(getGift.getAllowList(owner), "Owner should be allowlisted");
        assertEq(getGift.ROUTER_ADDR(), ROUTER_ADDR, "Router address should match");
        assertEq(getGift.DON_ID(), DON_ID, "DON ID should match");
    }

    // ============ Access Control Tests ============
    function test_OwnerIsAllowlisted() public view {
        assertTrue(getGift.getAllowList(owner));
    }

    function test_StrangerNotAllowlisted() public view {
        assertFalse(getGift.getAllowList(stranger));
    }

    function test_AddToAllowList_ByOwner() public {
        vm.prank(owner);
        getGift.addToAllowList(stranger);
        assertTrue(getGift.getAllowList(stranger));
    }

    function test_AddToAllowList_RevertIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(GetGift.UserNotAllowed.selector, stranger));
        vm.prank(stranger);
        getGift.addToAllowList(stranger);
    }

    function test_RemoveFromAllowList() public {
        vm.startPrank(owner);
        getGift.removeFromAllowList();
        assertFalse(getGift.getAllowList(owner));
        vm.stopPrank();
    }

    // ============ Request Tests ============
    function test_SendRequest_ValidGiftCode() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        args[0] = validGiftCode;
        bytes32 reqId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        assertEq(reqId, getGift.lastRequestId());
        vm.stopPrank();
    }

    function test_SendRequest_RevertIfCodeRedeemed() public {
        // Setup
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        string[] memory firstArgs = new string[](1);
        firstArgs[0] = validGiftCode;

        // First request and fulfillment
        vm.startPrank(user);
        bytes32 firstReqId = getGift.sendRequest(1, 1, firstArgs, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes memory validResponse = abi.encode("100 discount");
        _fulfillRequest(firstReqId, validResponse, new bytes(0));

        assertTrue(getGift.getgiftCodeRedeemed(validGiftCode), "Code should be marked as redeemed");

        // Try to reuse the same code
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(GetGift.CodeAlreadyRedeemed.selector, validGiftCode));
        getGift.sendRequest(1, 1, firstArgs, SUBSCRIPTION_ID, user);
        vm.stopPrank();
    }

    function test_SendRequest_RevertIfEmptyArgs() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert("args is empty");
        getGift.sendRequest(1, 1, new string[](0), SUBSCRIPTION_ID, user);
        vm.stopPrank();
    }

    function test_SendRequest_RevertIfNotInAllowList() public {
        vm.startPrank(stranger);
        args[0] = validGiftCode;
        vm.expectRevert(abi.encodeWithSelector(GetGift.UserNotAllowed.selector, stranger));
        getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, stranger);
        vm.stopPrank();
    }

    function test_SendRequest_RevertIfInvalidSubscriptionId() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        vm.startPrank(user);
        args[0] = validGiftCode;

        // Should revert with our custom error
        vm.expectRevert(abi.encodeWithSelector(GetGift.InvalidSubscription.selector, 0));
        getGift.sendRequest(1, 1, args, 0, user);
        vm.stopPrank();
    }

    // Helper function to setup test state with a valid user
    function _setupValidUser() internal {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        args[0] = validGiftCode;
    }

    // Helper function to make a valid request
    function _makeValidRequest() internal returns (bytes32) {
        _setupValidUser();

        vm.startPrank(user);
        bytes32 reqId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        return reqId;
    }

    // ============ Fulfillment Tests ============
    function test_FulfillRequest_ValidResponse() public {
        // Setup request
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        // Prepare response
        bytes memory validResponse = abi.encode("100 discount");
        bytes memory emptyError;

        // Mock fulfillment through FunctionsClient's handleOracleFulfillment
        _fulfillRequest(requestId, validResponse, emptyError);

        assertEq(getGift.lastResponse(), validResponse);
        assertTrue(getGift.getgiftCodeRedeemed(validGiftCode));
    }

    function test_FulfillRequest_InvalidResponse() public {
        // Setup request
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        // Prepare invalid response
        bytes memory invalidResponse = abi.encode("not found");
        bytes memory emptyError;

        // Mock fulfillment through handleOracleFulfillment
        _fulfillRequest(requestId, invalidResponse, emptyError);

        assertEq(getGift.lastResponse(), invalidResponse);
        assertFalse(getGift.getgiftCodeRedeemed(validGiftCode));
    }

    function test_FulfillRequest_RevertIfUnexpectedRequestId() public {
        bytes memory response = abi.encode("100 discount");
        bytes memory emptyError;
        bytes32 wrongRequestId = bytes32(uint256(1));

        vm.prank(ROUTER_ADDR);
        vm.expectRevert(abi.encodeWithSelector(GetGift.UnexpectedRequestID.selector, wrongRequestId));
        bool success;
        (success,) = address(getGift).call(
            abi.encodeWithSignature(
                "handleOracleFulfillment(bytes32,bytes,bytes)", wrongRequestId, response, emptyError
            )
        );
    }

    function test_FulfillRequest_RevertIfNotRouter() public {
        bytes memory response = abi.encode("100 discount");
        bytes memory emptyError;

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(FunctionsClient.OnlyRouterCanFulfill.selector));
        bool success;
        (success,) = address(getGift).call(
            abi.encodeWithSignature("handleOracleFulfillment(bytes32,bytes,bytes)", requestId, response, emptyError)
        );
    }

    function test_FulfillRequest_Success_WithEmptyError() public {
        // Setup request
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes memory validResponse = abi.encode("100 discount");
        bytes memory emptyError = new bytes(0);

        _fulfillRequest(requestId, validResponse, emptyError);

        assertEq(getGift.lastResponse(), validResponse);
        assertTrue(getGift.getgiftCodeRedeemed(validGiftCode));
        assertEq(getGift.lastError(), emptyError);
    }

    function test_FulfillRequest_Success_WithError() public {
        // Setup request
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes memory response = new bytes(0);
        bytes memory error = abi.encode("Test error");

        _fulfillRequest(requestId, response, error);

        assertEq(getGift.lastResponse(), response);
        assertEq(getGift.lastError(), error);
        assertFalse(getGift.getgiftCodeRedeemed(validGiftCode));
    }

    // ============ NFT Tests ============
    function test_NFTMinting_AfterValidFulfillment() public {
        // Setup and send request
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        // Fulfill with valid response
        bytes memory validResponse = abi.encode("100 discount");
        bytes memory emptyError;

        // Store the current tokenId before minting
        uint256 currentTokenId = getGift.tokenId();

        _fulfillRequest(requestId, validResponse, emptyError);

        // Check NFT minting with the correct token ID
        assertEq(getGift.ownerOf(currentTokenId), user);
        assertEq(getGift.tokenId(), currentTokenId + 1);
    }

    function test_NFTMinting_RevertIfInvalidURI() public {
        // Setup request with invalid response (non-existent token URI)
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes memory invalidResponse = abi.encode("invalid gift");
        bytes memory emptyError;

        vm.prank(ROUTER_ADDR);
        vm.expectRevert();
        bool success;
        (success,) = address(getGift).call(
            abi.encodeWithSignature(
                "handleOracleFulfillment(bytes32,bytes,bytes)", requestId, invalidResponse, emptyError
            )
        );
    }

    function test_NFT_TokenURIMatchesGift() public {
        // Setup and fulfill valid request
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes memory validResponse = abi.encode("100 discount");
        bytes memory emptyError;

        _fulfillRequest(requestId, validResponse, emptyError);

        assertEq(
            getGift.tokenURI(0),
            "ipfs://QmaGqBNqHazCjSMNMuDk6VrgjNLMQKNZqaab1vfMHAwkoj",
            "Token URI should match the gift type"
        );
    }

    // ============ Utility Tests ============
    function test_GetGiftCodeRedeemed() public {
        assertFalse(getGift.getgiftCodeRedeemed(validGiftCode));

        // Setup and fulfill a valid request
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        _fulfillRequest(requestId, abi.encode("100 discount"), new bytes(0));

        assertTrue(getGift.getgiftCodeRedeemed(validGiftCode));
    }

    function test_GetAllowList() public {
        assertTrue(getGift.getAllowList(owner));
        assertFalse(getGift.getAllowList(stranger));

        vm.prank(owner);
        getGift.addToAllowList(stranger);
        assertTrue(getGift.getAllowList(stranger));

        vm.prank(owner);
        getGift.removeFromAllowList();
        assertFalse(getGift.getAllowList(owner));
    }

    // ============ Request Building Tests ============
    function test_BuildValidRequest() public pure {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(SOURCE);
        req.addDONHostedSecrets(DON_HOSTED_SECRETS_SLOT, DON_HOSTED_SECRETS_VERSION);
        string[] memory testArgs = new string[](1);
        testArgs[0] = validGiftCode;
        req.setArgs(testArgs);

        bytes memory encodedRequest = req.encodeCBOR();
        assertTrue(encodedRequest.length > 0, "Request should be properly encoded");
    }

    function test_RequestWithMultipleArgs() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        string[] memory multiArgs = new string[](2);
        multiArgs[0] = validGiftCode;
        multiArgs[1] = "additional_param";

        vm.startPrank(user);
        bytes32 reqId =
            getGift.sendRequest(DON_HOSTED_SECRETS_SLOT, DON_HOSTED_SECRETS_VERSION, multiArgs, SUBSCRIPTION_ID, user);
        assertEq(reqId, getGift.lastRequestId());
        vm.stopPrank();
    }

    // ============ Extended NFT Tests ============
    function test_NFTMinting_ReentrantRequest() public {
        // Setup request
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        bytes memory validResponse = abi.encode("100 discount");
        bytes memory emptyError;

        // First fulfillment should succeed
        _fulfillRequest(requestId, validResponse, emptyError);

        // Second fulfillment should fail with UnexpectedRequestID
        vm.startPrank(ROUTER_ADDR);
        vm.expectRevert(abi.encodeWithSelector(GetGift.UnexpectedRequestID.selector, requestId));
        address(getGift).call(
            abi.encodeWithSignature(
                "handleOracleFulfillment(bytes32,bytes,bytes)", requestId, validResponse, emptyError
            )
        );
        vm.stopPrank();
    }

    function test_NFT_BatchMinting() public {
        vm.startPrank(owner);
        getGift.addToAllowList(user);
        vm.stopPrank();

        string[] memory codes = new string[](3);
        codes[0] = "code1";
        codes[1] = "code2";
        codes[2] = "code3";

        string[] memory request = new string[](1);
        uint256 expectedTokenId = 0;

        for (uint256 i = 0; i < 3; i++) {
            // Send request
            vm.startPrank(user);
            request[0] = codes[i];
            bytes32 reqId = getGift.sendRequest(1, 1, request, SUBSCRIPTION_ID, user);
            vm.stopPrank();

            // Fulfill request
            bytes memory validResponse = abi.encode("100 discount");
            _fulfillRequest(reqId, validResponse, new bytes(0));

            // Verify NFT was minted correctly
            assertEq(getGift.ownerOf(expectedTokenId), user);
            assertTrue(getGift.getgiftCodeRedeemed(codes[i]));
            expectedTokenId++;
        }

        // Verify final token ID
        assertEq(getGift.tokenId(), 3);
    }

    // ============ Edge Cases and Response Variations ============
    function test_FulfillRequest_DifferentGiftTypes() public {
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;
        requestId = getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        vm.stopPrank();

        // Different gift types responses
        bytes[] memory responses = new bytes[](3);
        responses[0] = abi.encode("100 discount");
        responses[1] = abi.encode("50 discount");
        responses[2] = abi.encode("1-month premium");

        // First response should succeed
        _fulfillRequest(requestId, responses[0], new bytes(0));
        assertTrue(getGift.getgiftCodeRedeemed(validGiftCode));

        // Subsequent responses should revert
        vm.expectRevert(abi.encodeWithSelector(GetGift.UnexpectedRequestID.selector, requestId));
        (bool success,) = address(getGift).call(
            abi.encodeWithSignature(
                "handleOracleFulfillment(bytes32,bytes,bytes)", requestId, responses[1], new bytes(0)
            )
        );

        vm.expectRevert(abi.encodeWithSelector(GetGift.UnexpectedRequestID.selector, requestId));
        (success,) = address(getGift).call(
            abi.encodeWithSignature(
                "handleOracleFulfillment(bytes32,bytes,bytes)", requestId, responses[2], new bytes(0)
            )
        );

        vm.stopPrank();
    }

    // ============ Gas Usage Tests ============
    function test_GasUsage_SendRequest() public {
        vm.prank(owner);
        getGift.addToAllowList(user);

        vm.startPrank(user);
        args[0] = validGiftCode;

        uint256 gasBefore = gasleft();
        getGift.sendRequest(1, 1, args, SUBSCRIPTION_ID, user);
        uint256 gasUsed = gasBefore - gasleft();

        assertTrue(gasUsed < GAS_LIMIT, "Gas usage should be reasonable");
        vm.stopPrank();
    }
}
