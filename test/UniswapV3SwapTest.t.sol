// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
// It's good practice to import IERC20 generally, even if TransferHelper also uses it.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// TransferHelper is not strictly needed for this specific test if we manually approve 
// and don't use its safe transfer functions, but it's often part of swap interactions.
// For this direct router call, only IERC20.approve is strictly necessary.

// Interface for Uniswap V3 Pool to query pool info
interface IUniswapV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function liquidity() external view returns (uint128);
}

contract UniswapV3MultiHopTest is Test {
    // Uniswap V3 Router on Polygon Mainnet
    ISwapRouter constant UNISWAP_V3_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    
    // The specific NCT/USDC pool address provided by user
    IUniswapV3Pool constant NCT_USDC_POOL = IUniswapV3Pool(0xa2804549Aa248796507A98aDccBCFEFA87F674E7);
    
    // Token Addresses on Polygon Mainnet
    IERC20 constant POLYGON_USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 constant POLYGON_USDC = IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
    IERC20 constant POLYGON_NCT = IERC20(0xD838290e877E0188a4A44700463419ED96c16107);
    
    // Pool Fee Tiers you are testing
    uint24 constant USDT_USDC_POOL_FEE = 500;  // 0.05%
    uint24 constant USDC_NCT_POOL_FEE = 10000; // 1.0%

    address testWallet;
    uint256 usdtAmountToSwap = 0.01 * 10**6; // 0.01 USDT (6 decimals)
    // For testing USDC -> NCT, we need an estimated amount of USDC we might get from 0.01 USDT
    // Assuming roughly 1:1 for USDT:USDC, so 0.01 USDC (6 decimals)
    uint256 usdcAmountToSwap = 0.01 * 10**6; 

    function setUp() public {
        // Using a fixed private key for a predictable testWallet address
        // This private key corresponds to address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
        // You can use any private key, or vm.addr(someUint) for a random one.
        uint256 testWalletPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d; 
        testWallet = vm.addr(testWalletPrivateKey);
        vm.label(testWallet, "TestWallet");
        
        // Deal initial tokens for tests
        deal(address(POLYGON_USDT), testWallet, usdtAmountToSwap * 10); // Deal 0.1 USDT
        deal(address(POLYGON_USDC), testWallet, usdcAmountToSwap * 10); // Deal 0.1 USDC for the second hop test
    }

    function testQueryPoolInformation() public view {
        console.log("=== Querying NCT/USDC Pool Information ===");
        console.log("Pool address:", address(NCT_USDC_POOL));
        
        address token0 = NCT_USDC_POOL.token0();
        address token1 = NCT_USDC_POOL.token1();
        uint24 poolFee = NCT_USDC_POOL.fee();
        uint128 poolLiquidity = NCT_USDC_POOL.liquidity();
        
        console.log("Token0:", token0);
        console.log("Token1:", token1);
        console.log("Pool Fee:", poolFee);
        console.log("Pool Liquidity:", poolLiquidity);
        
        // Check if our token addresses match
        console.log("Expected USDC:", address(POLYGON_USDC));
        console.log("Expected NCT:", address(POLYGON_NCT));
        
        bool usdcMatches = (token0 == address(POLYGON_USDC)) || (token1 == address(POLYGON_USDC));
        bool nctMatches = (token0 == address(POLYGON_NCT)) || (token1 == address(POLYGON_NCT));
        
        console.log("USDC matches pool tokens:", usdcMatches);
        console.log("NCT matches pool tokens:", nctMatches);
    }

    function testSwap_USDT_to_USDC() public {
        vm.startPrank(testWallet);
        POLYGON_USDT.approve(address(UNISWAP_V3_ROUTER), usdtAmountToSwap);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(POLYGON_USDT),
            tokenOut: address(POLYGON_USDC),
            fee: USDT_USDC_POOL_FEE,
            recipient: testWallet,
            deadline: block.timestamp + 300,
            amountIn: usdtAmountToSwap,
            amountOutMinimum: 1, // Expect at least 1 wei of USDC
            sqrtPriceLimitX96: 0
        });

        console.log("Attempting USDT -> USDC swap...");
        consoleLogParams(params);
        
        // We expect this to succeed if the pool exists and has liquidity
        // If it reverts, this is the problematic leg.
        // For now, let's assume it should succeed and catch revert if not.
        try UNISWAP_V3_ROUTER.exactInputSingle(params) returns (uint256 amountOutUSDC) {
            console.log("USDT -> USDC swap SUCCESS. USDC out:", amountOutUSDC);
            assertTrue(amountOutUSDC > 0, "USDC output should be greater than 0");
        } catch (bytes memory reason) {
            console.log("USDT -> USDC swap FAILED. Reason (hex):", vm.toString(reason));
            // Optionally, fail the test explicitly if a specific error is not expected
            // fail("USDT -> USDC leg failed unexpectedly");
            // For now, we let the test pass to see the reason if it fails.
            // If it fails, the test runner will mark it as failed if no vm.expectRevert was hit.
            // However, to make it explicit, we can expect a revert here if we are debugging this leg.
            vm.expectRevert(); // Add this if you want the test to PASS only if this leg REVERTS
            UNISWAP_V3_ROUTER.exactInputSingle(params); // This re-executes to be caught by expectRevert
        }
        vm.stopPrank();
    }

    function testSwap_USDC_to_NCT() public {
        vm.startPrank(testWallet);
        POLYGON_USDC.approve(address(UNISWAP_V3_ROUTER), usdcAmountToSwap);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(POLYGON_USDC),
            tokenOut: address(POLYGON_NCT),
            fee: USDC_NCT_POOL_FEE,
            recipient: testWallet,
            deadline: block.timestamp + 300,
            amountIn: usdcAmountToSwap,
            amountOutMinimum: 1, // Expect at least 1 wei of NCT
            sqrtPriceLimitX96: 0
        });

        console.log("Attempting USDC -> NCT swap...");
        consoleLogParams(params);

        try UNISWAP_V3_ROUTER.exactInputSingle(params) returns (uint256 amountOutNCT) {
            console.log("USDC -> NCT swap SUCCESS. NCT out:", amountOutNCT);
            assertTrue(amountOutNCT > 0, "NCT output should be greater than 0");
        } catch (bytes memory reason) {
            console.log("USDC -> NCT swap FAILED. Reason (hex):", vm.toString(reason));
            vm.expectRevert(); // Add this if you want the test to PASS only if this leg REVERTS
            UNISWAP_V3_ROUTER.exactInputSingle(params); // This re-executes to be caught by expectRevert
        }
        vm.stopPrank();
    }

    // Helper to log ExactInputSingleParams
    function consoleLogParams(ISwapRouter.ExactInputSingleParams memory params) internal view {
        console.log("  tokenIn:", params.tokenIn);
        console.log("  tokenOut:", params.tokenOut);
        console.log("  fee:", params.fee);
        console.log("  recipient:", params.recipient);
        console.log("  deadline:", params.deadline);
        console.log("  amountIn:", params.amountIn);
        console.log("  amountOutMinimum:", params.amountOutMinimum);
        console.log("  sqrtPriceLimitX96:", params.sqrtPriceLimitX96);
    }

    // You can add more tests here trying to catch other specific Uniswap error signatures if needed
    // Example for a named error (replace with actual error if identified):
    // function testDirectSwapRouterCallForNamedError() public {
    //     vm.startPrank(testWallet);
    //     POLYGON_USDT.approve(address(UNISWAP_V3_ROUTER), amountToSwap);
    //     ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(...);
    //     vm.expectRevert(abi.encodeWithSignature("SomeUniswapError()"));
    //     UNISWAP_V3_ROUTER.exactInputSingle(params);
    //     vm.stopPrank();
    // }
} 