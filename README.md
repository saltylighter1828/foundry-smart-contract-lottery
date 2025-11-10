# 🎟️ Raffle Smart Contract  

**Author:** Antony Cheng | **Solidity:** 0.8.19 | **License:** MIT  

A provably fair lottery system powered by **Chainlink VRF v2.5**. Players enter by paying an entrance fee, and at set intervals, a random winner is picked automatically.  

---

## 🚀 Features

- **Fair randomness** via Chainlink VRF  
- **Enter the raffle** by sending ETH ≥ entrance fee  
- **Automatic winner selection** at configurable intervals  
- **Secure ETH transfer** using CEI pattern  
- **Event logging** for easy front-end integration  
- **Gas-efficient custom errors**  

---

## ⚡ Quick Example

```solidity
Raffle raffle = new Raffle(
    0.01 ether,         // entrance fee
    300,                // interval in seconds
    vrfCoordinatorAddr, // VRF Coordinator
    keyHash,            // gas lane / key hash
    subscriptionId,     // Chainlink subscription
    100000              // callback gas limit
);

raffle.enterRaffle{value: 0.01 ether}();
📊 Contract Overview
States: OPEN (accepting entries), CALCULATING (selecting winner)

Events: RaffleEntered, WinnerPicked, RequestedRaffleWinner

Errors: Raffle__SendMoreToEnterRaffle, Raffle__TransferFailed, Raffle__RaffleNotOpen, Raffle__UpkeepNotNeeded

Key Functions: enterRaffle(), checkUpkeep(), performUpkeep(), fulfillRandomWords()

🛠 Deployment Notes
Fund a Chainlink VRF subscription (v2.5)

Configure contract constructor parameters: entrance fee, interval, VRF Coordinator, key hash, subscription ID, callback gas limit

Deploy using Foundry, Hardhat, or Remix

✅ Security Highlights
Checks-Effects-Interactions (CEI) pattern

Only opens raffle when conditions are met

Random winner chosen using provably fair VRF

Reset state securely after each raffle round

📂 Repository Structure
bash
Copy code
contracts/
    Raffle.sol
lib/
    chainlink-brownie-contracts/
test/
    RaffleTest.t.sol
foundry.toml
README.md
📈 Next Steps
Integrate with a frontend to visualize entries and winners

Add Foundry tests to cover all edge cases

Extend for multiple raffle rounds or token-based entries