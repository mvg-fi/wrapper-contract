# @version 0.3.7
# license GPL
# Wrapper contract that simplies the bridging process

interface Asset:
    def balanceOf(_who: address) -> uint256: view
    def transfer(_to: address, _value: uint256) -> bool : nonpayable
    def allowance(_owner: address, _spender: address) -> uint256: view
    def approve(_spender: address, _value: uint256) -> bool: nonpayable
    def transferFrom(_from: address, _to: address, _value: uint256) -> bool : nonpayable
    def transferWithExtra(_to: address, _value: uint256, _extra: bytes32) -> bool: nonpayable

interface Bridge:
    def release(receiver: address, input: bytes32): payable

interface RegistryExchange:
    def exchange_multiple(_route: address[9],_swap_params: uint256[3][4],_amount: uint256,_expected: uint256,_pools: address[4]) -> uint256: payable

event SwapAndWithdrawChainAsset:
    w: WithdrawalArguments          # Params for withdrawal
    e: ExchangeMultiplyArguments    # Params for exchange chain asset

event SwapAndWithdrawSubAsset:
    w: WithdrawalArguments          # Params for withdrawal
    e0: ExchangeMultiplyArguments   # Params for exchange withdrawal asset
    e1: ExchangeMultiplyArguments   # Params for exchange fee asset

struct WithdrawalArguments:
    _output_asset: address      # Address of withdrawal asset
    _fee_asset: address         # Address of fee asset
    _fee_amount: uint256        # Amount of fee
    _extra_a: bytes32           # Extra for paying withdrawal asset
    _extra_b: bytes32           # Extra for paying withdrawal fee

struct ExchangeMultiplyArguments:
    _route: address[9]          # The route used for exchange _to to_asset/chain_asset
    _swap_params: uint256[3][4] # to_asset/chain_asset swapParams
    _amount: uint256            # Total input amount of from asset - from_fee_amount (which is _amount1) or Amount of from asset that going to convert to chain asset
    _expected: uint256          # The minimum amount received after the final swap.
    _pools: address[4]          # Array of pools for swaps via zap contracts. This parameter is useless

owner: public(address)
ETH_ADDRESS: constant(address) = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
BRIDGE_ADDRESS: constant(address) = 0x0915EaE769D68128EEd9711A0bc4097831BE57F3
STORAGE_ADDRESS: constant(address) = 0xef241988D19892fE4efF4935256087F4fdc5ecAa
REGISTRY_EXCHANGE: constant(address) = 0x1f9C758E27D928c7295f66e7eb13d353c5291210

is_killed: bool
kill_deadline: uint256
KILL_DEADLINE_DT: constant(uint256) = 2 * 30 * 86400

@external
def __init__(
    _owner: address,
):
    self.owner = _owner
    self.kill_deadline = block.timestamp + KILL_DEADLINE_DT

@internal
def IsETH(contract: address) -> bool:
    return contract == ETH_ADDRESS

@external
def SwapAndWithdrawChainAsset(
    e: ExchangeMultiplyArguments,
    w: WithdrawalArguments,
):
    """
    In case the withdrawal asset == chain asset. e.g ETH -> EOS
    """
    assert not self.is_killed  # dev: is killed

    recv: uint256 = 0
    # If ERC20, transfer into contract
    if (self.IsETH(e._route[0]) == False):
        Asset(e._route[0]).transferFrom(msg.sender ,self, e._amount)
    
    # Exchange
    recv = RegistryExchange(REGISTRY_EXCHANGE).exchange_multiple(e._route, e._swap_params, e._amount, e._expected, e._pools)
    
    # Withdrawal
    if (self.IsETH(w._output_asset)):
        Bridge(BRIDGE_ADDRESS).release.value(recv - w._fee_amount)(self, w._extra_a)
    else:
        Asset(w._output_asset).transferWithExtra(self, recv - w._fee_amount, w._extra_a)
    
    if (self.IsETH(w._fee_asset)):
        Bridge(BRIDGE_ADDRESS).release.value(w._fee_amount)(self, w._extra_b)
    else:
        Asset(w._fee_asset).transferWithExtra(self, w._fee_amount, w._extra_b)
    log SwapAndWithdrawChainAsset(e, w)

@external
@nonreentrant('lock')
def SwapAndWithdrawSubAsset(
    e0: ExchangeMultiplyArguments,
    e1: ExchangeMultiplyArguments,
    w: WithdrawalArguments,
):
    """
    In case the withdrawal asset is not a chain asset. e.g ETH -> USDC(Matic)
    """
    assert not self.is_killed  # dev: is killed
    
    recv0: uint256 = 0
    recv1: uint256 = 0
    # If ERC20, transfer into contract
    if (self.IsETH(e._route[0]) == False):
        Asset(e._route[0]).transferFrom(msg.sender, self, e._amount)

    recv0 = RegistryExchange(REGISTRY_EXCHANGE).exchange_multiple(e0._route, e0._swap_params, e0._amount, e0._expected, e0._pools)
    recv1 = RegistryExchange(REGISTRY_EXCHANGE).exchange_multiple(e1._route, e1._swap_params, e1._amount, e1._expected, e1._pools)
    assert recv1 >= w._fee_amount

    # Withdrawal
    if (self.IsETH(w._output_asset)):
        Bridge(BRIDGE_ADDRESS).release.value(recv0)(self, w._extra_a)
    else:
        Asset(w._output_asset).transferWithExtra(self, recv0, w._extra_a)
    
    if (self.IsETH(w._fee_asset)):
        Bridge(BRIDGE_ADDRESS).release.value(w._fee_amount)(self, w._extra_b)
    else:
        Asset(w._fee_asset).transferWithExtra(self, w._fee_amount, w._extra_b)
    log SwapAndWithdrawSubAsset(w, e0, e1)

@external
def kill_me():
    assert msg.sender == self.owner  # dev: only owner
    assert self.kill_deadline > block.timestamp  # dev: deadline has passed
    self.is_killed = True

@external
def unkill_me():
    assert msg.sender == self.owner  # dev: only owner
    self.is_killed = False