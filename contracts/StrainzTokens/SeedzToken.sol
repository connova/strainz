// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../StrainzMaster.sol";

contract SeedzToken is ERC20 {

    StrainzMaster master;
    modifier onlyMaster() {
        require(msg.sender == address(master));
        _;
    }
    modifier onlyStrainzNFT() {
        require(msg.sender == address(master.strainzNFT()));
        _;
    }

    mapping(uint => uint) public lastTimeGrowFertilizerUsedOnPlant;

    event FertilizerBought(address buyer, uint plantId);

    uint public growFertilizerCost = 500e18;
    uint public growFertilizerBoost = 100;

    function buyGrowFertilizer(uint plantId) public {
        uint cost = growFertilizerCost;

        require(balanceOf(msg.sender) >= cost);
        require(lastTimeGrowFertilizerUsedOnPlant[plantId] + 1 weeks < block.timestamp);
        _burn(msg.sender, cost);
        lastTimeGrowFertilizerUsedOnPlant[plantId] = block.timestamp;
        emit FertilizerBought(msg.sender, plantId);
    }

    function setGrowFertilizerDetails(uint newCost, uint newBoost) public onlyMaster {
        growFertilizerCost = newCost;
        growFertilizerBoost = newBoost;
    }
    // LP Pools by Sushiswap: https://etherscan.io/address/0xc2edad668740f1aa35e4d8f227fb8e17dca888cd#code
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SEEDZ
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSeedzPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accSeedzPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. SEEDZ to distribute per block.
        uint256 lastRewardBlock;  // Last block number that SEEDZ distribution occurs.
        uint256 accSeedzPerShare; // Accumulated SEEDZ per share, times 1e12. See below.
    }

    // SEEDZ tokens created per block.
    uint256 public seedzPerBlock = 5e17;

    function setSeedzPerBlock(uint _seedzPerBlock) public onlyMaster {
        massUpdatePools();
        seedzPerBlock = _seedzPerBlock;

    }

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);


    constructor(address owner) ERC20("Seedz", "SEEDZ") {
        master = StrainzMaster(msg.sender);
        _mint(owner, 125000 * 1e18); // initial liquidity
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyMaster {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint += _allocPoint;
        poolInfo.push(PoolInfo({
        lpToken : _lpToken,
        allocPoint : _allocPoint,
        lastRewardBlock : block.number,
        accSeedzPerShare : 0
        }));
    }

    // Update the given pool's SEEDZ allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyMaster {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // View function to see pending SEEDZ on frontend.
    function pendingSeedz(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSeedzPerShare = pool.accSeedzPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 seedzReward = multiplier * seedzPerBlock * pool.allocPoint / totalAllocPoint;
            accSeedzPerShare += seedzReward * 1e12 / lpSupply;
        }
        return (user.amount * accSeedzPerShare / 1e12) - user.rewardDebt;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - pool.lastRewardBlock;
        uint256 seedzReward = multiplier * seedzPerBlock * pool.allocPoint / totalAllocPoint;
        _mint(address(this), seedzReward);
        pool.accSeedzPerShare += seedzReward * 1e12 / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for SEEDZ allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.accSeedzPerShare / 1e12) - user.rewardDebt;
            safeSeedzTransfer(msg.sender, pending);
        }
        pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
        user.amount += _amount;
        user.rewardDebt = user.amount * pool.accSeedzPerShare / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = (user.amount * pool.accSeedzPerShare / 1e12) - user.rewardDebt;
        safeSeedzTransfer(msg.sender, pending);
        user.amount -= _amount;
        user.rewardDebt = user.amount * pool.accSeedzPerShare / 1e12;

        pool.lpToken.transfer(address(msg.sender), _amount);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.transfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe SEEDZ transfer function, just in case if rounding error causes pool to not have enough SEEDZ.
    function safeSeedzTransfer(address _to, uint256 _amount) internal {
        uint256 seedzBal = balanceOf(address(this));
        if (_amount > seedzBal) {
            _transfer(address(this), _to, seedzBal);
        } else {
            _transfer(address(this), _to, _amount);
        }
    }


    function compostMint(address receiver, uint amount) public onlyStrainzNFT {
        _mint(receiver, amount);
    }

    function getHarvestableFertilizerAmount(uint strainId, uint lastHarvest) public view returns (uint) {
        uint fertilizerBonus = 0;
        uint fertilizerAttachTime = lastTimeGrowFertilizerUsedOnPlant[strainId];
        if (fertilizerAttachTime > 0) {
            uint start = max(fertilizerAttachTime, lastHarvest);

            uint end = min(start + 1 weeks, block.timestamp);

            fertilizerBonus = (end - start) * growFertilizerBoost / 1 days;
        }
        return fertilizerBonus;
    }

    function breedBurn(address account, uint amount) public onlyStrainzNFT {
        _burn(account, amount);
    }


    function max(uint a, uint b) private pure returns (uint) {
        if (a > b) {
            return a;
        } else return b;
    }

    function min(uint a, uint b) private pure returns (uint) {
        if (a < b) {
            return a;
        } else return b;
    }


    function decimals() public pure override returns (uint8) {
        return 18;
    }

}
