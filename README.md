Raffle Smart Contract Project
This project implements a decentralized, automated lottery system leveraging Chainlink VRF v2.5 for provable randomness and Chainlink Automation for trustless execution.

Project Description
A high-integrity "Set and Forget" lottery. Users enter by paying a set entrance fee. Once a specified time interval passes, Chainlink Automation triggers the contract to request a random number. The contract then identifies a winner, transfers the entire balance (prize pool), and resets itself for the next round.

Testing Overview
The suite utilizes Foundry for high-performance testing. Key areas covered:

State Transitions: Ensuring the raffle moves correctly between OPEN and CALCULATING.

Entry Logic: Validating entrance fees, player registration, and event emissions.

Upkeep Validation: Testing the checkUpkeep logic under various conditions (time, balance, state).

End-to-End Simulation: Using a Mock VRF Coordinator to simulate the fulfillment of randomness, prize distribution, and state resets.

Fuzz Testing: Proving that the VRF callback can only be triggered by the coordinator and handles varying request IDs.

Gas-Optimized Raffle.sol
To achieve maximum gas efficiency, this version utilizes:

immutable variables: Reduces gas for every read.

unchecked arithmetic: Saves gas on index increments where overflow is impossible.

Local variable caching: Minimizes expensive SLOAD operations from storage.

Custom Errors: Replaces expensive strings with 4-byte selectors.

Direct Transfer: Uses call for optimal ETH transfers.