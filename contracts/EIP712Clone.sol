// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC5267} from "@openzeppelin/contracts/interfaces/IERC5267.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP-712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding scheme specified in the EIP requires a domain separator and a hash of the typed structured data, whose
 * encoding is very generic and therefore its implementation in Solidity is not feasible, thus this contract
 * does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in order to
 * produce the hash of their typed data using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP-712 domain separator ({_domainSeparatorV4Clone}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * @custom:oz-upgrades-unsafe-allow state-variable-immutable
 */
abstract contract EIP712Clone is IERC5267 {

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    string private _name;
    uint private _FID;
    string private constant _version = "1";
    bytes32 private constant _hashedVersion = keccak256(bytes("1"));

    function _initEIP712(uint FID) internal {
        _FID = FID;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4Clone() internal view returns (bytes32) {
        return keccak256(abi.encode(
            TYPE_HASH,
            keccak256(bytes(_getEIP712Name())),
            _hashedVersion,
            block.chainid,
            address(this)
        ));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(_domainSeparatorV4Clone(), structHash);
    }

    /**
     * @dev See {IERC-5267}.
     */
    function eip712Domain() public view virtual returns (
        bytes1 fields,
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract,
        bytes32 salt,
        uint256[] memory extensions
    ) {
        return (
            hex"0f", // 01111
            _getEIP712Name(),
            _version,
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    function _getEIP712Name() internal view returns (string memory) {
        return string(abi.encodePacked("FIDE ", Strings.toString(_FID)));
    }

    function _getFID() internal view returns (uint) {
        return _FID;
    }
}
