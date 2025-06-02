// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {PreDepositPhase} from "../interfaces/IPhase.sol";

/// @notice Tracks the current phase of the PreDeposit Vault: Points or Yield
/// @dev Abstract contract to be inherited by PreDeposit Vault implementations
abstract contract PreDepositPhaser {

    PreDepositPhase public currentPhase;

    uint256[49] private __gap;

    event PhaseStarted(PreDepositPhase phase);


    function setYieldPhaseInner () internal {
        require(currentPhase != PreDepositPhase.YieldPhase, "ACTIVE_PHASE");

        currentPhase = PreDepositPhase.YieldPhase;
        emit PhaseStarted(currentPhase);
    }
}
