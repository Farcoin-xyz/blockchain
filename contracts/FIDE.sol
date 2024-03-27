// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {EIP712Clone} from "./EIP712Clone.sol";

contract FIDE is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, ERC165, EIP712Clone {
    address private _minter;

    uint private constant COIN = (10 ** 18);        // 1.00 Coin
    uint private constant FEES = (10 ** 16) * 25;   // 0.25 Coin

    modifier onlyMinter {
        require(msg.sender == _minter, "Not Minter");
        _;
    }

    constructor() ERC20("FIDE Template", "FIDE-T") ERC20Permit("FIDE Template") {
        _minter = msg.sender;
    }

    function initAndMint(uint FID, address liker, address liked, uint coins, address vault) external {
        require(_minter == address(0), "Cannot Reinitialize FIDE");
        require(FID > 0, "Invalid FID");

        _minter = msg.sender;
        _initEIP712(FID);
        _mint(liker, liked, coins, vault);
    }

    function mint(address liker, address liked, uint coins, address vault) external onlyMinter {
        _mint(liker, liked, coins, vault);
    }

    function _mint(address liker, address liked, uint coins, address vault) private {
        if (liker == address(0)) {
            liker = address(this);                  // Hold until `claim`
        }
        require(liked != address(0), "Invalid Recipient");

        _mint(vault, coins * FEES / 2);             // 10% to Vault
        _mint(liker, coins * FEES / 2);             // 10% for FID
        _mint(liked, coins * COIN);

        if (delegates(liked) == address(0)) {
            _delegate(liked, liked);                // Auto-delegate votes
        }
    }

    function claim(address liker) external onlyMinter returns (uint) {
        uint quantity = balanceOf(address(this));
        _transfer(address(this), liker, quantity);
        if (delegates(liker) == address(0)) {
            _delegate(liker, liker);
        }
        return quantity;
    }

    function name() public view override returns (string memory) {
        return _getEIP712Name();
    }

    function symbol() public view override returns (string memory) {
        return string(abi.encodePacked("FIDE-", Strings.toString(_getFID())));
    }

    function getFID() public view returns (uint) {
        return _getFID();
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

    // EIP-712
    function DOMAIN_SEPARATOR() external override view virtual returns (bytes32) {
        return EIP712Clone._domainSeparatorV4Clone();
    }

    function _hashTypedDataV4(bytes32 structHash) internal override(EIP712, EIP712Clone) view virtual returns (bytes32) {
        return EIP712Clone._hashTypedDataV4(structHash);
    }

    function eip712Domain() public override(EIP712, EIP712Clone) view virtual returns (
        bytes1,             // fields
        string memory,      // name
        string memory,      // version
        uint256,            // chainId
        address,            // verifyingContract
        bytes32,            // salt
        uint256[] memory    // extensions
    ) {
        return EIP712Clone.eip712Domain();
    }
}
