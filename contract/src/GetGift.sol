// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract GetGift is FunctionsClient, ERC721URIStorage, ReentrancyGuard {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public lastRequestId;
    bytes public lastResponse;
    bytes public lastError;

    string public result;
    mapping(address => bool) private allowList;
    mapping(string => bool) private giftCodeRedeemed;
    mapping(bytes32 => address) private reqIdToAddr;
    mapping(bytes32 => string) private reqIdToGiftCode;
    uint256 public tokenId;

    error UnexpectedRequestID(bytes32 requestId);
    error CodeAlreadyRedeemed(string giftCode);
    error InvalidSubscription(uint64 subscriptionId);
    error InvalidGiftType(string giftType);
    error UserNotAllowed(address user);

    event Response(bytes32 indexed requestId, bytes response, bytes err);

    // Gift codes and NFT metadata (saved on IPFS)
    mapping(bytes => string) private giftToTokenUri;
    bytes private constant ITEM_1 = bytes("100 discount");
    bytes private constant ITEM_2 = bytes("50 discount");
    bytes private constant ITEM_3 = bytes("1-month premium");

    string constant ITEM_1_METADATA = "ipfs://QmaGqBNqHazCjSMNMuDk6VrgjNLMQKNZqaab1vfMHAwkoj";
    string constant ITEM_2_METADATA = "ipfs://QmfNhhpUezQLcyqXBGL4ehPwo7Gfbwk9yy3YcJqGgr9dPb";
    string constant ITEM_3_METADATA = "ipfs://QmNxq7GqehZf9SpCEFK7C4moxZTZPNwCer5yCAqCBNdk2a";

    // Hardcode for Avalanche Fuji testnet
    address public constant ROUTER_ADDR = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    bytes32 public constant DON_ID = 0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;
    uint32 public constant CALLBACK_GAS_LIMIT = 300_000;

    string public constant SOURCE = "const giftCode = args[0];"
        'if(!secrets.apikey) { throw Error("Error: Supabase API Key is not set!") };' "const apikey = secrets.apikey;"
        "const apiResponse = await Functions.makeHttpRequest({"
        'url: "https://flofeywjrxcklrizkgdg.supabase.co/rest/v1/Gifts?select=gift_name,gift_code",' 'method: "GET",'
        'headers: { "apikey": apikey}' "});" "if (apiResponse.error) {" "console.error(apiResponse.error);"
        'throw Error("Request failed: " + apiResponse.message);' "};" "const { data } = apiResponse;"
        "const item = data.find(item => item.gift_code == giftCode);"
        'if(item == undefined) {return Functions.encodeString("not found")};'
        "return Functions.encodeString(item.gift_name);";

    constructor() FunctionsClient(ROUTER_ADDR) ERC721("Gift", "GT") {
        allowList[msg.sender] = true;
        giftToTokenUri[ITEM_1] = ITEM_1_METADATA;
        giftToTokenUri[ITEM_2] = ITEM_2_METADATA;
        giftToTokenUri[ITEM_3] = ITEM_3_METADATA;
        tokenId = 0;
    }

    function sendRequest(
        uint8 donHostedSecretsSlotID,
        uint64 donHostedSecretsVersion,
        string[] memory args,
        uint64 subscriptionId,
        address userAddr
    ) external onlyAllowList returns (bytes32) {
        if (subscriptionId == 0) {
            revert InvalidSubscription(subscriptionId);
        }
        require(args.length > 0, "args is empty");

        string memory giftCode = args[0];
        require(bytes(giftCode).length > 0, "Invalid gift code");
        if (giftCodeRedeemed[giftCode]) {
            revert CodeAlreadyRedeemed(giftCode);
        }

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(SOURCE);
        if (donHostedSecretsVersion > 0) {
            req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);
        }
        req.setArgs(args);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), subscriptionId, CALLBACK_GAS_LIMIT, DON_ID);
        lastRequestId = requestId;
        reqIdToAddr[requestId] = userAddr;
        reqIdToGiftCode[requestId] = giftCode;

        return requestId;
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err)
        internal
        override
        nonReentrant
    {
        if (requestId != lastRequestId) {
            revert UnexpectedRequestID(requestId);
        }

        lastResponse = response;
        lastError = err;
        emit Response(requestId, response, err);

        // Clear the request ID first to prevent reuse
        bytes32 currentRequestId = lastRequestId;
        lastRequestId = 0;

        if (err.length == 0 && response.length > 0) {
            address userAddr = reqIdToAddr[currentRequestId];
            string memory giftCode = reqIdToGiftCode[currentRequestId];
            require(userAddr != address(0), "Invalid user address");
            require(bytes(giftCode).length > 0, "Invalid gift code");

            if (giftCodeRedeemed[giftCode]) {
                revert CodeAlreadyRedeemed(giftCode);
            }

            (string memory giftType) = abi.decode(response, (string));
            if (keccak256(bytes(giftType)) == keccak256(bytes("not found"))) {
                return;
            }

            string memory tokenUri;
            bytes memory giftTypeBytes = bytes(giftType);

            if (keccak256(giftTypeBytes) == keccak256(ITEM_1)) {
                tokenUri = ITEM_1_METADATA;
            } else if (keccak256(giftTypeBytes) == keccak256(ITEM_2)) {
                tokenUri = ITEM_2_METADATA;
            } else if (keccak256(giftTypeBytes) == keccak256(ITEM_3)) {
                tokenUri = ITEM_3_METADATA;
            } else {
                revert InvalidGiftType(giftType);
            }

            require(bytes(tokenUri).length > 0, "Invalid token URI");

            // Perform state updates before external interactions (Checks-Effects-Interactions pattern)
            uint256 currentTokenId = tokenId;
            giftCodeRedeemed[giftCode] = true;
            tokenId = currentTokenId + 1;

            // External interactions last
            _safeMint(userAddr, currentTokenId);
            _setTokenURI(currentTokenId, tokenUri);

            // Clear the request mappings after successful fulfillment
            delete reqIdToAddr[currentRequestId];
            delete reqIdToGiftCode[currentRequestId];
        }
    }

    function addToAllowList(address addrToAdd) external onlyAllowList {
        allowList[addrToAdd] = true;
    }

    function removeFromAllowList() external onlyAllowList {
        allowList[msg.sender] = false;
    }

    modifier onlyAllowList() {
        if (!allowList[msg.sender]) {
            revert UserNotAllowed(msg.sender);
        }
        _;
    }

    function getgiftCodeRedeemed(string memory code) external view returns (bool) {
        return giftCodeRedeemed[code];
    }

    function getAllowList(address addr) external view returns (bool) {
        return allowList[addr];
    }
}
