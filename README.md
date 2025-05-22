# GetGift Contract Deployment and Interaction Guide

This guide explains how to use the Foundry scripts to deploy and interact with the GetGift contract.

## Prerequisites

1. Foundry installed (forge, cast, anvil)
2. Chainlink Functions subscription (for testnet deployment)
3. Supabase API key (for database interaction)

## Setup

1. Create your Supabase database with a `Gifts` table containing columns:
   - `gift_code`: The unique code to redeem a gift
   - `gift_name`: The name/type of the gift (must match one of the gift types in the contract)

2. Ensure your Foundry.toml file has the correct remappings:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@chainlink/=lib/chainlink/",
    "@openzeppelin/=lib/openzeppelin-contracts/"
]
```

## Script Usage

### 1. Deploy the GetGift Contract

```bash
forge script script/DeployGetGift.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

This will:
- Deploy the GetGift contract
- Log the contract address and configuration

Save the deployed contract address for future interactions.

### 2. Create Chainlink Functions Subscription (if not already created)

```bash
forge script script/CreateSubscription.s.sol:CreateSubscription --sig "createSubscription()" --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

Save the subscription ID output from this command.

### 3. Fund the Subscription

```bash
forge script script/CreateSubscription.s.sol:CreateSubscription --sig "fundSubscription(uint64,uint96)" <subscription_id> <amount_in_juels> --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

Example to fund with 1 LINK:
```bash
forge script script/CreateSubscription.s.sol:CreateSubscription --sig "fundSubscription(uint64,uint96)" 123 1000000000000000000 --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

### 4. Add Contract as Consumer to Subscription

```bash
forge script script/CreateSubscription.s.sol:CreateSubscription --sig "addConsumer(uint64,address)" <subscription_id> <getgift_contract_address> --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

### 5. Upload Secrets to DON (Decentralized Oracle Network)

For this step, you'll need to use the Chainlink Functions CLI:

```bash
npx hardhat functions-upload-secrets --network <network_name> --slot <slot_id> --environment <environment_name>
```

To generate the required JSON file:

```bash
forge script script/UploadSecrets.s.sol:UploadSecrets --sig "createSecretsJsonFile(string)" <your_supabase_api_key> --rpc-url <your_rpc_url>
```

### 6. Add Addresses to Allow List (if needed)

```bash
forge script script/InteractWithGetGift.s.sol:InteractWithGetGift --sig "addToAllowList(address,address)" <getgift_contract_address> <address_to_add> --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

### 7. Add Custom Gift Types (if needed)

```bash
forge script script/InteractWithGetGift.s.sol:InteractWithGetGift --sig "addGift(address,string,string)" <getgift_contract_address> "New Gift Name" "ipfs://your-ipfs-cid" --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

### 8. Redeem a Gift Code

```bash
forge script script/InteractWithGetGift.s.sol:InteractWithGetGift --sig "redeemGiftCode(address,string,uint8,uint64)" <getgift_contract_address> "GIFT123" <slot_id> <secrets_version> --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

Replace:
- `GIFT123` with the gift code to redeem
- `<slot_id>` with the DON secrets slot ID
- `<secrets_version>` with the DON secrets version

### 9. Check Response and NFT Minting Status

```bash
forge script script/DecodeResponse.s.sol:DecodeResponse --sig "decodeLastResponse(address)" <getgift_contract_address> --rpc-url <your_rpc_url>
```

### 10. View Token Information

```bash
forge script script/DecodeResponse.s.sol:DecodeResponse --sig "getTokenInfo(address,uint256)" <getgift_contract_address> <token_id> --rpc-url <your_rpc_url>
```

## Testing with Anvil (Local Development)

For local testing, start Anvil:

```bash
anvil
```

Then deploy and interact with your contract using the Anvil RPC URL:

```bash
forge script script/DeployGetGift.s.sol --rpc-url http://localhost:8545 --private-key <anvil_private_key> --broadcast
```

## Troubleshooting

1. If you encounter errors related to Chainlink Functions, check:
   - Subscription is properly funded
   - Contract is added as a consumer
   - Secrets are properly uploaded
   - DON ID and Router address are correct for the network

2. If NFTs aren't minting after gift code redemption:
   - Verify the gift code exists in your Supabase database
   - Check that the gift_name in the database matches one of the gift types in the contract
   - Use the DecodeResponse script to check for any errors

3. For authorization errors:
   - Ensure the transaction sender is on the allow list
   - The contract deployer is automatically added to the allow list