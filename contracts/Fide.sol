// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Fide is ERC20 {
    address private _minter;
    uint private _FID = 0;

    uint private constant COIN = (10 ** 18);
    uint private constant CUTS = (10 ** 15) * 125;

    modifier onlyMinter {
        require(msg.sender == _minter, "Not Minter");
        _;
    }

    constructor() ERC20("", "") {
        _minter = msg.sender;
    }

    function initAndMint(uint FID, address recipient, uint coins, address farcoinDAO) external {
        require(_minter == address(0), "Cannot Reinitialize Fide");
        require(FID > 0, "Invalid FID");

        _minter = msg.sender;
        _FID = FID;

        _mint(recipient, coins * COIN);
        _mint(msg.sender, coins * CUTS); // 10% to FID
        _mint(farcoinDAO, coins * CUTS); // 10% to DAO
    }

    function mint(address recipient, uint coins, address farcoinDAO) external onlyMinter {
        _mint(recipient, coins * COIN);
        _mint(msg.sender, coins * CUTS); // 10% to FID
        _mint(farcoinDAO, coins * CUTS); // 10% to DAO
    }

    function claim(address recipient) external onlyMinter returns (uint) {
        uint quantity = balanceOf(msg.sender);
        _transfer(msg.sender, recipient, quantity);
        return quantity;
    }

    function name() public view override returns (string memory) {
        return string(abi.encodePacked("Fide #", Strings.toString(_FID)));
    }

    function symbol() public view override returns (string memory) {
        return string(abi.encodePacked("FIDE", Strings.toString(_FID)));
    }
}
