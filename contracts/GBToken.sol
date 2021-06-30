pragma solidity >=0.8.0 <0.9.0;

import './token/ERC20/ERC20.sol';

contract GBToken is ERC20 {
   constructor(address _publisher, uint _miningPoolAmount, uint _preMiningAmount) public ERC20("GoldBean", "GB") {
     _mint(msg.sender, _miningPoolAmount);
     _mint(_publisher, _preMiningAmount);
   }
}
