# 🎓 Project Documentation: AI-Powered NFT Gifting Agent

## 🧠 Overview
This project demonstrates a hybrid Web3/Web2 AI Agent system that allows users to receive NFTs simply by replying to a tweet. It uses:

- **Eliza Framework** for creating and running AI agents.
- **Chainlink Functions** to bridge off-chain inputs with on-chain smart contract actions.
- **Supabase** for secure and scalable off-chain data storage (e.g., gift codes).

---

## 📌 Features
- AI Agent (via Eliza) listens to Twitter for natural language NFT requests.
- Processes inputs using an LLM (e.g., GPT) to understand context.
- Checks gift code validity in Supabase.
- Triggers Chainlink Function to mint NFT on Avalanche Fuji testnet.
- Sends NFT to wallet address mentioned in the tweet.

---

## 🏗️ Architecture

```
User Tweet  --->  Eliza Agent  --->  LLM  --->  Supabase (verify code)
                                  |                     ↓
                                  |--------> Chainlink Function
                                                        ↓
                                                Smart Contract (Mint NFT)
```

---

## 📦 Tech Stack
- **AI Agent**: [ElizaOS](https://github.com/eliza-ai/elizaos)
- **LLM**: OpenAI / GPT-style
- **Database**: Supabase (PostgreSQL + API)
- **Oracle Bridge**: Chainlink Functions
- **Blockchain**: Avalanche Fuji Testnet
- **Testing**: Foundry Toolkit
- **Auditing**: Slither + Cyfrinup

---

## 🚀 Setup Guide

### 1. Using Docker
Use the docker image. It includes our project in a single image. /home/share will be mounted to /share in the container.

```bash
docker pull ????????????????
```

###To share a directory in the container:
```bash
docker run -it -v /home/share:/share image ????????????
```


### 2. Supabase Setup

- Create a project at [supabase.com](https://supabase.com)
- Create `gift_codes` table:
  
  ```sql
  CREATE TABLE gift_codes (
    id SERIAL PRIMARY KEY,
    code TEXT UNIQUE NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    claimed_by TEXT,
    created_at TIMESTAMP DEFAULT now()
  );
  ```
- Get Supabase URL and `anon` key.


### 3.This project depends on:

- OpenZeppelin Contracts
- Chainlink contracts

To install all dependencies:

```bash
make install
```

### 4. Eliza Agent Configuration
Set up your Eliza Agent with Twitter client and Supabase plugin. Define:
- Natural language pattern recognition
- Gift code verification via REST call
- Trigger to Chainlink Functions when valid

### 5. Chainlink Functions Setup
- Deploy your on-chain contract to Fuji
- Set up off-chain source code for Chainlink Functions to:
  - Receive input (wallet address)
  - Trigger minting logic

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
- [Eliza GitHub](https://github.com/eliza-ai/elizaos)
- [Chainlink Functions Docs](https://docs.chain.link/functions)
- [Supabase Docs](https://supabase.com/docs)
- [Avalanche Fuji](https://docs.avax.network/build/subnet/testnet-fuji)

