// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Minter} from "./Minter.sol";

contract Oracle {
    mapping(uint => uint) _claimNonce;
    mapping(uint => mapping(uint => uint)) _lastLikeTime;
    mapping(address => bool) _signerAuthorized;
    uint private _minimumSigners = 1;
    address private _minter;

    event VerifiedMint(
        uint indexed likerFID,
        uint indexed likedFID,
        address indexed recipient,
        uint quantity,
        uint firstLikeTime,
        uint lastLikeTime
    );

    event VerifiedClaim(
        uint indexed FID,
        address indexed recipient,
        uint indexed nonce,
        uint quantity
    );

    modifier onlyGovernance {
        require(msg.sender == Minter(_minter).getGovernance());
        _;
    }

    constructor(address minter) {
        minter = _minter;
    }

    function _verify(bytes32 digest, bytes[] memory signatures) private view {
        require(signatures.length >= _minimumSigners, "Below Minimum Signers");
        bytes32[] memory comparableSignatures = new bytes32[](signatures.length);

        for (uint i = 0; i < signatures.length; i++) {
            require(_signerAuthorized[ECDSA.recover(digest, signatures[i])], "Signer Not Authorized");

            comparableSignatures[i] = keccak256(signatures[i]);
            for (uint j = 0; j < i; j++) {
                require(comparableSignatures[j] != comparableSignatures[i], "Duplicate Signatures");
            }
        }
    }

    function verifyAndMint(
        uint[] memory likerFIDs,
        uint[] memory likedFIDs,
        address[] memory recipients,
        uint[] memory quantities,
        uint[] memory firstLikeTimes,
        uint[] memory lastLikeTimes,
        bytes[] memory signatures
    ) external {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(keccak256(
            abi.encode(likerFIDs, likedFIDs, recipients, quantities, firstLikeTimes, lastLikeTimes)
        ));
        _verify(digest, signatures);

        Minter minter = Minter(_minter);
        for (uint i = 0; i < likerFIDs.length; i++) {
            uint likerFID = likerFIDs[i];
            uint likedFID = likedFIDs[i];
            address recipient = recipients[i];
            uint quantity = quantities[i];
            uint firstLikeTime = firstLikeTimes[i];
            uint lastLikeTime = lastLikeTimes[i];

            require(firstLikeTime <= lastLikeTime, "Invalid Time Range");
            require(firstLikeTime > _lastLikeTime[likerFID][likedFID], "Likes Already Minted");

            _lastLikeTime[likerFID][likedFID] = lastLikeTime;
            minter.mint(likerFID, recipient, quantity);

            emit VerifiedMint(likerFID, likedFID, recipient, quantity, firstLikeTime, lastLikeTime);
        }
    }

    function verifyAndClaim(
        uint[] memory FIDs,
        address[] memory recipients,
        uint[] memory nonces,
        bytes[] memory signatures
    ) external {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(keccak256(
            abi.encode(FIDs, recipients, nonces)
        ));
        _verify(digest, signatures);

        Minter minter = Minter(_minter);
        for (uint i = 0; i < FIDs.length; i++) {
            uint FID = FIDs[i];
            address recipient = recipients[i];
            uint nonce = nonces[i];

            require(_claimNonce[FID] + 1 == nonce, "Invalid Nonce");

            _claimNonce[FID] = nonce;
            uint quantity = minter.claim(FID, recipient);

            emit VerifiedClaim(FID, recipient, nonce, quantity);
        }
    }

    function setMinimumSigners(uint minimumSigners) external onlyGovernance {
        require(minimumSigners > 0, "Minimum 1 Signer Required");

        _minimumSigners = minimumSigners;
    }

    function setSignerAuthorized(address signer, bool authorized) external onlyGovernance {
        require(signer != address(0), "Invalid Address");

        _signerAuthorized[signer] = authorized;
    }

    function getSignerAuthorized(address addr) external view returns (bool) {
        return _signerAuthorized[addr];
    }

    function getMinimumSigners() external view returns (uint) {
        return _minimumSigners;
    }

    function getClaimNonce(uint FID) external view returns (uint) {
        return _claimNonce[FID];
    }

    function getLastLikeTime(uint likerFID, uint likedFID) external view returns (uint) {
        return _lastLikeTime[likerFID][likedFID];
    }

    function getLastLikeTimeBatch(uint[] memory likerFIDs, uint[] memory likedFIDs) external view returns (uint[] memory) {
        uint[] memory lastLikes = new uint[](likerFIDs.length);
        for (uint i = 0; i < likerFIDs.length; i++) {
            lastLikes[i] = _lastLikeTime[likerFIDs[i]][likedFIDs[i]];
        }
        return lastLikes;
    }
}
