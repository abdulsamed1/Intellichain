// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "lib/chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract GetGift is FunctionsClient, ERC721URIStorage, ReentrancyGuard {
    /**
     * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
     * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
     * DO NOT USE THIS CODE IN PRODUCTION.
     */
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;
    string public result;
    mapping(address => bool) private allowList;
    mapping(string => bool) private giftCodeRedeemed;
    mapping(bytes32 => address) private reqIdToAddr;
    mapping(bytes32 => string) private reqIdToGiftCode;
    uint256 public tokenId;
    /// @dev true while a Chainlink request awaits fulfillment: enforcing this
    /// prevents orphaning an earlier request (its store entry never fulfills)
    bool public requestIdInFlight;

    error UnexpectedRequestID(bytes32 requestId);
    error CallerNotAllowlisted();
    error CodeAlreadyRedeemed();
    error RequestAlreadyInFlight();
    error InvalidGiftCode();
    error InvalidRecipient();

    event Response(bytes32 indexed requestId, bytes response, bytes err);
    event GiftRedeemed(bytes32 indexed requestId, address indexed recipient, string giftCode, string giftName, uint256 indexed tokenId);
    event GiftCodeReleased(string giftCode);

    // Gift codes and NFT metadata (saved on IPFS)
    mapping(bytes => string) giftToTokenUri;
    bytes constant ITEM_1 = bytes("100 discount");
    bytes constant ITEM_2 = bytes("50 discount");
    bytes constant ITEM_3 = bytes("1-month premium");

    string constant ITEM_1_METADATA = "ipfs://QmaGqBNqHazCjSMNMuDk6VrgjNLMQKNZqaab1vfMHAwkoj";
    string constant ITEM_2_METADATA = "ipfs://QmfNhhpUezQLcyqXBGL4ehPwo7Gfbwk9yy3YcJqGgr9dPb";
    string constant ITEM_3_METADATA = "ipfs://QmNxq7GqehZf9SpCEFK7C4moxZTZPNwCer5yCAqCBNdk2a";

    // Router and DON ID are injected at deployment time (per-network values
    // from script/utility/NetworkConfigLibrary.sol), not hardcoded — the same
    // bytecode serves every network and test suites can inject their own mock
    // router. Public immutables keep the getters tested in GetGiftInitTest.
    address public immutable ROUTER_ADDR;

    bytes32 public immutable DON_ID;

    uint32 public constant CALLBACK_GAS_LIMIT = 300_000;

    // Hardcode javascript code that is to sent to DON
    // REPLACE THE SUPBASE PROJECT NAME in js code below:
    // "url: `https://<SUPBASE_PROJECT_NAME>.supabase.co/rest/v1/<TABLE_NAME>?select=<COLUMN_NAME1>,<COLUMN_NAME2>`,"
    // TABLE_NAME is the name of table created in step 1.
    // COLUMN_NAMES are names of columns to be search, in the case, they are gift_code and gift_name.

    string public constant SOURCE = "const giftCode = args[0];"
        'if(!secrets.apikey) { throw Error("Error: Supabase API Key is not set!") };' "const apikey = secrets.apikey;"
        "const apiResponse = await Functions.makeHttpRequest({"
        'url: "https://flofeywjrxcklrizkgdg.supabase.co/rest/v1/Gifts?select=gift_name,gift_code",' 'method: "GET",'
        'headers: { "apikey": apikey}' "});" "if (apiResponse.error) {" "console.error(apiResponse.error);"
        'throw Error("Request failed: " + apiResponse.message);' "};" "const { data } = apiResponse;"
        "const item = data.find(item => item.gift_code == giftCode);"
        'if(item == undefined) {return Functions.encodeString("not found")};'
        "return Functions.encodeString(item.gift_name);";

    constructor(address router, bytes32 donId) FunctionsClient(router) ERC721("Gift", "GT") {
        ROUTER_ADDR = router;
        DON_ID = donId;
        allowList[msg.sender] = true;
        giftToTokenUri[ITEM_1] = ITEM_1_METADATA;
        giftToTokenUri[ITEM_2] = ITEM_2_METADATA;
        giftToTokenUri[ITEM_3] = ITEM_3_METADATA;
    }

    /**
     * @notice Send a simple request
     * @param subscriptionId Billing ID
     */
    function sendRequest(
        uint8 donHostedSecretsSlotID,
        uint64 donHostedSecretsVersion,
        string[] memory args,
        uint64 subscriptionId,
        address userAddr
    ) external onlyAllowList returns (bytes32 requestId) {
        // validate before sending a PAID Functions request
        if (args.length == 0) revert InvalidGiftCode();
        string memory giftCode = args[0];
        if (bytes(giftCode).length == 0) revert InvalidGiftCode();
        if (userAddr == address(0)) revert InvalidRecipient();

        // make sure the code is redeemable: it is CLAIMED atomically here and
        // released again in fulfillRequest if the code turns out unusable —
        // two in-flight requests can therefore never both mint the same code
        if (giftCodeRedeemed[giftCode]) revert CodeAlreadyRedeemed();
        giftCodeRedeemed[giftCode] = true;

        // enforce the one-request-in-flight invariant: a second request while
        // one awaits fulfillment would orphan the first (s_lastRequestId
        // mismatch on its callback) and burn its LINK. Checked after the
        // per-code claim so a duplicate code surfaces CodeAlreadyRedeemed.
        if (requestIdInFlight) revert RequestAlreadyInFlight();
        requestIdInFlight = true;

        // send the Chainlink Functions request with DON hosted secret
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(SOURCE);
        if (donHostedSecretsVersion > 0) {
            req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);
        }
        if (args.length > 0) req.setArgs(args);
        s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, CALLBACK_GAS_LIMIT, DON_ID);

        reqIdToAddr[s_lastRequestId] = userAddr;
        reqIdToGiftCode[s_lastRequestId] = giftCode;
        return s_lastRequestId;
    }

    /**
     * @notice Store latest result/error
     * @param requestId The request ID, returned by sendRequest()
     * @param response Aggregated response from the user code
     * @param err Aggregated error from the user code or from the execution pipeline
     * Either response or error parameter will be set, but never both
     */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId);
        }

        // this request is no longer awaiting fulfillment
        requestIdInFlight = false;
        s_lastResponse = response;
        s_lastError = err;

        emit Response(requestId, s_lastResponse, s_lastError);

        // copy the fulfill bookkeeping we still need, then free the storage
        // slots for the next request
        address userAddr = reqIdToAddr[requestId];
        string memory giftCode = reqIdToGiftCode[requestId];
        delete reqIdToAddr[requestId];
        delete reqIdToGiftCode[requestId];

        // fulfillment failed: the code was claimed at request time, so release
        // it — the code stays redeemable
        if (err.length != 0) {
            _releaseGiftCode(giftCode);
            return;
        }

        // the oracle says the code is unknown: release and claim nothing
        if (keccak256(response) == keccak256(abi.encode("not found"))) {
            _releaseGiftCode(giftCode);
            return;
        }

        // Decode the response to the gift type
        string memory giftType = abi.decode(response, (string));
        string memory tokenUri = giftToTokenUri[bytes(giftType)];

        // The oracle validated the code but the contract has no registered
        // metadata for this gift type: do NOT mint an empty-metadata token;
        // release the code so admin can addGift() and the user can retry
        if (bytes(tokenUri).length == 0) {
            _releaseGiftCode(giftCode);
            return;
        }

        // All checks passed: mint the gift NFT and record the redemption
        uint256 redeemedTokenId = safeMint(userAddr, tokenUri);
        emit GiftRedeemed(requestId, userAddr, giftCode, giftType, redeemedTokenId);
    }

    /// @dev Releases a claimed gift code (error / unknown-code / unknown-gift-type paths)
    function _releaseGiftCode(string memory giftCode) internal {
        giftCodeRedeemed[giftCode] = false;
        emit GiftCodeReleased(giftCode);
    }

    function safeMint(address to, string memory uri) internal nonReentrant returns (uint256 tokenNumber) {
        tokenNumber = tokenId;
        _safeMint(to, tokenNumber);
        _setTokenURI(tokenNumber, uri);
        tokenId++;
    }

    function addGift(string memory giftName, string memory _tokenUri) external onlyAllowList {
        giftToTokenUri[bytes(giftName)] = _tokenUri;
    }

    function addToAllowList(address addrToAdd) external onlyAllowList {
        allowList[addrToAdd] = true;
    }

    function removeFromAllowList() external onlyAllowList {
        allowList[msg.sender] = false;
    }

    modifier onlyAllowList() {
        if (!allowList[msg.sender]) revert CallerNotAllowlisted();
        _;
    }
}