# 金豆合约

## 一. 开发环境

1. node 12.16.1
2. Truffle v5.3.3 (core: 5.3.3)
3. Solidity - 0.8.1 (solc-js)
4. Node v10.16.0
5. Web3.js v1.3.5


## 二. 运行命令

1. 安装本地个人区块链工具
```
npm install -g ganache-cli
```

2. 运行区块链工具(增加了gas limit)
```
ganache-cli -l 0xf691b7

```

3. 部署合约
```
$ truffle migrate --reset
```

4. 单元测试
```
$ truffle test --stacktrace
```
