// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {FIDE} from "./FIDE.sol";

contract Minter {
    address private immutable _fideTemplate;
    address private immutable _vault;

    address private _oracle;

    mapping(uint => uint) _claimNonces;
    mapping(uint => address) private _fides;
    mapping(uint => mapping(uint => uint)) _lastLikeTimes;

    modifier onlyOracle {
        require(msg.sender == _oracle, "Not Oracle");
        _;
    }

    modifier onlyVault {
        require(msg.sender == _vault, "Not Vault");
        _;
    }

    event Mint(
        uint indexed likerFID,
        uint indexed likedFID,
        address liker,
        address liked,
        uint quantity,
        uint firstLikeTime,
        uint lastLikeTime,
        uint timestamp
    );

    event Claim(
        uint indexed likerFID,
        address liker,
        uint nonce,
        uint quantity,
        uint timestamp
    );

    constructor(address vault) {
        _fideTemplate = address(new FIDE());
        _vault = vault;
    }

    function _mint(
        uint likerFID,
        uint likedFID,
        address liker,
        address liked,
        uint quantity,
        uint firstLikeTime,
        uint lastLikeTime
    ) private {
        require(firstLikeTime <= lastLikeTime, "Invalid Time Range");
        require(firstLikeTime > _lastLikeTimes[likerFID][likedFID], "Range Already Minted");

        _lastLikeTimes[likerFID][likedFID] = lastLikeTime;

        address fide = _fides[likerFID];
        if (fide == address(0)) {
            fide = Clones.cloneDeterministic(_fideTemplate, bytes32(likerFID));
            _fides[likerFID] = fide;
            FIDE(fide).initAndMint(likerFID, liker, liked, quantity, _vault);
        } else {
            FIDE(fide).mint(liker, liked, quantity, _vault);
        }
        emit Mint(likerFID, likedFID, liker, liked, quantity, firstLikeTime, lastLikeTime, block.timestamp);
    }

    function mint(
        uint likerFID,
        uint likedFID,
        address liker,
        address liked,
        uint quantity,
        uint firstLikeTime,
        uint lastLikeTime
    ) external onlyOracle {
        _mint(likerFID, likedFID, liker, liked, quantity, firstLikeTime, lastLikeTime);
    }

    function mint(
        uint[] memory likerFIDs,
        uint[] memory likedFIDs,
        address[] memory likers,
        address[] memory likeds,
        uint[] memory quantities,
        uint[] memory firstLikeTimes,
        uint[] memory lastLikeTimes
    ) external onlyOracle {
        for (uint i = 0; i < likerFIDs.length; i++) {
            _mint(likerFIDs[i], likedFIDs[i], likers[i], likeds[i], quantities[i], firstLikeTimes[i], lastLikeTimes[i]);
        }
    }

    function _claim(uint FID, address liker, uint nonce) private {
        address fide = _fides[FID];
        require(fide != address(0), "FIDE Not Found");
        require(_claimNonces[FID] + 1 == nonce, "Invalid Nonce");
        _claimNonces[FID] = nonce;

        uint quantity = FIDE(fide).claim(liker);

        emit Claim(FID, liker, nonce, quantity, block.timestamp);
    }

    function claim(uint FID, address liked, uint nonce) external onlyOracle {
        _claim(FID, liked, nonce);
    }

    function claim(uint[] memory FIDs, address[] memory likeds, uint[] memory nonces) external onlyOracle {
        for (uint i = 0; i < FIDs.length; i++) {
            _claim(FIDs[i], likeds[i], nonces[i]);
        }
    }

    function setOracle(address oracle) external onlyVault {
        _oracle = oracle;
    }

    function getFideTemplate() external view returns (address) {
        return _fideTemplate;
    }

    function getOracle() external view returns (address) {
        return _oracle;
    }

    function getVault() external view returns (address) {
        return _vault;
    }

    function getClaimNonce(uint FID) external view returns (uint) {
        return _claimNonces[FID];
    }

    function getFide(uint FID) external view returns (address) {
        return _fides[FID];
    }

    function getLastLikeTime(uint likerFID, uint likedFID) external view returns (uint) {
        return _lastLikeTimes[likerFID][likedFID];
    }

    function getClaimNonces(uint[] memory FIDs) external view returns (uint[] memory) {
        uint[] memory claimNonces = new uint[](FIDs.length);
        for (uint i = 0; i < FIDs.length; i++) {
            claimNonces[i] = _claimNonces[FIDs[i]];
        }
        return claimNonces;
    }

    function getFides(uint[] memory FIDs) external view returns (address[] memory) {
        address[] memory fides = new address[](FIDs.length);
        for (uint i = 0; i < FIDs.length; i++) {
            fides[i] = _fides[FIDs[i]];
        }
        return fides;
    }

    function getLastLikeTimes(uint[] memory likerFIDs, uint[] memory likedFIDs) external view returns (uint[] memory) {
        uint[] memory lastLikeTimes = new uint[](likerFIDs.length);
        for (uint i = 0; i < likerFIDs.length; i++) {
            lastLikeTimes[i] = _lastLikeTimes[likerFIDs[i]][likedFIDs[i]];
        }
        return lastLikeTimes;
    }
}
