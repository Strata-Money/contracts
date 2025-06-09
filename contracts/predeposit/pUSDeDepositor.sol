// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {IDepositor} from "../interfaces/IDepositor.sol";
import {PreDepositPhase} from "../interfaces/IPhase.sol";
import {IMetaVault} from "../interfaces/IMetaVault.sol";
import {PreDepositPhaser} from "./PreDepositPhaser.sol";

contract pUSDeDepositor is IDepositor, OwnableUpgradeable {

    IERC20 public USDe;
    IERC4626 public sUSDe;
    IERC4626 public pUSDe;

    event SwapInfoChanged(address indexed token);

    error InvalidAsset(address asset);


    struct TAutoSwap {
        address router;
        // Supported DEX. 0 for default (Uniswap v3)
        uint24 engine;
        // Fee Tier, 0 for default (100=(0.01%))
        uint24 fee;
    }

    mapping (address sourceToken => TAutoSwap tokenSwapInfo) autoSwaps;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_
        , IERC20 USDe_
        , IERC4626 sUSDe_
        , IERC4626 pUSDe_
    ) public virtual initializer {
        __Ownable_init_unchained(owner_);

        USDe = USDe_;
        sUSDe = sUSDe_;
        pUSDe = pUSDe_;
    }

    /**
     * @notice Adds or clears the swap information for a given token
     * @dev This function allows the owner to set or update the swap parameters for a specific token
     * @param token The ERC20 token address for which to update swap info
     * @param swapInfo The new swap information to set, including router, engine, and fee
     */
    function updateSwapInfo (IERC20 token, TAutoSwap calldata swapInfo) external onlyOwner() {
        autoSwaps[address(token)] = swapInfo;
        emit SwapInfoChanged(address(token));
    }


    /**
     * @notice Deposits assets into the vault
     * @dev Accepts three types of assets:
     *      1. sUSDe: Deposited as-is
     *      2. USDe: First staked to receive sUSDe, then deposited
     *      3. Preconfigured stables: Swapped to USDe, then handled as in point 2
     * @param asset The address of the asset to deposit
     * @param amount The amount of the asset to deposit
     * @return uint256 The amount of pUSDe tokens minted
     */
    function deposit(IERC20 asset, uint256 amount, address receiver) external returns (uint256) {
        address user = _msgSender();
        if (asset == sUSDe) {
            return _deposit_sUSDe(user, amount, receiver);
        }
        if (asset == USDe) {
            return _deposit_USDe(user, amount, receiver);
        }
        if (autoSwaps[address(asset)].router != address(0)) {
            return _deposit_viaSwap(user, asset, amount, receiver);
        }
        IMetaVault vault = IMetaVault(address(pUSDe));
        SafeERC20.safeTransferFrom(asset, user, address(this), amount);
        SafeERC20.forceApprove(asset, address(vault), amount);
        return vault.deposit(address(asset), amount, receiver);
    }

    function _deposit_sUSDe (address from, uint256 amount, address receiver) internal returns (uint256) {
        require(amount > 0, "Deposit is zero");

        IERC4626 sUSDe_ = sUSDe;
        IERC4626 pUSDe_ = pUSDe;
        PreDepositPhase phase = PreDepositPhaser(address(pUSDe_)).currentPhase();
        require(phase == PreDepositPhase.YieldPhase, "INVALID_PHASE");

        if (from != address(this)) {
            SafeERC20.safeTransferFrom(sUSDe_, from, address(this), amount);
        }
        SafeERC20.forceApprove(sUSDe_, address(pUSDe_), amount);
        return IMetaVault(address(pUSDe_)).deposit(address(sUSDe_), amount, receiver);
    }

    function _deposit_USDe (address from, uint256 amount, address receiver) internal returns (uint256) {
        require(amount > 0, "Deposit is zero");

        IERC20 USDe_ = USDe;
        IERC4626 pUSDe_ = pUSDe;

        if (from != address(this)) {
            // Get USDe Tokens
            SafeERC20.safeTransferFrom(USDe_, from, address(this), amount);
        }

        SafeERC20.forceApprove(USDe_, address(pUSDe_), amount);
        return pUSDe_.deposit(amount, receiver);
    }

    function _deposit_viaSwap (address from, IERC20 token, uint256 amount, address receiver) internal returns (uint256) {
        if (from != address(this)) {
            SafeERC20.safeTransferFrom(token, from, address(this), amount);
        }

        TAutoSwap memory swapInfo = autoSwaps[address(token)];

        // Approve Uniswap router to spend Token
        SafeERC20.forceApprove(token, swapInfo.router, amount);

        // Calculate minimum amount out with 0.1% slippage
        uint256 amountOutMin = (amount * 999) / 1000;

        IERC20 USDe_ = USDe;
        uint256 USDeBalance = USDe_.balanceOf(address(this));
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(token),
            tokenOut: address(USDe_),
            fee: swapInfo.fee,
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountIn: amount,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        ISwapRouter(swapInfo.router).exactInputSingle(params);
        uint256 amountOut = USDe_.balanceOf(address(this)) - USDeBalance;

        return _deposit_USDe(address(this), amountOut, receiver);
    }

}
