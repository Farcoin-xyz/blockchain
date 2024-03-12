// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {Fide} from "./Fide.sol";

contract Minter {
    mapping(uint => address) _fides;
    address private _fideTemplate;
    address private _governance;
    address private _oracle;
    address private _DAO;

    modifier onlyGovernance {
        require(msg.sender == _governance, "Not Governance");
        _;
    }

    modifier onlyOracle {
        require(msg.sender == _oracle, "Not Oracle");
        _;
    }

    modifier onlyDAO {
        require(msg.sender == _DAO, "Not DAO");
        _;
    }

    event Mint(
        uint indexed FID,
        address indexed fide,
        address indexed recipient,
        uint quantity,
        uint timestamp
    );

    event Claim(
        uint indexed FID,
        address indexed fide,
        address indexed recipient,
        uint quantity,
        uint timestamp
    );

    constructor(address DAO) {
        _fideTemplate = address(new Fide());
        _governance = msg.sender;
        _DAO = DAO;
    }

    function _mint(uint FID, address recipient, uint quantity, address fideTemplate, address DAO) private {
        address fide = _fides[FID];
        if (fide == address(0)) {
            fide = Clones.cloneDeterministic(fideTemplate, bytes32(FID));
            Fide(fide).initAndMint(FID, recipient, quantity, DAO);
            _fides[FID] = fide;
        } else {
            Fide(fide).mint(recipient, quantity, DAO);
        }
        emit Mint(FID, fide, recipient, quantity, block.timestamp);
    }

    function mint(uint FID, address recipient, uint quantity) external onlyOracle {
        _mint(FID, recipient, quantity, _fideTemplate, _DAO);
    }

    function mint(uint[] memory FIDs, address[] memory recipients, uint[] memory quantities) external onlyOracle {
        address fideTemplate = _fideTemplate;
        address DAO = _DAO;
        for (uint i = 0; i < FIDs.length; i++) {
            _mint(FIDs[i], recipients[i], quantities[i], fideTemplate, DAO);
        }
    }

    function _claim(uint FID, address recipient) private returns (uint) {
        address fide = _fides[FID];
        require(fide != address(0), "Fide Not Found");

        uint quantity = Fide(fide).claim(recipient);

        emit Claim(FID, fide, recipient, quantity, block.timestamp);

        return quantity;
    }

    function claim(uint FID, address recipient) external onlyOracle returns (uint) {
        return _claim(FID, recipient);
    }

    function claim(uint[] memory FIDs, address[] memory recipients) external onlyOracle returns (uint[] memory) {
        uint[] memory quantities = new uint[](FIDs.length);
        for (uint i = 0; i < FIDs.length; i++) {
            quantities[i] = _claim(FIDs[i], recipients[i]);
        }
        return quantities;
    }

    function setGovernance(address governance) external onlyGovernance {
        _governance = governance;
    }

    function setOracle(address oracle) external onlyGovernance {
        _oracle = oracle;
    }

    function setDAO(address DAO) external onlyDAO {
        _DAO = DAO;
    }

    function getGovernance() external view returns (address) {
        return _governance;
    }

    function getOracle() external view returns (address) {
        return _oracle;
    }

    function getDAO() external view returns (address) {
        return _DAO;
    }

    function getFide(uint FID) external view returns (address) {
        return _fides[FID];
    }

    function getFides(uint[] memory FIDs) external view returns (address[] memory) {
        address[] memory fides = new address[](FIDs.length);
        for (uint i = 0; i < FIDs.length; i++) {
            fides[i] = _fides[FIDs[i]];
        }
        return fides;
    }
}
