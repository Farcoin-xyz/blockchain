// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract Vault is TimelockController {
    constructor() TimelockController(0, new address[](0), new address[](1), _msgSender()) {}
}
