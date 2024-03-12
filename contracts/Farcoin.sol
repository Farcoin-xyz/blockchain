// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20, ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Minter} from "./Minter.sol";

contract Farcoin is ERC20Votes {
    uint private _tokensIssued = 0;
    uint private _unclaimedFees = 0;
    address private _minter;

    uint private constant MAX_TOKEN_BUY = 1000000000; // Prevent Multiplicative Overflows
    uint private constant BASE_PRICE = 1 gwei;
    uint private constant TOKEN_UNIT = 10 ** 18;
    uint public constant FEE_PCT = 1;
    uint public constant TRADE_TYPE_BUY = 1;
    uint public constant TRADE_TYPE_SELL = 2;

    event Trade (
        address indexed owner,
        uint indexed tradeType,
        uint tokens,
        uint bond,
        uint fees,
        uint supply,
        uint timestamp
    );

    constructor(address minter) ERC20("Farcoin", "FRC") EIP712("Farcoin", "1") {
        _minter = minter;
    }

    function buy(uint tokens, uint minTokens) public payable {
        require(tokens >= minTokens && tokens > 0 && tokens <= MAX_TOKEN_BUY, "Invalid Order");

        uint maxBond = _getMaxBond(msg.value);
        uint oldSupply = _tokensIssued;
        uint totalBonded = _getTotalBonded(oldSupply);

        uint newTokens = tokens;
        uint bond = _getTotalBonded(oldSupply + newTokens) - totalBonded;
        if (bond > maxBond) { // Not enough sent to buy `tokens`, find the max we can get
            newTokens = minTokens;
            bond = _getTotalBonded(oldSupply + newTokens) - totalBonded;
            require(bond <= maxBond, "Unable To Buy Minimum Tokens");

            // Search for the max token amount
            uint testTokens = (tokens - minTokens) / 2;
            while (testTokens != 0) {
                bond = _getTotalBonded(oldSupply + newTokens + testTokens) - totalBonded;
                if (bond <= maxBond) {
                    newTokens += testTokens;
                    testTokens = (testTokens / 2) + 1;
                } else {
                    testTokens /= 2;
                }
            }
            bond = _getTotalBonded(oldSupply + newTokens) - totalBonded;
        }
        uint newSupply = oldSupply + newTokens;
        uint fees = _getFeesToBond(bond);

        _mint(msg.sender, newTokens * TOKEN_UNIT);
        _tokensIssued = newSupply;
        _unclaimedFees += fees;

        uint excess = msg.value - bond - fees;
        if (excess >= 1 gwei) { // Don't refund dust
            (bool sent,) = msg.sender.call{value: excess}("");
            require(sent, "Unable To Refund Excess");
        }

        emit Trade(
            msg.sender,
            TRADE_TYPE_BUY,
            newTokens,
            bond,
            fees,
            newSupply,
            block.timestamp
        );
    }

    function sell(uint tokens, uint minProceeds) public {
        uint oldSupply = _tokensIssued;
        require(tokens <= oldSupply, "Invalid Order");
        uint newSupply = oldSupply - tokens;

        uint bond = _getTotalBonded(oldSupply) - _getTotalBonded(newSupply);
        uint fees = bond * FEE_PCT / 100;
        uint send = bond - fees;

        require(send >= minProceeds, "Unable To Sell For Min Proceeds");

        _burn(msg.sender, tokens * TOKEN_UNIT);
        _tokensIssued = newSupply;
        _unclaimedFees += fees;

        (bool sent,) = msg.sender.call{value: send}("");
        require(sent, "Unable To Send Proceeds");

        emit Trade(
            msg.sender,
            TRADE_TYPE_SELL,
            tokens,
            bond,
            fees,
            newSupply,
            block.timestamp
        );
    }

    function _getFeesToBond(uint bondWei) private pure returns (uint) {
        return (bondWei * 100 / (100 - FEE_PCT)) - bondWei;
    }

    function _getTotalBonded(uint supply) private pure returns (uint) {
        // The price of each token is N * BASE_PRICE, where N is the supply
        // Sum the natural numbers and multiply by the base price to get the total value bonded
        return BASE_PRICE * supply * (supply + 1) / 2;
    }

    function _getMaxBond(uint sentWei) private pure returns (uint) {
        return sentWei * ((100 - FEE_PCT) / 100);
    }

    function claimFees() external {
        address recipient = Minter(_minter).getGovernance();

        uint feesWei = _unclaimedFees;
        _unclaimedFees = 0;

        (bool sent,) = recipient.call{value: feesWei}("");
        require(sent, "Unable To Send Fee");
    }

    function getUnclaimedFees() external view returns (uint) {
        return _unclaimedFees;
    }

    function getTokensIssued() external view returns (uint) {
        return _tokensIssued;
    }

    function getTotalBonded() external view returns (uint256) {
        return _getTotalBonded(_tokensIssued);
    }
}
