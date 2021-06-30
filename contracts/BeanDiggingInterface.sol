pragma solidity >=0.4.22 <0.9.0;

interface BeanDiggingInterface {
  function oracleCallback(uint256 _zzbusdtPrice, uint256 id) external;
}
