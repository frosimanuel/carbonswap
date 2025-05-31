// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TokenSwapComposer} from "../src/TokenSwapComposer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExecuteSwap is Script {
    // Polygon Mainnet Addresses - Ensure these are consistent with your TokenSwapComposer deployment
    address constant POLYGON_USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address constant POLYGON_NCT = 0xD838290e877E0188a4A44700463419ED96c16107; // Target token

    // --- Script Configuration ---
    // Amount of USDT to swap (0.01 USDT)
    uint256 amountToSwap = 0.01 * 10**6; 
    
    // Minimum amount of NCT you expect to receive for the amountToSwap
    // YOU MUST SET THIS TO A REALISTIC VALUE BASED ON CURRENT USDT/NCT PRICE AND LIQUIDITY!
    // This is critical to avoid reverts or bad swaps.
    // Example: If 0.01 USDT should get ~5 NCT, set this to slightly less, e.g., 4.9 * 10**18
    uint256 minNCTOut = 0.00001 * 10**18; // Placeholder - CHANGE THIS!

    function run(address _tokenSwapComposerAddress) external {
        require(_tokenSwapComposerAddress != address(0), "TokenSwapComposer address cannot be zero");

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        TokenSwapComposer tokenSwapComposer = TokenSwapComposer(_tokenSwapComposerAddress);

        console.log("--- Executing Swap on Existing Contract ---    ");
        console.log("TokenSwapComposer Address:", _tokenSwapComposerAddress);
        console.log("Deployer/Recipient Address:", deployerAddress);
        console.log("Swapping", amountToSwap / (10**6), "USDT for NCT...");
        console.log("Minimum NCT expected (18 dec):", minNCTOut);

        // Check initial balances
        uint256 usdtBalanceBefore = IERC20(POLYGON_USDT).balanceOf(deployerAddress);
        uint256 nctBalanceBefore = IERC20(POLYGON_NCT).balanceOf(deployerAddress);
        console.log("USDT balance before (6 dec):", usdtBalanceBefore);
        console.log("NCT balance before (18 dec):", nctBalanceBefore);

        require(usdtBalanceBefore >= amountToSwap, "Deployer has insufficient USDT for swap");

        console.log("Approving TokenSwapComposer to spend deployer's USDT...");
        IERC20(POLYGON_USDT).approve(address(tokenSwapComposer), amountToSwap);
        
        console.log("Encoding swap data (sender, recipient, minAmountOut)...");
        // For this script, deployerAddress acts as both the sender (original initiator for test context)
        // and the recipient of the swapped NCT tokens.
        address testSender = deployerAddress;
        address testRecipient = deployerAddress;
        bytes memory composedSwapData = abi.encode(testSender, testRecipient, minNCTOut);

        console.log("Calling testSwap on TokenSwapComposer with encoded data...");
        tokenSwapComposer.testSwap(
            amountToSwap,
            composedSwapData
        );
        console.log("testSwap call completed.");

        // Check final balances
        uint256 usdtBalanceAfter = IERC20(POLYGON_USDT).balanceOf(deployerAddress);
        uint256 nctBalanceAfter = IERC20(POLYGON_NCT).balanceOf(deployerAddress);
        console.log("USDT balance after (6 dec):", usdtBalanceAfter);
        console.log("NCT balance after (18 dec):", nctBalanceAfter);

        uint256 usdtSpent = usdtBalanceBefore - usdtBalanceAfter;
        uint256 nctReceived = nctBalanceAfter - nctBalanceBefore;

        console.log("--- Swap Summary (USDT to NCT) ---    ");
        console.log("USDT Spent (raw): ", usdtSpent);
        console.log("NCT Received (raw): ", nctReceived);
        
        require(nctReceived >= minNCTOut, "Did not receive enough NCT as per minNCTOut");
        console.log("Successfully swapped USDT for NCT!");

        vm.stopBroadcast();
    }
} 