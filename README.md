# Token Swap Composer Contract

This project contains a Solidity smart contract `TokenSwapComposer.sol` that is designed to be called by a LayerZero v2 OApp or OFT. It receives tokens (e.g., USDT) on a destination chain (e.g., Polygon) and swaps them for a target token (e.g., NCT) using a DEX like QuickSwap.

A deployment and test script `DeployAndTestSwap.s.sol` is included to demonstrate its functionality.

## Project Structure

```
swap-contract/
├── src/                      # Core smart contracts
│   └── TokenSwapComposer.sol
├── script/                   # Deployment and interaction scripts
│   └── DeployAndTestSwap.s.sol
├── lib/                      # Dependencies (installed via forge)
├── .env.example              # Example environment file
├── foundry.toml              # Foundry configuration
├── remappings.txt            # Solidity import remappings
└── README.md
```

## Prerequisites

- [Foundry](https://getfoundry.sh/) (includes `forge` and `cast`)
- Node.js and npm (if you plan to use JavaScript for additional tasks, not strictly required for this Solidity project)

## Setup

1.  **Clone the repository (if applicable) or navigate to the `swap-contract` directory.**

2.  **Install Dependencies:**
    If the `lib` directory is not committed, install the necessary libraries using Foundry:
    ```bash
    forge install foundry-rs/forge-std --no-commit
    forge install OpenZeppelin/openzeppelin-contracts --no-commit
    forge install LayerZero-Labs/lz-evm-protocol-v2 --no-commit
    forge install LayerZero-Labs/lz-evm-oapp-v2 --no-commit
    # Add any other dependencies listed in remappings.txt or imported in contracts
    ```
    Ensure your `remappings.txt` file is correctly set up to point to these installed libraries.

3.  **Set up Environment Variables:**
    Copy the `.env.example` file (or create a new `.env` file) and populate it with your details:
    ```bash
    cp .env.example .env
    ```
    Your `.env` file should look like this:
    ```
    POLYGON_RPC_URL=your_polygon_rpc_url
    DEPLOYER_KEY=your_private_key_for_deployment_and_testing
    ETHERSCAN_API_KEY=your_polygonscan_api_key # Optional, for contract verification
    ```
    -   `POLYGON_RPC_URL`: RPC endpoint for the Polygon network (e.g., from Alchemy, Infura).
    -   `DEPLOYER_KEY`: Private key of the account you want to use for deploying and testing. **Do not commit this file with your actual private key.**
    -   `ETHERSCAN_API_KEY`: Your PolygonScan API key if you want to verify contracts automatically.

## Build

Compile the smart contracts:
```bash
forge build
```

## Running the Test Script

The `DeployAndTestSwap.s.sol` script will deploy the `TokenSwapComposer` contract and execute its `testSwap` function. This function simulates receiving USDT, swapping it for the configured `TARGET_TOKEN` (e.g., NCT), and sending the `TARGET_TOKEN` to the deployer.

**Important:**
-   The script uses live Polygon mainnet addresses for tokens (USDT, NCT) and QuickSwap.
-   Ensure the `minAmountOut` variable in `script/DeployAndTestSwap.s.sol` is set to a reasonable value based on the current market price of USDT vs. the target token to avoid reverts due to slippage.

**To run the script against a Polygon mainnet fork (recommended for testing):**
```bash
forge script script/DeployAndTestSwap.s.sol:DeployAndTestSwap --fork-url $POLYGON_RPC_URL --broadcast -vvvv
```
This command uses the `POLYGON_RPC_URL` from your shell environment (or you can hardcode it). The `-vvvv` flag provides verbose output.

**To run the script directly on Polygon mainnet (use with caution):**
This will deploy contracts and execute transactions, costing real gas and using real tokens.
```bash
forge script script/DeployAndTestSwap.s.sol:DeployAndTestSwap --rpc-url $POLYGON_RPC_URL --broadcast --verify -vvvv
```
-   `--verify`: Attempts to verify the contract on PolygonScan using the `ETHERSCAN_API_KEY` from your `.env` file.

## Linter Errors

If you encounter linter errors like `Source "forge-std/Script.sol" not found`, ensure that:
1.  You have run `forge install` for all necessary dependencies (e.g., `forge-std`).
2.  The `lib` directory is present in your project root (`swap-contract/lib`).
3.  Your `remappings.txt` file is correctly configured (Foundry usually handles this well after `forge install`). It should look something like:
    ```
    forge-std/=lib/forge-std/src/
    @openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
    @layerzerolabs/lz-evm-protocol-v2/=lib/lz-evm-protocol-v2/contracts/
    @layerzerolabs/lz-evm-oapp-v2/=lib/lz-evm-oapp-v2/contracts/
    ```

## TokenSwapComposer Functionality

-   **`constructor`**: Initializes the contract with addresses for the input token (e.g., Stargate-bridged USDT), LayerZero endpoint, swap router (QuickSwap), and the target token to swap into.
-   **`lzCompose`**: The main function called by LayerZero. It decodes the incoming message to get the amount of input token and a composed message containing the final recipient address and the minimum amount of target token expected from the swap. It then approves the swap router and calls `executeSwap`.
-   **`executeSwap`**: Performs the token swap using the specified router and token path. It's designed to be called internally or via the `testSwap` function.
-   **`testSwap`**: A helper function for testing. It allows an external caller (EOA) to send input tokens to the contract and trigger a swap, simulating the token reception and swap process that `lzCompose` would handle.

This contract primarily focuses on the token swapping logic on the destination chain after tokens have been received via a LayerZero message.
