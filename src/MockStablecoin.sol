// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockStablecoin
/// @notice A testnet ERC-20 token with permissionless minting for development and testing.
contract MockStablecoin is ERC20 {
    /// @notice Initializes the MockStablecoin with name "Mock USDC", symbol "mUSDC", and 6 decimals.
    constructor() ERC20("Mock USDC", "mUSDC") {}

    /// @notice Returns the number of decimal places for this token.
    /// @return The number of decimals (6).
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Allows anyone to mint tokens (permissionless, testnet only).
    /// @param to The address to receive the minted tokens.
    /// @param amount The amount of tokens to mint (in units of 1e-6).
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
