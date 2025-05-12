// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FunctionsV1EventsMock {
    // solhint-disable-next-line gas-struct-packing
    struct Config {
        uint16 maxConsumersPerSubscription;
        uint72 adminFee;
        bytes4 handleOracleFulfillmentSelector;
        uint16 gasForCallExactCheck;
        uint32[] maxCallbackGasLimits;
    }

    event ConfigUpdated(Config param1);
    event RequestProcessed(
        bytes32 indexed requestId,
        uint64 indexed subscriptionId,
        uint96 totalCostJuels,
        address transmitter,
        uint8 resultCode,
        bytes response,
        bytes err,
        bytes callbackReturnData
    );
    event RequestTimedOut(bytes32 indexed requestId);

    function emitRequestProcessed(
        bytes32 requestId,
        uint64 subscriptionId,
        uint96 totalCostJuels,
        address transmitter,
        uint8 resultCode,
        bytes memory response,
        bytes memory err,
        bytes memory callbackReturnData
    ) public {
        emit RequestProcessed(
            requestId, subscriptionId, totalCostJuels, transmitter, resultCode, response, err, callbackReturnData
        );
    }

    function emitRequestTimedOut(bytes32 requestId) public {
        emit RequestTimedOut(requestId);
    }
}
