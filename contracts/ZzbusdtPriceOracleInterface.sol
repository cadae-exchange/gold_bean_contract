pragma solidity >=0.4.22 <0.9.0;

interface ZzbusdtPriceOracleInterface {
  function getLatestZzbusdtPrice() external returns (uint256);
}
