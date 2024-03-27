// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Minter} from "./Minter.sol";

contract Oracle {
    address private immutable _minter;
    address private _federation;

    uint private _minimumSigners = 1;
    mapping(address => bool) _signerAuthorized;

    modifier onlyFederation {
        require(msg.sender == _federation, "Not Federation");
        _;
    }

    constructor(address minter) {
        _minter = minter;
        _federation = msg.sender;
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
        address[] memory likers,
        address[] memory likeds,
        uint[] memory quantities,
        uint[] memory firstLikeTimes,
        uint[] memory lastLikeTimes,
        bytes[] memory signatures
    ) external {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(keccak256(
            abi.encode(likerFIDs, likedFIDs, likers, likeds, quantities, firstLikeTimes, lastLikeTimes)
        ));
        _verify(digest, signatures);
        Minter(_minter).mint(likerFIDs, likedFIDs, likers, likeds, quantities, firstLikeTimes, lastLikeTimes);
    }

    function verifyAndClaim(
        uint[] memory likerFIDs,
        address[] memory likers,
        uint[] memory nonces,
        bytes[] memory signatures
    ) external {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(keccak256(
            abi.encode(likerFIDs, likers, nonces)
        ));
        _verify(digest, signatures);
        Minter(_minter).claim(likerFIDs, likers, nonces);
    }

    function setFederation(address federation) external onlyFederation {
        _federation = federation;
    }

    function setMinimumSigners(uint minimumSigners) external onlyFederation {
        require(minimumSigners > 0, "Minimum 1 Signer Required");

        _minimumSigners = minimumSigners;
    }

    function setSignerAuthorized(address signer, bool authorized) external onlyFederation {
        require(signer != address(0), "Invalid Signer Address");

        _signerAuthorized[signer] = authorized;
    }

    function getFederation() external view returns (address) {
        return _federation;
    }

    function getSignerAuthorized(address addr) external view returns (bool) {
        return _signerAuthorized[addr];
    }

    function getMinimumSigners() external view returns (uint) {
        return _minimumSigners;
    }

    function getMinter() external view returns (address) {
        return _minter;
    }
}
