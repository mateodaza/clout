// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockStablecoin} from "../src/MockStablecoin.sol";
import {CloutEscrow} from "../src/CloutEscrow.sol";
import {CloutPool} from "../src/CloutPool.sol";

contract Deploy is Script {
    function run() external {
        // Step 1 — Read all env vars (before broadcast; reads are free)
        uint256 privateKey   = vm.envUint("PRIVATE_KEY");
        address ownerAddress = vm.envAddress("OWNER_ADDRESS");
        address treasury     = vm.envAddress("TREASURY_ADDRESS");
        uint256 feeBps       = vm.envUint("FEE_BPS");

        // Step 2 — Enforce owner == deployer
        address deployer = vm.addr(privateKey);
        require(deployer == ownerAddress, "OWNER_ADDRESS must match deployer derived from PRIVATE_KEY");

        // Step 3 — Begin broadcast with explicit private key
        vm.startBroadcast(privateKey);

        // Step 4 — Deploy in order
        MockStablecoin token = new MockStablecoin();
        CloutEscrow escrow   = new CloutEscrow();
        CloutPool pool       = new CloutPool();

        // Step 5 — Configure
        escrow.addWhitelistedToken(address(token));
        pool.addWhitelistedToken(address(token));

        escrow.setProtocolFee(feeBps);
        pool.setProtocolFee(feeBps);

        escrow.setTreasury(treasury);
        pool.setTreasury(treasury);

        // Step 6 — End broadcast
        vm.stopBroadcast();

        // Step 7 — Log all addresses (after stopBroadcast; no gas cost)
        console.log("=== Clout Deployment ===");
        console.log("Owner (deployer):", ownerAddress);
        console.log("Treasury:", treasury);
        console.log("Fee (bps):", feeBps);
        console.log("MockStablecoin:", address(token));
        console.log("CloutEscrow:   ", address(escrow));
        console.log("CloutPool:     ", address(pool));
    }
}
