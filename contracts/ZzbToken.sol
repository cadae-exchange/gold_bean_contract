pragma solidity >=0.8.0 <0.9.0;

import './token/ERC20/ERC20.sol';

contract ZzbToken is ERC20 {
   constructor() public ERC20("JizhongziBean", "ZZB") {
     _mint(msg.sender, 3000000000000000000000000000); // 30亿枚
   }
}
