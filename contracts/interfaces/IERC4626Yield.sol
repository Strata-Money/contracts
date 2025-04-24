import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IERC4626Yield {
    function previewYield(address caller, uint256 shares) external view returns (uint256);

    function previewRedeem(address caller, uint256 shares) external view returns (uint256);
}

interface IERC4626YieldVault is IERC4626, IERC4626Yield {

}
