// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {BeforeAfter} from "./BeforeAfter.sol";

abstract contract Properties is BeforeAfter, Asserts {
    function property_usde_addition_increases_pUSDe_depositedBase() public {
        if (currentOperation == OpType.ADD) {
            lte(
                _before.pUSDe_depositedBase,
                _after.pUSDe_depositedBase,
                "USDe addition does not increase pUSDe_depositedBase"
            );
            lte(
                _before.pUSDe_totalSupply, _after.pUSDe_totalSupply, "USDe addition does not increase pUSDe_totalSupply"
            );
        }
    }

    function property_usde_removal_decreases_pUSDe_depositedBase() public {
        if (currentOperation == OpType.REMOVE) {
            gte(
                _before.pUSDe_depositedBase,
                _after.pUSDe_depositedBase,
                "USDe removal does not decrease pUSDe_depositedBase"
            );
            gte(_before.pUSDe_totalSupply, _after.pUSDe_totalSupply, "USDe removal does not decrease pUSDe_totalSupply");
        }
    }

    // NOTE: this property will break as the yUSDe state is not currently updated, so we comment it out for now.
    // function property_currentPhase_equivalence() public {
    //     // NOTE: could just remove this if statement to check all operations
    //     // since properties are checked after every call, or alternatively make it a doomsday invariant
    //     // but this has been left for now to allow for flexibility if needed in the future
    //     if(uint8(currentOperation) >= uint8(OpType.GENERIC)) {
    //         t(
    //             _before.pUSDe_currentPhase == _before.yUSDe_currentPhase &&
    //             _after.pUSDe_currentPhase == _after.yUSDe_currentPhase,
    //             "pUSDe currentPhase and yUSDe currentPhase should be equivalent across all operations"
    //         );
    //     }
    // }

    function property_share_solvency() public {
        lte(
            _after.pUSDe_totalSupplyGhost,
            _after.pUSDe_totalSupplyGhost,
            "pUSDe totalSupplyGhost should be less than or equal to totalSupply"
        );
        lte(
            _after.yUSDe_totalSupplyGhost,
            _after.yUSDe_totalSupplyGhost,
            "yUSDe totalSupplyGhost should be less than or equal to totalSupply"
        );
    }

    function property_additions_should_never_decrease_price_per_share() public {
        if (currentOperation == OpType.ADD) {
            lte(
                _before.pUSDe_pricePerShare,
                _after.pUSDe_pricePerShare,
                "pUSDe price per share should never decrease on addition"
            );
            lte(
                _before.yUSDe_pricePerShare,
                _after.yUSDe_pricePerShare,
                "yUSDe price per share should never decrease on addition"
            );
        }
    }

    function property_removals_should_never_increase_price_per_share() public {
        if (currentOperation == OpType.REMOVE) {
            gte(
                _before.pUSDe_pricePerShare,
                _after.pUSDe_pricePerShare,
                "pUSDe price per share should never increase on removal"
            );
            gte(
                _before.yUSDe_pricePerShare,
                _after.yUSDe_pricePerShare,
                "yUSDe price per share should never increase on removal"
            );
        }
    }

    // Any actor who only ever deposits into (and redeems from) pUSDe should never withdraw more USDe than they put in.
    // In other words, ∀ actor: pUSDe_totalWithdrawnUSDe[actor] <= pUSDe_totalDepositedUSDe[actor].
    function property_pUSDe_withdrawals_cannot_exceed_deposits() public {
        if (currentOperation == OpType.REMOVE) {
            address[] memory actors = _getActors();
            for (uint256 i; i < actors.length; i++) {
                address actor = actors[i];
                lte(
                    pUSDe_totalWithdrawnUSDe[actor],
                    pUSDe_totalDepositedUSDe[actor],
                    "Actor withdrew more USDe from pUSDe than they ever deposited."
                );
            }
        }
    }

    // Any actor who deposits into yUSDe should never withdraw less USDe than they originally put in to pUSDe.
    // In other words, ∀ actor: yUSDe_totalWithdrawnUSDe[actor] >= yUSDe_totalDepositedUSDe[actor].
    function property_yUSDe_no_loss() public {
        if (currentOperation == OpType.REMOVE) {
            address[] memory actors = _getActors();
            for (uint256 i; i < actors.length; i++) {
                address actor = actors[i];
                gte(
                    yUSDe_totalWithdrawnUSDe[actor],
                    yUSDe_totalDepositedUSDe[actor],
                    "Actor redeemed yUSDe for less USDe-equivalent than they deposited."
                );
            }
        }
    }
}
