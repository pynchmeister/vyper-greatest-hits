# @version ^0.3.2
# @dev Implementation of ERC-721 non-fungible token standard with Metadata.

# Interface for the contract called by safeTransferFrom()
interface NFTReceiver:
    def onERC721Received(
            _operator: address,
            _from: address,
            _tokenId: uint256,
            _data: Bytes[1024]
        ) -> bytes32: view


# @dev Emits when ownership of any NFT changes by any mechanism. This event emits when NFTs are
#      created (`from` == 0) and destroyed (`to` == 0). Exception: during contract creation, any
#      number of NFTs may be created and assigned without emitting Transfer. At the time of any
#      transfer, the approved address for that NFT (if any) is reset to none.
# @param _from Sender of NFT (if address is zero address it indicates token creation).
# @param _to Receiver of NFT (if address is zero address it indicates token destruction).
# @param _tokenId The NFT that got transfered.
event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _tokenId:indexed(uint256)


# @dev This emits when the approved address for an NFT is changed or reaffirmed. The zero
#      address indicates there is no approved address. When a Transfer event emits, this also
#      indicates that the approved address for that NFT (if any) is reset to none.
# @param _owner Owner of NFT.
# @param _approved Address that we are approving.
# @param _tokenId NFT which we are approving.
event Approval:
    _owner: indexed(address)
    _approved: indexed(address)
    _tokenId:indexed(uint256)


# @dev This emits when an operator is enabled or disabled for an owner. The operator can manage
#      all NFTs of the owner.
# @param _owner Owner of NFT.
# @param _operator Address to which we are setting operator rights.
# @param _approved Status of operator rights(true if operator rights are given and false if
# revoked).
event ApprovalForAll:
    _owner: indexed(address)
    _operator: indexed(address)
    _approved: bool


IDENTITY_PRECOMPILE: constant(address) = 0x0000000000000000000000000000000000000004


# @dev Mapping from NFT ID to the address that owns it.
idToOwner: HashMap[uint256, address]

# @dev Mapping from NFT ID to approved address.
idToApprovals: HashMap[uint256, address]

# @dev Mapping from owner address to count of his tokens.
ownerToNFTokenCount: HashMap[address, uint256]

# @dev Mapping from owner address to mapping of operator addresses.
ownerToOperators: HashMap[address, HashMap[address, bool]]

# @dev The name of the NFT project
name: public(String[20])

# @dev The symbol of the NFT project
symbol: public(String[5])

# @dev The baseURI of the NFT project (for the tokenURI method)
baseURI: public(String[256])


# @dev Contract constructor..
@external
def __init__(_name: String[20], _symbol: String[5], _baseURI: String[256]):
    self.name = _name
    self.symbol = _symbol
    self.baseURI = _baseURI


# @dev Converts integer to String
# From https://github.com/curvefi/curve-veBoost/blob/0e51be10638df2479d9e341c07fafa940ef58596/contracts/VotingEscrowDelegation.vy#L423
# Author: skellet0r
@internal
@view
def _uint_to_string(_value: uint256) -> String[78]:
    # NOTE: Odd that this works with a raw_call inside, despite being marked
    # a pure function
    if _value == 0:
        return "0"

    buffer: Bytes[78] = b""
    digits: uint256 = 78

    for i in range(78):
        # go forward to find the # of digits, and set it
        # only if we have found the last index
        if digits == 78 and _value / 10 ** i == 0:
            digits = i

        value: uint256 = ((_value / 10 ** (77 - i)) % 10) + 48
        char: Bytes[1] = slice(convert(value, bytes32), 31, 1)
        buffer = raw_call(
            IDENTITY_PRECOMPILE,
            concat(buffer, char),
            max_outsize=78,
            is_static_call=True
        )

    return convert(slice(buffer, 78 - digits, digits), String[78])


# @dev Returns the URI of the token item
@external
@view
def tokenURI(tokenId: uint256) -> String[350]:
    return concat(self.baseURI, self._uint_to_string(tokenId))


# @dev Returns the number of NFTs owned by `_owner`. NFTs assigned to the zero address are
#      considered invalid, and this function throws for queries about the zero address.
# @param _owner Address for whom to query the balance.
@external
@view
def balanceOf(_owner: address) -> uint256:
    assert _owner != ZERO_ADDRESS
    return self.ownerToNFTokenCount[_owner]


# @dev Returns the address of the owner of the NFT. NFTs assigned to zero address are considered
#      invalid, and queries about them do throw.
# @param _tokenId The identifier for an NFT.
@internal
@view
def ownerOf(_tokenId: uint256) -> address:
    assert self.idToOwner[_tokenId] != ZERO_ADDRESS
    return self.idToOwner[_tokenId]


### TRANSFER FUNCTION HELPERS ###

# NOTE: as VYPER uses a new message call for a function call, I needed to pass `_sender: address`
#       rather than use msg.sender
# @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
#      address for this NFT.
# Throws if `_from` is not the current owner.
# Throws if `_to` is the zero address.
# Throws if `_tokenId` is not a valid NFT.
@internal
def _validateTransferFrom(_from: address, _to: address, _tokenId: uint256, _sender: address):
    # Check that _to and _from are valid addresses
    assert _from != ZERO_ADDRESS
    assert _to != ZERO_ADDRESS
    # Throws if `_from` is not the current owner
    assert self.idToOwner[_tokenId] == _from
    # Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
    # address for this NFT.
    senderIsOwner: bool = self.idToOwner[_tokenId] == _sender
    senderIsApproved: bool = self.idToApprovals[_tokenId] == _sender
    senderIsOperator: bool = (self.ownerToOperators[_from])[_sender]
    assert (senderIsOwner or senderIsApproved) or senderIsOperator


@internal
def _doTransfer(_from: address, _to: address, _tokenId: uint256):
    # Change the owner
    self.idToOwner[_tokenId] = _to
    # Reset approvals
    self.idToApprovals[_tokenId] = ZERO_ADDRESS
    # Change count tracking
    self.ownerToNFTokenCount[_to] += 1
    self.ownerToNFTokenCount[_from] -= 1
    # Log the transfer
    log Transfer(_from, _to, _tokenId)


### TRANSFER FUNCTIONS ###

# @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
#      address for this NFT.
#      Throws if `_from` is not the current owner.
#      Throws if `_to` is the zero address.
#      Throws if `_tokenId` is not a valid NFT.
# @notice The caller is responsible to confirm that `_to` is capable of receiving NFTs or else
#         they maybe be permanently lost.
# @param _from The current owner of the NFT.
# @param _to The new owner.
# @param _tokenId The NFT to transfer.
@external
def transferFrom(_from: address, _to: address, _tokenId: uint256):
    self._validateTransferFrom(_from, _to, _tokenId, msg.sender)
    self._doTransfer(_from, _to, _tokenId)


# @dev Transfers the ownership of an NFT from one address to another address.
# @notice Throws unless `msg.sender` is the current owner, an authorized operator, or the
#         approved address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is
#         the zero address. Throws if `_tokenId` is not a valid NFT. When transfer is complete, this
#         function checks if `_to` is a smart contract (code size > 0). If so, it calls `onERC721Received`
#         on `_to` and throws if the return value is not `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`.
#         NOTE: bytes4 is represented by bytes32 with padding
# @param _from The current owner of the NFT.
# @param _to The new owner.
# @param _tokenId The NFT to transfer.
# @param _data Additional data with no specified format, sent in call to `_to`.
@external
def safeTransferFrom(
        _from: address,
        _to: address,
        _tokenId: uint256,
        _data: Bytes[1024]
    ):
    self._validateTransferFrom(_from, _to, _tokenId, msg.sender)
    self._doTransfer(_from, _to, _tokenId)
    _operator: address = ZERO_ADDRESS
    if(_to.codesize > 0):
        returnValue: bytes32 = NFTReceiver(_to).onERC721Received(_operator, _from, _tokenId, _data)
        assert returnValue == method_id("onERC721Received(address,address,uint256,bytes)", output_type=bytes32)


# @dev Set or reaffirm the approved address for an NFT.
# @notice The zero address indicates there is no approved address. Throws unless `msg.sender` is
#         the current NFT owner, or an authorized operator of the current owner.
# @param _approved Address to be approved for the given NFT ID.
# @param _tokenId ID of the token to be approved.
@external
def approve(_approved: address, _tokenId: uint256):
    # get owner
    owner: address = self.idToApprovals[_tokenId]
    # check requirements
    senderIsOwner: bool = self.idToOwner[_tokenId] == msg.sender
    senderIsOperator: bool = (self.ownerToOperators[owner])[msg.sender]
    assert (senderIsOwner or senderIsOperator)
    # set the approval
    self.idToApprovals[_tokenId] = _approved
    log Approval(owner, _approved, _tokenId)


# @dev Enables or disables approval for a third party ("operator") to manage all of
#      `msg.sender`'s assets. It also emits the ApprovalForAll event.
# @notice This works even if sender doesn't own any tokens at the time.
# @param _operator Address to add to the set of authorized operators.
# @param _approved True if the operators is approved, false to revoke approval.
@external
def setApprovalForAll(_operator: address, _approved: bool):
    assert _operator != ZERO_ADDRESS
    self.ownerToOperators[msg.sender][_operator] = _approved
    log ApprovalForAll(msg.sender, _operator, _approved)


# @dev Get the approved address for a single NFT.
# @notice Throws if `_tokenId` is not a valid NFT.
# @param _tokenId ID of the NFT to query the approval of.
@external
@view
def getApproved(_tokenId: uint256) -> address:
    assert self.idToOwner[_tokenId] != ZERO_ADDRESS
    return self.idToApprovals[_tokenId]


# @dev Checks if `_operator` is an approved operator for `_owner`.
# @param _owner The address that owns the NFTs.
# @param _operator The address that acts on behalf of the owner.
@external
@view
def isApprovedForAll( _owner: address, _operator: address) -> bool:
    # TODO: check original for _owner == 0x0
    if (_owner == ZERO_ADDRESS):
        return False
    return (self.ownerToOperators[_owner])[_operator]
