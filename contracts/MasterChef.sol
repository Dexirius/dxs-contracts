// SPDX-License-Identifier: MIT

//https://dexirius.finance

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./DXSToken.sol";

interface IMembers {
    function addMember(address _member, address _sponsor) external;

    function isMember(address _member) external view returns (bool);

    function membersList(uint256 _id) external view returns (address);

    function setVenus(address _venus) external;

    function getParentTree(address _member, uint256 _deep) external view returns (address[] memory);
}



// MasterChef is the master of Egg. He can make Egg and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once EGG is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of EGGs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accEggPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accEggPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. EGGs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that EGGs distribution occurs.
        uint256 accEggPerShare;   // Accumulated EGGs per share, times 1e12. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
    }

    // The EGG TOKEN!
    DXSToken public egg;
    // Members
    IMembers public member;       
    // Dev address.
    address public devaddr;
    // EGG tokens created per block.
    uint256 public eggPerBlock;
    // Bonus muliplier for early egg makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // Deposit Fee address
    address public feeAddress;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    mapping(address => mapping(uint256 => uint256)) public userDexirius;
    address setup;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when EGG mining starts.
    uint256 public startBlock;
    bool public paused = true;
    uint256[5] public refPercent = [0, 0, 0, 0, 0];
    uint256[5] public refBalance = [0, 0, 0, 0, 0];
    address public moderator;
    address public charity;
    
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        DXSToken _egg,
        address _devaddr,
        address _feeAddress,
        uint256 _eggPerBlock,
        uint256 _startBlock,
        IMembers _member,
        address _moderator,
        address _charity
    ) public {
        egg = _egg;
        devaddr = _devaddr;
        feeAddress = _feeAddress;
        eggPerBlock = _eggPerBlock;
        startBlock = _startBlock;
        member = _member;
        moderator = _moderator;
        charity = _charity;
    }

    modifier onlyOwnerAndSetup() {
        require(owner() == msg.sender || setup == msg.sender, "Ownable: caller is not the owner or setup");
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _lpToken, uint16 _depositFeeBP, bool _withUpdate) public onlyOwnerAndSetup {
        require(_depositFeeBP <= 10000, "add: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accEggPerShare: 0,
            depositFeeBP: _depositFeeBP
        }));
    }

    // Update the given pool's EGG allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate) public onlyOwner {
        require(_depositFeeBP <= 10000, "set: invalid deposit fee basis points");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending EGGs on frontend.
    function pendingEgg(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accEggPerShare = pool.accEggPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 eggReward = multiplier.mul(eggPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accEggPerShare = accEggPerShare.add(eggReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accEggPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
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
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 eggReward = multiplier.mul(eggPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        egg.mint(devaddr, eggReward.div(10));
        egg.mint(charity, eggReward.div(4));
        egg.mint(address(this), eggReward);
        pool.accEggPerShare = pool.accEggPerShare.add(eggReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for EGG allocation.
    function deposit(uint256 _pid, uint256 _amount, address ref) public {
        require(paused == false, "!paused");

        if(member.isMember(ref) == false){
            ref = member.membersList(0);
        }

        if(member.isMember(msg.sender) == false){
            member.addMember(msg.sender, ref);
        }         

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accEggPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeEggTransfer(msg.sender, pending);
                referrals(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if(pool.depositFeeBP > 0){
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            }else{
                user.amount = user.amount.add(_amount);
            }
            userDexirius[msg.sender][_pid] = now;
        }
        user.rewardDebt = user.amount.mul(pool.accEggPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        require(paused == false, "!paused");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accEggPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeEggTransfer(msg.sender, pending);
            referrals(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accEggPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        require(paused == false, "!paused");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe egg transfer function, just in case if rounding error causes pool to not have enough EGGs.
    function safeEggTransfer(address _to, uint256 _amount) internal {
        uint256 eggBal = egg.balanceOf(address(this));
        if (_amount > eggBal) {
            egg.transfer(_to, eggBal);
        } else {
            egg.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    function setFeeAddress(address _feeAddress) public{
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
    }

    function setChariryAddress(address _charityAddress) public{
        require(msg.sender == charity, "setChariryAddress: FORBIDDEN");
        charity = _charityAddress;
    }

    //Pancake has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _eggPerBlock) public onlyOwner {
        massUpdatePools();
        eggPerBlock = _eggPerBlock;
    }

    function updatePaused(bool _value) public {
        require(moderator == msg.sender);
        paused = _value;
    }

    function setPercent(uint256 r_1, uint256 r_2, uint256 r_3, uint256 r_4, uint256 r_5) external onlyOwner {
        refPercent[0] = r_1;
        refPercent[1] = r_2;
        refPercent[2] = r_3;
        refPercent[3] = r_4;
        refPercent[4] = r_5;
    }    
    function setRefBalance(uint256 r_1, uint256 r_2, uint256 r_3, uint256 r_4, uint256 r_5) external onlyOwner {
        refBalance[0] = r_1;
        refBalance[1] = r_2;
        refBalance[2] = r_3;
        refBalance[3] = r_4;
        refBalance[4] = r_5;
    }    

    function addSetup(address _setup) external {
        require(setup == address(0));
        setup = _setup;
    }

    function register(address ref) external {
        if(member.isMember(ref) == false){
            ref = member.membersList(0);
        }
        if(member.isMember(msg.sender) == false){
            member.addMember(msg.sender, ref);
        }
    }

    function referrals(address _user, uint256 _amount) public {
        address[] memory refTree = member.getParentTree(_user, 5);
        for (uint256 i = 0; i < 5; i++) {
            if (refTree[i] != address(0) && refPercent[i] > 0 && _amount > 0) {
                uint256 refAmount = _amount.mul(refPercent[i]).div(100 ether);
                if(refAmount > 0 && egg.balanceOf(refTree[i]) >= refBalance[i]){
                    egg.mint(refTree[i], refAmount);
                }
            } else {
                break;
            }
        }
    }

    function changeMod(address _mod) external {
        require(moderator == msg.sender);
        moderator = _mod;
    }


}
