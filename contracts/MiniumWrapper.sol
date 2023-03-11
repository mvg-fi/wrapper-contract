// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

interface IAsset {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function transferFrom(address, address, uint256) external returns (bool);
    function transferWithExtra(address, uint256, bytes32) external returns (bool);
}

interface IBridge {
    function release(address, bytes32) external payable;
}

interface IRegistryExchange {
    function exchange_multiple(
        address[9] calldata,
        uint256[3][4] calldata,
        uint256,
        uint256,
        address[4] calldata
    ) external payable returns (uint256);
}

contract MiniumWrapper {
    event SwapAndWithdrawChainAsset(
        WithdrawalArguments w,
        ExchangeMultiplyArguments e
    );

    event SwapAndWithdrawSubAsset(
        WithdrawalArguments w,
        ExchangeMultiplyArguments e0,
        ExchangeMultiplyArguments e1
    );

    struct WithdrawalArguments {
        address outputAsset;     // Address of withdrawal asset
        address feeAsset;        // Address of fee asset
        uint256 feeAmount;       // Amount of fee
        bytes32 extraA;          // Extra for paying withdrawal asset
        bytes32 extraB;          // Extra for paying withdrawal fee
    }

    struct ExchangeMultiplyArguments {
        address[9] route;           // The route used for exchange to_asset/chain_asset
        uint256[3][4] swapParams;   // to_asset/chain_asset swapParams
        uint256 amount;             // Total input amount of from asset - from_fee_amount (which is amount1) or Amount of from asset that going to convert to chain asset
        uint256 expected;           // The minimum amount received after the final swap.
        address[4] pools;           // Array of pools for swaps via zap contracts. This parameter is useless
    }

    address public owner;
    bool public isKilled;
    uint256 public killDeadline;
    uint256 constant public KILL_DEADLINE_DT = 2 * 30 * 86400; // 2 months in seconds

    address constant private ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant private BRIDGE_ADDRESS = 0x0915EaE769D68128EEd9711A0bc4097831BE57F3;
    address constant private STORAGE_ADDRESS = 0xef241988D19892fE4efF4935256087F4fdc5ecAa;
    address constant private REGISTRY_EXCHANGE = 0x1f9C758E27D928c7295f66e7eb13d353c5291210;

    modifier onlyOwner() {
        require(msg.sender == owner, "MiniumWrapper: Only the owner can call this function");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
        killDeadline = block.timestamp + KILL_DEADLINE_DT;
    }

    function isETH(address contractAddress) internal pure returns (bool) {
        return contractAddress == ETH_ADDRESS;
    }

    function swapAndWithdrawChainAsset(
        ExchangeMultiplyArguments calldata e,
        WithdrawalArguments calldata w
    ) external {
        require(!isKilled, "MiniumWrapper: Contract is killed");
        uint256 recv;

        // If ERC20, transfer into contract
        if (!isETH(e.route[0])) {
            IAsset asset = IAsset(e.route[0]);
            asset.transferFrom(msg.sender, address(this), e.amount);
        }

        // Exchange
        recv = IRegistryExchange(REGISTRY_EXCHANGE).exchange_multiple(
            e.route,
            e.swapParams,
            e.amount,
            e.expected,
            e.pools
        );

        // Withdrawal
        if (isETH(w.outputAsset)) {
            IBridge(BRIDGE_ADDRESS).release{value:(recv - w.feeAmount)}(
                address(this),
                w.extraA
            );
        } else {
            IAsset(w.outputAsset).transferWithExtra(
                address(this),
                recv - w.feeAmount,
                w.extraA
            );
        }
        
        if (isETH(w.feeAsset)) {
            IBridge(BRIDGE_ADDRESS).release{value:(w.feeAmount)}(
                address(this),
                w.extraB
            );
        } else {
            IAsset(w.feeAsset).transferWithExtra(
                address(this),
                w.feeAmount,
                w.extraB
            );
        }
        
        emit SwapAndWithdrawChainAsset(w, e);
    }

    function swapAndWithdrawSubAsset(
        ExchangeMultiplyArguments calldata e0,
        ExchangeMultiplyArguments calldata e1,
        WithdrawalArguments calldata w
    ) external {
        require(!isKilled, "MiniumWrapper: Contract is killed");
        uint256 recv0;
        uint256 recv1;

        // If ERC20, transfer into contract
        if (!isETH(e0.route[0])) {
            IAsset asset = IAsset(e0.route[0]);
            asset.transferFrom(msg.sender, address(this), e0.amount);
        }

        recv0 = IRegistryExchange(REGISTRY_EXCHANGE).exchange_multiple(
            e0.route,
            e0.swapParams,
            e0.amount,
            e0.expected,
            e0.pools
        );

        recv1 = IRegistryExchange(REGISTRY_EXCHANGE).exchange_multiple(
            e1.route,
            e1.swapParams,
            e1.amount,
            e1.expected,
            e1.pools
        );

        require(recv1 >= w.feeAmount, "MiniumWrapper: Received fee is less than expected");

        // Withdrawal
        if (isETH(w.outputAsset)) {
            IBridge(BRIDGE_ADDRESS).release{value: recv0}(address(this), w.extraA);
        } else {
            IAsset(w.outputAsset).transferWithExtra(address(this), recv0, w.extraA);
        }

        if (isETH(w.feeAsset)) {
            IBridge(BRIDGE_ADDRESS).release{value: w.feeAmount}(address(this), w.extraB);
        } else {
            IAsset(w.feeAsset).transferWithExtra(address(this), w.feeAmount, w.extraB);
        }

        emit SwapAndWithdrawSubAsset(w, e0, e1);
    }

    function killMe() external onlyOwner {
        require(killDeadline > block.timestamp, "MiniumWrapper: Deadline has passed");
        isKilled = true;
    }

    function unKillMe() external onlyOwner {
        isKilled = false;
    }

    receive() external payable {}
}
