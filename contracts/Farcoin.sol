// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

contract Farcoin is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, ERC165 {
    uint private constant ONE_HUNDRED_BILLION = 100000000000;
    uint private constant TOKEN_UNIT = 10 ** 18;

    constructor() ERC20("Farcoin", "FRC") ERC20Permit("Farcoin") {
        _mint(_msgSender(), TOKEN_UNIT * ONE_HUNDRED_BILLION);
    }

    // ERC-165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == 0xa219a025    // IERC20Metadata
        || interfaceId == 0x36372b07        // IERC20
        || interfaceId == 0xe90fb3f6        // IVotes
        || interfaceId == 0x84b0196e        // IERC5267
        || interfaceId == 0xda287a1d        // IERC6372
        || interfaceId == 0x01ffc9a7;       // IERC165
    }

    // ERC-6372
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // The functions below are overrides required by Solidity.
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
