# CarbonSwap: Polygon Smart Contract for NCT Acquisition

This repository houses `TokenSwapComposer.sol`, a Solidity smart contract designed to operate on the Polygon network. It acts as the destination-chain component in the [LayerGreen platform's](https://github.com/deca12x/CarbonOffset/) cross-chain workflow, automatically swapping bridged assets (USDT) for tokenized carbon credits (NCT - Nature Carbon Tonne).

**Our Vision:** To provide a transparent and automated mechanism on Polygon for converting bridged funds into tangible, verifiable carbon offsets, completing the user's journey to neutralize their carbon footprint.

## Overview

The `TokenSwapComposer.sol` contract is a LayerZero `ILayerZeroComposer`. Its primary role is:

1.  **Receive Assets:** It is triggered by a LayerZero message originating from the Flare Network (initiated by contracts in the [`CarbonHardhat` repository](https://github.com/deca12x/CarbonHardhat)). This message delivers USDT (bridged via Stargate's OFT) to this contract on Polygon.
2.  **Automated Swap:** Upon receiving the USDT and the compose message, the contract automatically executes a swap on a Decentralized Exchange (DEX) like QuickSwap.
3.  **Acquire Carbon Credits:** The USDT is swapped for NCT (Nature Carbon Tonne) tokens, which are ERC20 tokens representing verified carbon credits from the Toucan Protocol.
4.  **Deliver to Recipient:** The acquired NCT tokens are then sent to the user-specified recipient address on Polygon.

This contract is a key part of the **LayerZero Composability Track**, demonstrating how a cross-chain message can trigger a sequence of actions on the destination chain.

## Key Features

*   **LayerZero Composer:** Implements `ILayerZeroComposer` to seamlessly integrate with LayerZero's v2 messaging protocol.
*   **Automated Token Swap:** Swaps received USDT for NCT tokens using a configured DEX (QuickSwap).
*   **Polygon Native:** Deployed and operates on the Polygon network, the home of Toucan Protocol's NCT.
*   **Transparent & Verifiable:** All swaps and NCT acquisitions are on-chain transactions, verifiable on Polygon explorers like Blockscout.
*   **Error Handling:** Includes basic error handling to transfer the original USDT to the recipient if the swap fails.

## Contract: `TokenSwapComposer.sol`

*   **`constructor(address _stargateUsdt, address _layerzeroEndpoint, address _swapRouter, address _targetToken)`:**
    *   Initializes the contract with the addresses of:
        *   `_stargateUsdt`: The Stargate-bridged USDT token contract on Polygon.
        *   `_layerzeroEndpoint`: The LayerZero Endpoint contract on Polygon.
        *   `_swapRouter`: The QuickSwap (or other Uniswap V2-like) router address.
        *   `_targetToken`: The NCT token contract address on Polygon.
*   **`lzCompose(address _from, bytes32 _guid, bytes calldata _message, address _executor, bytes calldata _extraData)`:**
    *   The main entry point for LayerZero messages.
    *   Requires the caller to be the LayerZero Endpoint and the message to originate from the trusted Stargate USDT OFT contract.
    *   Decodes the `_message` to get the amount of USDT (`amountLD`) and the `composeMsg`.
    *   The `composeMsg` is further decoded to get the `sender` (original initiator on Flare), `recipient` (final NCT recipient on Polygon), and `minAmountOut` (minimum NCT expected from the swap).
    *   Approves the `SWAP_ROUTER` to spend the received USDT.
    *   Calls `executeSwap` to perform the token exchange.
*   **`testSwap(uint256 amountLD, bytes calldata composedTestData)`:**
    *   A public function for testing purposes.
    *   Allows an EOA to simulate the `lzCompose` flow by transferring USDT to the contract and then calling this function with encoded recipient and `minAmountOut` data.

## Technical Details

*   **Solidity Version:** `^0.8.19`
*   **Framework:** Foundry
*   **Key Dependencies:**
    *   `@openzeppelin/contracts`
    *   `@layerzerolabs/lz-evm-protocol-v2`
    *   `@layerzerolabs/lz-evm-oapp-v2`
*   **Target Network:** Polygon Mainnet (Chain ID: 137)
*   **DEX Integration:** QuickSwap (Uniswap V2 compatible)

## Project Repositories

This project is part of a larger ecosystem:

*   🌍 **`CarbonOffset`:** The frontend application providing the user interface.
    *   [https://github.com/deca12x/CarbonOffset/](https://github.com/deca12x/CarbonOffset/)
*   🔥 **`CarbonHardhat`:** Flare-side smart contracts for initiating the LayerZero bridge.
    *   [https://github.com/deca12x/CarbonHardhat](https://github.com/deca12x/CarbonHardhat)
*   🔄 **`carbonswap` (This Repository):** Polygon-side smart contract for swapping bridged assets into NCT.
    *   [https://github.com/frosimanuel/carbonswap](https://github.com/frosimanuel/carbonswap)

## Setup and Usage

### Prerequisites

-   [Foundry](https://getfoundry.sh/) (includes `forge` and `cast`)

### Environment Variables

Copy the `.env.example` file to `.env` and populate it with your details:
```bash
cp .env.example .env
```
Your `.env` file should look like this:
```env
POLYGON_RPC_URL=your_polygon_rpc_url
DEPLOYER_KEY=your_private_key_for_deployment_and_testing
ETHERSCAN_API_KEY=your_polygonscan_api_key # Optional, for contract verification on Blockscout/Polygonscan
```
*   `POLYGON_RPC_URL`: RPC endpoint for the Polygon network (e.g., from Ankr, Alchemy, Infura).
*   `DEPLOYER_KEY`: Private key of the account you want to use for deploying and testing. **Never commit this file with your actual private key to a public repository.**
*   `ETHERSCAN_API_KEY`: Your PolygonScan (or compatible Blockscout instance) API key if you want to verify contracts automatically.

### Installation of Dependencies

If the `lib` directory is not present or you need to update dependencies, run:
```bash
forge install
```
This will install dependencies based on `foundry.toml` and any git submodules (like `lib/forge-std`). Ensure your `remappings.txt` is correctly configured (Foundry typically handles this).

### Build

Compile the smart contracts:
```bash
forge build
```

### Running the Test Script (`DeployAndTestSwap.s.sol`)

The `DeployAndTestSwap.s.sol` script deploys the `TokenSwapComposer` contract and executes its `testSwap` function. This simulates receiving USDT, swapping it for NCT, and sending the NCT to the deployer.

**Important:**
*   The script uses live Polygon mainnet addresses for tokens (USDT, NCT) and QuickSwap.
*   **Crucially, ensure the `minAmountOut` variable in `script/DeployAndTestSwap.s.sol` is set to a realistic value based on the current market price of USDT vs. NCT to avoid reverts due to slippage.**
*   The deployer account needs sufficient MATIC for gas and USDT on Polygon for the test swap.

**To run the script (e.g., against a Polygon mainnet fork for safer testing):**
```bash
forge script script/DeployAndTestSwap.s.sol:DeployAndTestSwap --fork-url $POLYGON_RPC_URL --broadcast -vvvv
```
(Ensure `POLYGON_RPC_URL` is set in your environment or replace `$POLYGON_RPC_URL` with the actual URL).

**To run directly on Polygon mainnet (USE WITH CAUTION - real funds involved):**
```bash
forge script script/DeployAndTestSwap.s.sol:DeployAndTestSwap --rpc-url $POLYGON_RPC_URL --broadcast --verify -vvvv
```
*   `--verify`: Attempts to verify the contract on PolygonScan/Blockscout using the `ETHERSCAN_API_KEY`.

## Future Enhancements

*   Support for multiple DEXes or DEX aggregators for optimal swap rates.
*   Ability to swap for different types of tokenized carbon credits.
*   More sophisticated error handling and retry mechanisms for swaps.

---

Enabling automated and transparent carbon offsetting on Polygon.
