# Deployment and Interaction Guide

This guide explains how to use the Foundry scripts to deplo andd interact with the GetGift contract.

## Prerequisites

1. Foundry installed (forge, cast, anvil)
2. make sure your env is used to set environment variables for the contract example


- get your API key from https://etherscan.io/apidashboard

- get your RPC URL from https://www.alchemy.com/
- get your contract address from https://sepolia.etherscan.io/address/
- get your wallet address from https://sepolia.etherscan.io/address/0xCe
- get your private key :(https://awesamarth.hashnode.dev/the-best-way-to-import-your-private-key-in-foundry)

---

###  Deploy the GetGift Contract

```bash
cd contract
make deploy
```

This will:
- Deploy the GetGift contract
- Log the contract address and configuration

Save the deployed contract address for future interactions.

###   Verify The Contract after deploy contract

```bash
cd contract
make verify
```


###  Add Addresses to Allow List (if needed)

```bash
forge script script/InteractWithGetGift.s.sol:InteractWithGetGift --sig "addToAllowList(address,address)" <getgift_contract_address> <address_to_add> --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

###  Add Custom Gift Types (if needed)

```bash
forge script script/InteractWithGetGift.s.sol:InteractWithGetGift --sig "addGift(address,string,string)" <getgift_contract_address> "New Gift Name" "ipfs://your-ipfs-cid" --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

###  Redeem a Gift Code

```bash
forge script script/InteractWithGetGift.s.sol:InteractWithGetGift --sig "redeemGiftCode(address,string,uint8,uint64)" <getgift_contract_address> "GIFT123" <slot_id> <secrets_version> --rpc-url <your_rpc_url> --private-key <your_private_key> --broadcast
```

Replace:
- `GIFT123` with the gift code to redeem
- `<slot_id>` with the DON secrets slot ID
- `<secrets_version>` with the DON secrets version

###  Check Response and NFT Minting Status

```bash
forge script script/DecodeResponse.s.sol:DecodeResponse --sig "decodeLastResponse(address)" <getgift_contract_address> --rpc-url <your_rpc_url>
```

###  View Token Information

```bash
forge script script/DecodeResponse.s.sol:DecodeResponse --sig "getTokenInfo(address,uint256)" <getgift_contract_address> <token_id> --rpc-url <your_rpc_url>
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


   ---


### 🛡️ Real-World Use Case:

Imagine you’re deploying to Goerli and Mainnet using automation. With your private key stored in `PRIVATE_KEY`, your script can dynamically choose RPCs and perform deployments securely:

```bash
forge create --rpc-url $GOERLI_RPC --private-key $PRIVATE_KEY ...

```

Perfect for **CI/CD pipelines**, testnets, or even scheduled governance actions.

---

## 🧠 Quick Recap:

- You **converted a mnemonic to a private key** using `cast wallet private-key`.
- Use **environment variables** or a `.env` file to store the key securely.
- You can now **interact** (`cast send`, `forge create`) without retyping or copying keys.
- Keep your mnemonic **out of all code/config files**.