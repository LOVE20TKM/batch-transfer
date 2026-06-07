// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {BatchTransfer} from "../src/BatchTransfer.sol";

contract DeployBatchTransfer is Script {
    function run() external {
        console2.log("=== Deployment Parameters ===");
        console2.log("BatchTransfer has no constructor parameters");

        vm.startBroadcast();

        BatchTransfer batchTransfer = new BatchTransfer();

        console2.log("BatchTransfer deployed at:", address(batchTransfer));

        vm.stopBroadcast();

        string memory network = vm.envOr("network", string("anvil"));
        string memory addressFile = string.concat("script/network/", network, "/address.batch-transfer.params");
        string memory content = string.concat("batchTransferAddress=", vm.toString(address(batchTransfer)), "\n");

        vm.writeFile(addressFile, content);
        console2.log("Address saved to:", addressFile);

        console2.log("\n=== Deployment Summary ===");
        console2.log("BatchTransfer Address:", address(batchTransfer));
        console2.log("Network:", network);
    }
}
