// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakableToken is IERC20, Ownable {
    using SafeMath for uint256;

    string public _name;
    string public _symbol;
    uint8 public _decimals;
    uint256 public _totalSupply;

    mapping(address => uint256) public _balances;
    mapping(address => mapping(address => uint256)) public _allowances;

    uint256 public _stakingDuration;
    uint256 public _rewardRate;
    uint256 public _lastRewardTimestamp;
    uint256 public _totalRewards;

    struct StakingInfo {
        uint256 amount;
        uint256 startTimestamp;
    }

    mapping(address => StakingInfo) public _stakedBalances;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 stakingDuration_,
        uint256 rewardRate_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = totalSupply_ * 10**uint256(decimals_);
        _stakingDuration = stakingDuration_;
        _rewardRate = rewardRate_;
        _lastRewardTimestamp = block.timestamp;
        _totalRewards = 0;

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero")
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // Staking functions

    function stake(uint256 amount) public {
        require(amount > 0, "Cannot stake zero tokens");
        require(_balances[msg.sender] >= amount, "Not enough balance to stake");
        require(_stakedBalances[msg.sender].amount == 0, "Already staked");

        _transfer(msg.sender, address(this), amount);
        _stakedBalances[msg.sender] = StakingInfo(amount, block.timestamp);

        emit Staked(msg.sender, amount);
    }

    function unstake() public {
        require(_stakedBalances[msg.sender].amount > 0, "Nothing staked");
        require(
            block.timestamp >= _stakedBalances[msg.sender].startTimestamp.add(_stakingDuration),
            "Staking period not completed"
        );

        uint256 stakedAmount = _stakedBalances[msg.sender].amount;
        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = stakedAmount.add(reward);

        _stakedBalances[msg.sender] = StakingInfo(0, 0);
        _transfer(address(this), msg.sender, totalAmount);

        emit Unstaked(msg.sender, stakedAmount, reward);
    }

    function calculateReward(address account) public view returns (uint256) {
        if (_stakedBalances[account].amount == 0) return 0;

        uint256 timeStaked = block.timestamp.sub(_stakedBalances[account].startTimestamp);
        uint256 reward = _stakedBalances[account].amount.mul(timeStaked).mul(_rewardRate).div(_stakingDuration).div(1e18);
        return reward;
    }

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 stakedAmount, uint256 reward);
}
