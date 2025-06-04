// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TokenSwapComposer} from "../src/TokenSwapComposer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployAndTestSwap is Script {
    // Polygon Mainnet Addresses
    address constant POLYGON_STARGATE_USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // Input USDT (ensure this is the one your contract receives)
    address constant POLYGON_USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;          // Bridged USDC (USDC.e)
    address constant POLYGON_NCT = 0xD838290e877E0188a4A44700463419ED96c16107;           // Nature Carbon Tonne (Target Token)
    
    address constant POLYGON_UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // Uniswap V3 SwapRouter02
    address constant POLYGON_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;       // Ensure correct for LZ v2 on Polygon
    
    // Pool Fee Tiers (VERIFY THESE ARE CORRECT FOR THE TOKEN PAIRS AND LIQUIDITY)
    uint24  constant USDT_USDC_POOL_FEE = 500;  // 0.05% (assumed for POLYGON_STARGATE_USDT -> POLYGON_USDC)
    uint24  constant USDC_NCT_POOL_FEE = 10000; // 1% (for POLYGON_USDC -> POLYGON_NCT)

    // Test parameters
    uint256 amountToSwap = 0.01 * 10**6; // 0.01 STARGATE_USDT (6 decimals)
    uint256 minAmountOutNCT = 1;       // Min 1 wei of NCT - YOU MUST ADJUST THIS to a realistic value!

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying TokenSwapComposer for STARGATE_USDT -> USDC -> NCT swap using Uniswap V3...");
        TokenSwapComposer tokenSwapComposer = new TokenSwapComposer(
            POLYGON_STARGATE_USDT,
            POLYGON_USDC,
            POLYGON_NCT,
            POLYGON_LZ_ENDPOINT,
            POLYGON_UNISWAP_V3_ROUTER,
            USDT_USDC_POOL_FEE,
            USDC_NCT_POOL_FEE
        );
        console.log("TokenSwapComposer deployed at:", address(tokenSwapComposer));

        console.log("--- Starting Test Swap (STARGATE_USDT to NCT) ---");
        console.log("Deployer Address:", deployerAddress);

        uint256 usdtBalanceBefore = IERC20(POLYGON_STARGATE_USDT).balanceOf(deployerAddress);
        uint256 nctBalanceBefore = IERC20(POLYGON_NCT).balanceOf(deployerAddress);
        console.log("STARGATE_USDT balance before swap (6 dec):", usdtBalanceBefore);
        console.log("NCT balance before swap (18 dec):", nctBalanceBefore);

        require(usdtBalanceBefore >= amountToSwap, "Deployer has insufficient STARGATE_USDT for test swap");

        console.log("Approving TokenSwapComposer to spend deployer's STARGATE_USDT...");
        IERC20(POLYGON_STARGATE_USDT).approve(address(tokenSwapComposer), amountToSwap);
        
        console.log("Encoding test data (sender, recipient, minAmountOutNCT)...");
        address testSender = deployerAddress; 
        address testRecipient = deployerAddress; 
        bytes memory composedTestData = abi.encode(testSender, testRecipient, minAmountOutNCT);

        console.log("Calling testSwap on TokenSwapComposer...");
        tokenSwapComposer.testSwap(
            amountToSwap,
            composedTestData
        );
        console.log("testSwap call completed.");

        uint256 usdtBalanceAfter = IERC20(POLYGON_STARGATE_USDT).balanceOf(deployerAddress);
        uint256 nctBalanceAfter = IERC20(POLYGON_NCT).balanceOf(deployerAddress);
        console.log("STARGATE_USDT balance after swap (6 dec):", usdtBalanceAfter);
        console.log("NCT balance after swap (18 dec):", nctBalanceAfter);

        uint256 usdtSpent = usdtBalanceBefore - usdtBalanceAfter;
        uint256 nctReceived = nctBalanceAfter - nctBalanceBefore;

        console.log("--- Test Swap Summary (STARGATE_USDT to NCT) ---");
        console.log("STARGATE_USDT Spent (raw): ", usdtSpent);
        console.log("NCT Received (raw): ", nctReceived);
        
        require(nctReceived >= minAmountOutNCT, "Did not receive enough NCT");

        vm.stopBroadcast();
    }
} 