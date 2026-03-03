// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockStablecoin} from "../src/MockStablecoin.sol";

contract MockStablecoinTest is Test {
    MockStablecoin token;
    address alice = address(0xAAA);
    address bob = address(0xBBB);

    function setUp() public {
        token = new MockStablecoin();
    }

    function test_nameIsCorrect() public view {
        assertEq(token.name(), "Mock USDC");
    }

    function test_symbolIsCorrect() public view {
        assertEq(token.symbol(), "mUSDC");
    }

    function test_decimalsReturns6() public view {
        assertEq(token.decimals(), 6);
    }

    function test_mintAllowsAnyone() public {
        uint256 amount = 1000 * 10 ** 6;
        token.mint(alice, amount);
        assertEq(token.balanceOf(alice), amount);
    }

    function test_transferWorks() public {
        uint256 amount = 500 * 10 ** 6;
        token.mint(alice, amount);
        
        vm.prank(alice);
        assertTrue(token.transfer(bob, amount));

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), amount);
    }

    function test_approveAndTransferFromWork() public {
        uint256 amount = 300 * 10 ** 6;
        token.mint(alice, amount);
        
        vm.prank(alice);
        token.approve(bob, amount);
        
        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, amount));

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), amount);
    }

    function test_mintCheckBalanceAndTransfer() public {
        uint256 initialMint = 1000 * 10 ** 6;
        uint256 transferAmount = 250 * 10 ** 6;
        
        token.mint(alice, initialMint);
        assertEq(token.balanceOf(alice), initialMint);
        
        vm.prank(alice);
        assertTrue(token.transfer(bob, transferAmount));

        assertEq(token.balanceOf(alice), initialMint - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
    }

    function test_totalSupplyTracksMintsCorrectly() public {
        uint256 mint1 = 100 * 10 ** 6;
        uint256 mint2 = 200 * 10 ** 6;
        
        token.mint(alice, mint1);
        assertEq(token.totalSupply(), mint1);
        
        token.mint(bob, mint2);
        assertEq(token.totalSupply(), mint1 + mint2);
    }
}
