// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library InterestRate {
    uint256 constant BASE = 1e27;

    // per second
    uint256 constant INTEREST_RATE_0_5 = 158153903837946258; // 0.5%
    uint256 constant INTEREST_RATE_5 = 1477274043261233001; // 5%
    uint256 constant INTEREST_RATE_10 = 3022265980097387650; // 10%
    uint256 constant INTEREST_RATE_15 = 4431822129783699001; // 15%
    uint256 constant INTEREST_RATE_20 = 5781378656804591713; // 20%
    uint256 constant INTEREST_RATE_100 = 21979553151239153030; // 100%
    uint256 constant INTEREST_RATE_1000 = 76036763190083298290; // 1000%
    uint256 constant INTEREST_RATE_100000 = 219075200915893380020; // 100000%
    uint256 constant INTEREST_RATE_1000000000 = 511101594049663229250; // 1000000000%

    function calculateInterest(
        uint principal,
        uint interestRatePerSecond,
        uint duration
    ) internal pure returns (uint) {
        return
            calculatePrincipalPlusInterest(
                principal,
                interestRatePerSecond,
                duration
            ) - principal;
    }

    function calculatePrincipalPlusInterest(
        uint principal,
        uint interestRatePerSecond,
        uint duration
    ) internal pure returns (uint) {
        return
            (principal * rpow(interestRatePerSecond + BASE, duration, BASE)) /
            BASE;
    }

    function getInterestRateForDuration(
        uint256 interestRatePerSecond,
        uint256 duration
    ) internal pure returns (uint256) {
        return rpow(interestRatePerSecond + BASE, duration, BASE) - BASE;
    }

    /**
     * @dev calculate the power of x. return = (x/base)**n * base
     */
    function rpow(uint x, uint n, uint base) internal pure returns (uint z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    z := base
                }
                default {
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    z := base
                }
                default {
                    z := x
                }
                let half := div(base, 2) // for rounding.
                for {
                    n := div(n, 2)
                } n {
                    n := div(n, 2)
                } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) {
                        revert(0, 0)
                    }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }
                    x := div(xxRound, base)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                            revert(0, 0)
                        }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }
                        z := div(zxRound, base)
                    }
                }
            }
        }
    }
}
