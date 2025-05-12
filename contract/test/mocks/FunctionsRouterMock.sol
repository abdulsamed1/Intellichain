// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FunctionsRouterMock {
    error OnlyRouterOwner();
    error InvalidSubscription();
    error InvalidConsumer();

    bytes32 public constant REQUEST_DATA_VERSION = "1.0.0";

    mapping(uint64 => address) public s_subscriptionOwner;
    mapping(uint64 => bool) public s_isSubscriptionValid;
    mapping(uint64 => mapping(address => bool)) public s_consumers;

    event RequestSent(bytes32 indexed id);
    event RequestFulfilled(bytes32 indexed id);

    function sendRequest(
        uint16 donHostedSecretsSlotID,
        uint64 donHostedSecretsVersion,
        string[] calldata args,
        uint64 subscriptionId,
        address consumer
    ) external returns (bytes32) {
        if (!s_isSubscriptionValid[subscriptionId]) revert InvalidSubscription();
        if (!s_consumers[subscriptionId][consumer]) revert InvalidConsumer();

        bytes32 requestId = keccak256(
            abi.encode(subscriptionId, consumer, donHostedSecretsSlotID, donHostedSecretsVersion, args, block.timestamp)
        );

        emit RequestSent(requestId);
        return requestId;
    }

    function handleOracleFulfillment(bytes32 requestId, bytes memory response, bytes memory err)
        external
        returns (bool success)
    {
        // Call the consumer contract's fulfillRequest function
        bytes memory payload =
            abi.encodeWithSignature("handleOracleFulfillment(bytes32,bytes,bytes)", requestId, response, err);

        (bool callSuccess,) = msg.sender.call(payload);
        require(callSuccess, "Oracle fulfillment failed");

        emit RequestFulfilled(requestId);
        return true;
    }

    function createSubscription() external returns (uint64 subscriptionId) {
        subscriptionId = uint64(block.timestamp);
        s_subscriptionOwner[subscriptionId] = msg.sender;
        s_isSubscriptionValid[subscriptionId] = true;
        return subscriptionId;
    }

    function addConsumer(uint64 subscriptionId, address consumer) external {
        require(s_subscriptionOwner[subscriptionId] == msg.sender, "Router: not subscription owner");
        s_consumers[subscriptionId][consumer] = true;
    }

    function setSubscriptionValid(uint64 subscriptionId, bool isValid) external {
        s_isSubscriptionValid[subscriptionId] = isValid;
    }
}
