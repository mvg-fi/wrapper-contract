struct PreAction:
    destination: String[200]
    memo: String[200]
    trace_id: String[36]

struct Action:
    destination: String[200]
    memo: String[200]
    extra: String[200]

MVM_REGISTRY_ID_HEX: public(bytes32)
MVM_STORAGE_ADDRESS_HEX: public(bytes32)

# uuid.FromStringOrNil(MVMRegistryId).Bytes()
self.MVM_REGISTRY_ID_HEX = bd67087276ce3263b9333aa337e212a4
# hex.DecodeString(MVMStorageContract[2:])
self.MVM_STORAGE_ADDRESS_HEX = ef241988d19892fe4eff4935256087f4fdc5ecaa

@internal
def BuildExtra(a: PreAction):
    """
    @destination: The recipent address
    @memo: The memo carrired by the transfer
    @trace_id: UUID for tracing transaction
    """
    #WIP
    #extra: Determine tx type. e.g. TraceID:A|B
    assert self.MVM_REGISTRY_ID_HEX != None
    assert self.MVM_STORAGE_ADDRESS_HEX != None
    assert a.destination != None
    assert a.memo != None
    assert a.trace_id != None

    _a = keccak256({destination: a.destination, memo: a.memo, extra: a.trace_id + ":A"})
    _b = keccak256({destination: a.destination, memo: a.memo, extra: a.trace_id + ":B"})

    return [
        extract32((self.MVM_REGISTRY_ID_HEX + self.MVM_STORAGE_ADDRESS_HEX + _a), 0, String),
        extract32((self.MVM_REGISTRY_ID_HEX + self.MVM_STORAGE_ADDRESS_HEX + _b), 0, String),
    ]

@external
def update_addresses(registry_id_hex: bytes32, storage_address_hex: bytes32):
    assert msg.sender == self.owner  # dev: only owner
    self.MVM_REGISTRY_ID_HEX = registry_id_hex
    self.MVM_STORAGE_ADDRESS_HEX = storage_address_hex
