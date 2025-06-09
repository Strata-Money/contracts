// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {PreDepositPhase, IPreDepositPhaser} from "../interfaces/IPhase.sol";

/// @notice Tracks the current phase of the PreDeposit Vault: Points or Yield
/// @dev Abstract contract to be inherited by PreDeposit Vault implementations
abstract contract PreDepositPhaser is IPreDepositPhaser {

    PreDepositPhase internal _currentPhase;

    uint256[49] private __gap;

    event PhaseStarted(PreDepositPhase phase);

    function currentPhase() public view virtual returns (PreDepositPhase) {
        return _currentPhase;
    }

    function _setYieldPhaseInner () internal {
        require(_currentPhase != PreDepositPhase.YieldPhase, "ACTIVE_PHASE");

        _currentPhase = PreDepositPhase.YieldPhase;
        emit PhaseStarted(_currentPhase);
    }
}
