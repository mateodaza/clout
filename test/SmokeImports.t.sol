// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {SmokeImports} from "./helpers/SmokeImports.sol";

/// @title SmokeImportsTest
/// @notice Validates that the Foundry toolchain and OpenZeppelin dependency are
///         wired up correctly. If this test suite compiles and passes, the
///         NC-001 acceptance criteria are satisfied.
contract SmokeImportsTest is Test {
    SmokeImports internal smoke;

    function setUp() public {
        smoke = new SmokeImports();
    }

    /// @notice Verifies the contract deploys successfully and owner is set.
    function test_deploysSuccessfully() public view {
        assertEq(smoke.owner(), address(this), "Owner should be the test contract (deployer)");
    }

    /// @notice Verifies token() returns the zero address (unset default).
    function test_tokenDefaultsToZeroAddress() public view {
        assertEq(address(smoke.token()), address(0), "Token should default to zero address");
    }

    /// @notice Verifies noOp() can be called by the owner without reverting.
    function test_noOpSucceeds() public {
        smoke.noOp(); // Should not revert
    }

    /// @notice Verifies noOp() reverts when called by a non-owner.
    function test_noOpRevertsForNonOwner() public {
        vm.prank(address(0xdead));
        vm.expectRevert();
        smoke.noOp();
    }
}
