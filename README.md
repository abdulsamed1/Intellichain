### WHAT THIS REPO IS

This repo uses the **ElizaOS Agentic AI framework** to create an AI agent that interacts with your input (via terminal or Twitter!).

You give the agent a gift code and your wallet address, and it will mint a gift NFT for you on the **Sepolia Network**.

The agent uses custom actions that interact with [Chainlink Functions](https://docs.chain.link/chainlink-functions).

> 📚 The full GitBook walkthrough and tutorial is available at:  
> [https://cll-devrel.gitbook.io/elizaos-functions-twitter/](https://cll-devrel.gitbook.io/elizaos-functions-twitter/)

---

## How to Use API Keys in Chainlink Functions?

Before Chainlink Functions can send an API call, it needs to know the **Supabase API key** to communicate with our database. Chainlink Functions provides two ways to store secrets:

1. **DON-hosted secrets**
2. **Off-chain secrets**

> ⚠️ Regardless of which method you choose, secrets are always encrypted using **threshold encryption** for security.  
> Instead of relying on a centralized private key, the DON (Decentralized Oracle Network) partitions a master key into shards, where each node holds only one piece. This ensures high availability and fault tolerance.

---

### In This Workshop: Storing Secrets in DON

We’ll be uploading the Supabase API key directly to the DON. Before we can do that, we must encrypt the key using the DON’s master key.

To help with this process, we use the `@chainlink/functions-toolkit` NPM library, which allows us to encrypt and upload secrets securely.

---

## Steps to Upload a Secret to Chainlink Functions

We’ve prepared a GitHub repository for today’s demo, which includes all the necessary scripts.

### 1. Clone the Repository

```bash
git clone -b for-sepolia https://github.com/abdulsamed1/Eliza-Chainlink-Functions.git
```

### 2. Install Dependencies

```bash
cd Eliza-Chainlink-Functions
pnpm install
```

### 3. Edit `.env` File


---

### 5. Encrypt and Upload the Secret

Run the script to encrypt and upload your Supabase API key to the DON:

```bash
cd Eliza-Chainlink-Functions
node ./scripts/uploadToDON.js
```

If successful, you'll see output similar to:

```
Make request...
Upload encrypted secret to gateways https://01.functions-gateway.testnet.chain.link/, https://02.functions-gateway.testnet.chain.link/. Slot ID: 0. Expiration in minutes: 1440

✅ Secrets uploaded properly to gateways!
Gateways response: { version: 1739510832, success: true }

donHostedSecretsVersion is 1739510832, Saved info to donSecretsInfo.txt
```

The secret version is saved in the file `donSecretsInfo.txt`.

> ⏳ The secret will expire in **24 hours**. If you need to update it before expiration, simply run the command again — the old secret will be overwritten.
