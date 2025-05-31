// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// QuickSwap Router interface (Uniswap V2 style)
interface IQuickSwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract TokenSwapComposer is ILayerZeroComposer {
    address public immutable STARGATE_USDT; // This is the token received from Stargate/LayerZero
    address public immutable LAYERZERO_ENDPOINT;
    address public immutable SWAP_ROUTER;
    address public immutable TARGET_TOKEN; // This is the token we are swapping to (e.g., NCT)
    
    event SwapCompleted(address recipient, uint256 amountIn, uint256 amountOut);
    event SwapFailed(address recipient, uint256 amount);
    
    constructor(
        address _stargateUsdt,
        address _layerzeroEndpoint,
        address _swapRouter,
        address _targetToken // Updated parameter name
    ) {
        STARGATE_USDT = _stargateUsdt;
        LAYERZERO_ENDPOINT = _layerzeroEndpoint;
        SWAP_ROUTER = _swapRouter;
        TARGET_TOKEN = _targetToken; // Updated state variable assignment
    }
    
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        // Security checks
        require(msg.sender == LAYERZERO_ENDPOINT, "Only LZ Endpoint");
        require(_from == STARGATE_USDT, "Only from Stargate controlled token contract"); // Ensure it's the specific Stargate OFT/OApp
        
        // Decode the message
        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);
        
        // Decode the compose message (recipient for the final tokens, minAmountOut for the swap)
        (address sender, address recipient, uint256 minAmountOut) = abi.decode(composeMsg, (address, address, uint256));
        
        // Approve swap router to spend the received STARGATE_USDT
        IERC20(STARGATE_USDT).approve(SWAP_ROUTER, amountLD);
        
        // Try to swap using QuickSwap router
        try this.executeSwap(amountLD, minAmountOut, recipient) returns (uint256 amountOut) {
            emit SwapCompleted(recipient, amountLD, amountOut);
        } catch {
            // If swap fails, send the original STARGATE_USDT directly to recipient
            IERC20(STARGATE_USDT).transfer(recipient, amountLD);
            emit SwapFailed(recipient, amountLD);
        }
    }
    
    // Separate function to isolate try/catch, called by lzCompose and testSwap
    function executeSwap(uint256 amountIn, uint256 minAmountOut, address recipient) external returns (uint256) {
        require(msg.sender == address(this), "Only self via lzCompose or testSwap");
        
        // Create token path for QuickSwap: STARGATE_USDT -> TARGET_TOKEN
        address[] memory path = new address[](2);
        path[0] = STARGATE_USDT;
        path[1] = TARGET_TOKEN; // Use the generic TARGET_TOKEN
        
        // Execute swap using QuickSwap
        uint256[] memory amounts = IQuickSwapRouter(SWAP_ROUTER).swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            recipient, // The recipient of the TARGET_TOKEN
            block.timestamp + 300 // 5 minutes deadline
        );
        
        return amounts[1]; // Return amount of TARGET_TOKEN received
    }
    
    // For testing purposes - simulates receiving tokens and executing swap
    function testSwap(
        uint256 amountLD,    // Amount of STARGATE_USDT to swap
        bytes calldata composedTestData // Encoded (sender, recipient, minAmountOut)
    ) external {
        // Decode the composed test data
        (address sender, address recipient, uint256 minAmountOut) = abi.decode(composedTestData, (address, address, uint256));

        // Log the decoded sender for testing purposes, can be removed later
        // console.log("testSwap decoded sender:", sender);

        // Transfer STARGATE_USDT from msg.sender to this contract (simulating LZ transfer)
        IERC20(STARGATE_USDT).transferFrom(msg.sender, address(this), amountLD);
        
        // Approve router to spend the STARGATE_USDT held by this contract
        IERC20(STARGATE_USDT).approve(SWAP_ROUTER, amountLD);
        
        // Try to swap
        try this.executeSwap(amountLD, minAmountOut, recipient) returns (uint256 amountOut) {
            emit SwapCompleted(recipient, amountLD, amountOut);
        } catch {
            // If swap fails, send the original STARGATE_USDT (now held by this contract) directly to recipient
            IERC20(STARGATE_USDT).transfer(recipient, amountLD);
            emit SwapFailed(recipient, amountLD);
        }
    }
    
    // Allow receiving ETH (e.g., for gas refunds from LZ if configured)
    receive() external payable {}
} 

