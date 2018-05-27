pragma solidity 0.4.23;

// Safe Math library that automatically checks for overflows and underflows
library SafeMath {
    // Safe multiplication
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }
    // Safe subtraction
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }
    // Safe addition
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c>=a && c>=b);
        return c;
    }
}

/// @title Owned contract
/// @author InnoChain
contract Owned {
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner, "msg.sender isn't owner");
        _;
    }
    constructor() public {
        owner = msg.sender;
    }
}

/// @title ERC20 Token contract
/// @author InnoChain
/// @notice Basic ERC20 functionality
contract Token is Owned {
    using SafeMath for uint256;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    // This creates a mapping with all balances
    mapping (address => uint256) public balanceOf;
    // Another mapping with spending allowances
    mapping (address => mapping (address => uint256)) public allowance;
    // The total supply of the token
    uint256 public totalSupply;
    // variables for wallet integration
    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(uint256 _totalSupply, uint256 loyaltyReward) public {
        name = "Odeon Mining Token";
        symbol = "OMT";
        decimals = 18;
        totalSupply = _totalSupply;
        balanceOf[owner] = totalSupply.sub(loyaltyReward);
        balanceOf[address(this)] = loyaltyReward;
        // in case of the unlikely event that the tokens get locked inside the contract, the owner can withdraw the loyalty bonus tokens.
        allowance[address(this)][owner] = loyaltyReward;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != 0x0);
        require(_to != address(this));
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != 0x0);
        require(_to != address(this));
        balanceOf[_to] = balanceOf[_to].add(_value);
        balanceOf[_from] = balanceOf[_from].sub(_value);
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function increaseApproval(address _spender, uint _addedValue) public returns (bool success) {
        allowance[msg.sender][_spender] = allowance[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }
    
    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool success) {
        uint256 oldValue = allowance[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowance[msg.sender][_spender] = 0;
        } else {
            allowance[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }
}

contract Loyalty is Token {

    mapping(address => uint256) private timer;
    uint256 public rewardPerDayWei;
    bool public active;
    uint256 private timePeriod;

    constructor() public {
        active = true;
        // 6% per year
        rewardPerDayWei = 164383561600000;
        timePeriod = 1 days;
    }

    function update(address _tokenHolder) private {
        // the owner and the contract itself are not allowed to participate in the loyalty reward
        if (_tokenHolder != owner && _tokenHolder != address(this)) {
            uint256 tempTimer = timer[_tokenHolder];
            // initialize counter
            if (tempTimer == 0) {
                timer[_tokenHolder] = now;
            } else {
                // calculate number of days since last Loyalty reward withdrawal
                uint256 dayCount = now.sub(tempTimer)/timePeriod;
                // subtract number of days from timer
                timer[_tokenHolder] = tempTimer.add(dayCount.mul(timePeriod));
                // If number of days greater than 0, pay out loyalty reward
                if (dayCount > 0) {
                    // temporary variables for balance of tokenholder and contract and reward to save gas
                    uint256 balance = balanceOf[_tokenHolder];
                    // calculate token reward: daily token reward for one token * number of days * balance / 10^18
                    uint256 reward = rewardPerDayWei.mul(dayCount).mul(balance)/(1 ether);
                    uint256 contractBalance = balanceOf[address(this)];
                    // if reward is smaller than contract Balance, pay out the rest of the tokens and set the active bool to false
                    // else pay out reward and subtract it from the contract balance
                    if (reward > contractBalance) {
                        active = false;
                        balanceOf[address(this)] = 0;
                        balanceOf[_tokenHolder] = balance.add(contractBalance);
                        emit Transfer(address(this), _tokenHolder, contractBalance);
                    } else {
                        balanceOf[address(this)] = contractBalance.sub(reward);
                        balanceOf[_tokenHolder] = balance.add(reward);
                        emit Transfer(address(this), _tokenHolder, reward);
                    }
                }
            }
        }
    }

    function getRewardValue(address _tokenHolder) public view returns (uint256) {
        if (!active) {
            return 0;
        }
        // the owner is not allowed to participate in the loyalty reward
        if (_tokenHolder == owner) {
            return 0;
        } else {
            uint256 tempTimer = timer[_tokenHolder];
            // initialize counter
            if (tempTimer == 0) {
                return 0;
            } else {
                // calculate number of days since last Loyalty reward withdrawal
                uint256 dayCount = now.sub(tempTimer)/timePeriod;
                // If number of days greater than 0, pay out loyalty reward
                if (dayCount > 0) {
                    // temporary variables for balance of tokenholder and contract and reward to save gas
                    uint256 balance = balanceOf[_tokenHolder];
                    // calculate token reward: daily token reward for one token * number of days * balance / 10^18
                    return rewardPerDayWei.mul(dayCount).mul(balance)/(1 ether);
                } else {
                    return 0;
                }
            }
        }
    }

    /**
    Emergency function: if the contract is locked due to a bug in the smart contract code, 
    the owner can deactivate the loyalty bonus so the token can function as usual
     */
    function emergencyLock() external onlyOwner {
        active = false;        
    }

    // functions to collect the token reward
    function collectReward(address _tokenHolder) public {
        require(active);
        update(_tokenHolder);
    }
    // use fallback function so tokenholders can withdraw the loyalty reward without having to call a function
    function () public payable {
        require(msg.value == 0);
        require(active);
        update(msg.sender);
    }

    // overwrite transfer and transferFrom functions
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != 0x0);
        require(_to != address(this));
        // update and payout loyalty rewards during transfer
        if (active) {
            update(msg.sender);
            update(_to);
        }
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_to != 0x0);
        require(_to != address(this));
        // update and payout loyalty rewards during transfer
        if (active) {
            update(_from);
            update(_to);
        }
        balanceOf[_to] = balanceOf[_to].add(_value);
        balanceOf[_from] = balanceOf[_from].sub(_value);
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

}

contract Odeon is Loyalty {
    constructor(uint256 _totalSupply, uint256 loyaltyReward) public Token(_totalSupply, loyaltyReward) {}
}