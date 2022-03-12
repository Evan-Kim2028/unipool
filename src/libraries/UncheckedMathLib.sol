// SPDX-License-Identifier: GPLv3
pragma solidity >=0.8.0;

library UncheckedMathLib {
    function uAdd(uint256 x, uint256 y) internal pure returns (uint256 z) {assembly {z := add(x, y)}}
    function uSub(uint256 x, uint256 y) internal pure returns (uint256 z) {assembly {z := sub(x, y)}}
    function uMul(uint256 x, uint256 y) internal pure returns (uint256 z) {assembly {z := mul(x, y)}}
    function uDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {assembly {z := div(x, y)}}
    function uFrac(uint256 x, uint256 y, uint256 denom) internal pure returns (uint256 z) {assembly {z := div(mul(x, y), denom)}}
}