// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ILayerZeroComposer} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Standard imports for Uniswap V3 Periphery contracts
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract TokenSwapComposer is ILayerZeroComposer {
    address public immutable STARGATE_USDT;      // The Stargate OFT USDT token address on Polygon (Input Token)
    address public immutable USDC_TOKEN;         // Address for USDC on Polygon (Intermediate Token)
    address public immutable TARGET_TOKEN;       // The final token to swap to (e.g., NCT)
    
    address public immutable LAYERZERO_ENDPOINT; // LayerZero Endpoint on Polygon
    address public immutable SWAP_ROUTER;        // Uniswap V3 SwapRouter02 address on Polygon

    uint24  public immutable USDT_USDC_POOL_FEE; // Uniswap V3 Pool Fee for STARGATE_USDT -> USDC_TOKEN
    uint24  public immutable USDC_NCT_POOL_FEE;  // Uniswap V3 Pool Fee for USDC_TOKEN -> TARGET_TOKEN (NCT)

    event SwapCompleted(address indexed recipient, uint256 amountIn, uint256 amountOutNCT);
    event SwapFailed(address indexed recipient, uint256 amount, bytes reason);

    constructor(
        address _stargateUsdt,       // e.g., 0xc2132D05D31c914a87C6611C10748AEb04B58e8F (Polygon USDT)
        address _usdcToken,          // e.g., 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359 (Polygon USDC.e)
        address _targetToken,        // e.g., 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 (Polygon NCT)
        address _layerzeroEndpoint,
        address _swapRouter,         // e.g., 0xE592427A0AEce92De3Edee1F18E0157C05861564 (Polygon V3 SwapRouter02)
        uint24  _usdtUsdcPoolFee,    // e.g., 500 (0.05%) or 100 (0.01%)
        uint24  _usdcNctPoolFee      // e.g., 2500 (0.25%)
    ) {
        STARGATE_USDT = _stargateUsdt;
        USDC_TOKEN = _usdcToken;
        TARGET_TOKEN = _targetToken;
        LAYERZERO_ENDPOINT = _layerzeroEndpoint;
        SWAP_ROUTER = _swapRouter;
        USDT_USDC_POOL_FEE = _usdtUsdcPoolFee;
        USDC_NCT_POOL_FEE = _usdcNctPoolFee;
    }

    function lzCompose(
        address _from, 
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        require(msg.sender == LAYERZERO_ENDPOINT, "TokenSwapComposer: Only LayerZero Endpoint");

        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);
        bytes memory composeMsg = OFTComposeMsgCodec.composeMsg(_message);
        
        (address senderOnSourceChain, address finalRecipient, uint256 minAmountOutNCT) = abi.decode(composeMsg, (address, address, uint256));

        try this.executeSwap(amountLD, minAmountOutNCT, finalRecipient) returns (uint256 amountOutNCT) {
            emit SwapCompleted(finalRecipient, amountLD, amountOutNCT);
        } catch (bytes memory reason) {
            TransferHelper.safeTransfer(STARGATE_USDT, finalRecipient, amountLD);
            emit SwapFailed(finalRecipient, amountLD, reason);
        }
    }

    function executeSwap(
        uint256 amountInUSDT,
        uint256 minAmountOutNCT, 
        address recipient
    ) external returns (uint256 amountOutNCT) {
        require(msg.sender == address(this), "TokenSwapComposer: Only self via lzCompose or testSwap");

        TransferHelper.safeApprove(STARGATE_USDT, SWAP_ROUTER, amountInUSDT);

        bytes memory path = abi.encodePacked(
            STARGATE_USDT,
            USDT_USDC_POOL_FEE,
            USDC_TOKEN,
            USDC_NCT_POOL_FEE,
            TARGET_TOKEN
        );

        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams({
                path: path,
                recipient: recipient,
                deadline: block.timestamp + 300, // 5 minutes
                amountIn: amountInUSDT,
                amountOutMinimum: minAmountOutNCT
            });

        amountOutNCT = ISwapRouter(SWAP_ROUTER).exactInput(params);

        require(amountOutNCT >= minAmountOutNCT, "TokenSwapComposer: Insufficient NCT output");

        // Optional: Reset approval if desired, though exactInput should consume the specified amountIn or revert.
        // TransferHelper.safeApprove(STARGATE_USDT, SWAP_ROUTER, 0);

        return amountOutNCT;
    }

    function testSwap(
        uint256 amountToSwapUSDT,
        bytes calldata composedTestData // Encoded (address senderOnSourceChain, address finalRecipient, uint256 minAmountOutNCT)
    ) external {
        (address senderOnSourceChain, address finalRecipient, uint256 minAmountOutNCT) = abi.decode(composedTestData, (address, address, uint256));

        TransferHelper.safeTransferFrom(STARGATE_USDT, msg.sender, address(this), amountToSwapUSDT);

        try this.executeSwap(amountToSwapUSDT, minAmountOutNCT, finalRecipient) returns (uint256 amountOutNCT) {
            emit SwapCompleted(finalRecipient, amountToSwapUSDT, amountOutNCT);
        } catch (bytes memory reason) {
            TransferHelper.safeTransfer(STARGATE_USDT, finalRecipient, amountToSwapUSDT);
            emit SwapFailed(finalRecipient, amountToSwapUSDT, reason);
        }
    }

    receive() external payable {}
} 

