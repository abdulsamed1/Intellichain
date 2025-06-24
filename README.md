## 🏗️ Workflow Summary

![System Diagram](img/image.jpg)


### 🛠 System Diagram

1. **User Tweet Reply**

   * User replies to a tweet with their wallet address and a claim code.

2. **AI Agent — [ElizaOS](https://github.com/elizaOS/eliza)**

   * Parses tweet to extract the wallet and code.
   * Validates user intent (e.g., claiming a gift).

3. **Chainlink Functions**

   * Securely calls Supabase to check if the code is valid and unused.

4. **Smart Contract (on Sepolia Testnet)**

   * Receives data from Chainlink.
   * Mints a gift token (NFT) if validation passes.

5. **User Receives Gift**

   * NFT or gift token is sent directly to the wallet.

---

### 🧩 Tech Stack

* **AI Agent**: [ElizaOS](https://github.com/eliza-ai/elizaos)
* **Data Storage**: [Supabase](w) (for gift codes)
* **Off-chain Logic**: [Chainlink Functions](https://functions.chain.link/)
* **On-chain Logic**: [Smart Contract](https://sepolia.etherscan.io/address/0x3437c36913b3f2f18a71f63750d0a35fbd6b2135) (minting and validation)
* **Testing Framework**: [Foundry](https://getfoundry.sh/)
* **Security Auditing**: [Slither](https://github.com/crytic/slither) + [CyfrinUp](https://github.com/Cyfrin/up)


---

## 🚀 Setup Guide

###  Using Docker
Use the docker image. It includes our project in a single image. /home/share will be mounted to /share in the container.

```bash
cd /home/youruser/your-project-directory
docker build -t intellichain:latest.
```

###To share a directory in the container:
```bash
docker run -it --rm -v "$(pwd)":/app /intellichain:latest bash
```

Installing the contract dependents:

```bash
cd contract
make install
```

---

## ✅ Use Cases
- Marketing campaigns: Reward users who engage with tweets.
- Event ticketing: Issue NFTs based on RSVP codes.
- Gaming: Claim in-game items through social media.
