// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title SmokeImports
/// @notice Test-only helper contract that validates OpenZeppelin imports resolve
///         correctly during compilation. This contract is never deployed to
///         production — it exists solely to exercise the OZ import paths.
/// @dev Inherits ReentrancyGuard and Ownable (OZ v5 requires initialOwner arg),
///      and declares an IERC20 state variable so all imports are actively used.
contract SmokeImports is ReentrancyGuard, Ownable {
    /// @notice A token reference — exists to ensure IERC20 import is used.
    IERC20 public token;

    /// @notice Deploys SmokeImports, setting the deployer as the initial owner.
    /// @dev OZ v5 Ownable requires an explicit initialOwner constructor argument.
    constructor() Ownable(msg.sender) {}

    /// @notice No-op protected function — verifies ReentrancyGuard modifier compiles.
    function noOp() external nonReentrant onlyOwner {
        // Intentionally empty — validates modifier compilation only.
    }
}
