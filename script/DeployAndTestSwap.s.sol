// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TokenSwapComposer} from "../src/TokenSwapComposer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract DeployAndTestSwap is Script {
    // Polygon Mainnet Addresses
    address constant POLYGON_USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address constant POLYGON_NCT = 0xD838290e877E0188a4A44700463419ED96c16107; // Nature Carbon Tonne
    address constant POLYGON_QUICKSWAP_ROUTER = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address constant POLYGON_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c; // Example, ensure correct for LZ v2

    // Test parameters
    uint256 amountToSwap = 0.01 * 10**6; // 0.01 USDT (USDT has 6 decimals)
    // Placeholder: 0.01 USDT should get *some* NCT. NCT has 18 decimals.
    // YOU MUST ADJUST THIS BASED ON THE ACTUAL USDT/NCT PRICE AND LIQUIDITY.
    // Setting a very low value for now to pass the check, e.g., 0.00001 NCT.
    uint256 minAmountOut = 0.00001 * 10**18; // Expected 0.00001 NCT - ADJUST THIS!

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy TokenSwapComposer
        console.log("Deploying TokenSwapComposer for USDT -> NCT swap...");
        TokenSwapComposer tokenSwapComposer = new TokenSwapComposer(
            POLYGON_USDT,
            POLYGON_LZ_ENDPOINT, 
            POLYGON_QUICKSWAP_ROUTER,
            POLYGON_NCT // Swapping to NCT now
        );
        console.log("TokenSwapComposer deployed at:", address(tokenSwapComposer));

        // 2. Test the swap
        console.log("--- Starting Test Swap (USDT to NCT) ---");
        console.log("Deployer Address:", deployerAddress);

        // Check initial balances
        uint256 usdtBalanceBefore = IERC20(POLYGON_USDT).balanceOf(deployerAddress);
        uint256 nctBalanceBefore = IERC20(POLYGON_NCT).balanceOf(deployerAddress);
        console.log("USDT balance before swap (6 dec):", usdtBalanceBefore);
        console.log("NCT balance before swap (18 dec):", nctBalanceBefore);

        require(usdtBalanceBefore >= amountToSwap, "Deployer has insufficient USDT for test swap");

        console.log("Approving TokenSwapComposer to spend deployer's USDT...");
        IERC20(POLYGON_USDT).approve(address(tokenSwapComposer), amountToSwap);
        
        console.log("Encoding test data (sender, recipient, minAmountOut)...");
        // For testing, we'll use deployerAddress as both sender and recipient
        address testSender = deployerAddress;
        address testRecipient = deployerAddress;
        bytes memory composedTestData = abi.encode(testSender, testRecipient, minAmountOut);

        console.log("Calling testSwap on TokenSwapComposer with encoded data...");
        tokenSwapComposer.testSwap(
            amountToSwap,
            composedTestData
        );
        console.log("testSwap call completed.");

        // Check final balances
        uint256 usdtBalanceAfter = IERC20(POLYGON_USDT).balanceOf(deployerAddress);
        uint256 nctBalanceAfter = IERC20(POLYGON_NCT).balanceOf(deployerAddress);
        console.log("USDT balance after swap (6 dec):", usdtBalanceAfter);
        console.log("NCT balance after swap (18 dec):", nctBalanceAfter);

        uint256 usdtSpent = usdtBalanceBefore - usdtBalanceAfter;
        uint256 nctReceived = nctBalanceAfter - nctBalanceBefore;

        console.log("--- Test Swap Summary (USDT to NCT) ---");
        console.log("USDT Spent (raw): ", usdtSpent);
        console.log("NCT Received (raw): ", nctReceived);
        
        require(nctReceived >= minAmountOut, "Did not receive enough NCT");

        vm.stopBroadcast();
    }
} 