---
# 🧠 Overview

Tweet2NFT AI Bridge lets users claim NFTs by replying to tweets. It uses Eliza AI, Supabase for codes, and Chainlink to mint. It combines Web2 social with Web3 blockchain for secure, scalable rewards.

---

## 🏗️ Architecture

![Architecture Diagram](img/image.jpg)

---

## 📦 Tech Stack
- **AI Agent**: [ElizaOS](https://github.com/eliza-ai/elizaos)
- **LLM**: Qwen3-235B-A22B
- **Database**: Supabase (PostgreSQL + API)
- **Oracle Bridge**: Chainlink Functions DON
- **Blockchain**: Sepolia Testnet
- **Testing**: Foundry Toolkit
- **Auditing**: Slither + Cyfrinup


---

## 🚀 Setup Guide

###  Using Docker
Use the docker image. It includes our project in a single image. /home/share will be mounted to /share in the container.

```bash
docker pull ????????????????
```

###To share a directory in the container:
```bash
docker run -it -v /home/share:/share image ????????????
```

Installing dependencies for the contract :

```bash
cd contract
make install
```

---

## ✅ Use Cases
- Marketing campaigns: Reward users who engage with tweets.
- Event ticketing: Issue NFTs based on RSVP codes.
- Gaming: Claim in-game items through social media.

---

## 🛡️ Security Notes
- All gift codes are stored and verified **off-chain** for privacy.
- Smart contract uses access control to avoid abuse.
- Chainlink ensures decentralized and verifiable execution.

---

## 🔗 Links
- [Eliza GitHub]([https://github.com/eliza-ai/elizaos](https://github.com/elizaOS/eliza))
- [Chainlink Functions Docs]([https://docs.chain.link/functions](https://docs.chain.link/chainlink-functions))
