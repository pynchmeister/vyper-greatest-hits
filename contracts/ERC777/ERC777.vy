# ERC777 Token Standard
# https://eips.ethereum.org/EIPS/eip-777


# Interface for ERC1820 registry contract
# https://eips.ethereum.org/EIPS/eip-1820
contract ERC1820Registry:
    def setInterfaceImplementer(
        _addr: address,
        _interfaceHash: bytes32,
        _implementer: address,
    ): modifying
    def getInterfaceImplementer(
        _addr: address,
        _interfaceHash: bytes32,
    ) -> address: modifying

# Interface for ERC777Tokens sender contracts
contract ERC777TokensSender:
    def tokensToSend(
        _operator: address,
        _from: address,
        _to: address,
        _amount: uint256,
        _data: bytes[256],
        _operatorData: bytes[256]
    ): modifying

# Interface for ERC777Tokens recipient contracts
contract ERC777TokensRecipient:
    def tokensReceived(
        _operator: address,
        _from: address,
        _to: address,
        _amount: uint256,
        _data: bytes[256],
        _operatorData: bytes[256]
    ): modifying


Sent: event({
    _operator: indexed(address), # Address which triggered the send.
    _from: indexed(address),     # Token holder.
    _to: indexed(address),       # Token recipient.
    _amount: uint256,            # Number of tokens to send.
    _data: bytes[256],           # Information provided by the token holder.
    _operatorData: bytes[256]    # Information provided by the operator.
})

Minted: event({
    _operator: indexed(address), # Address which triggered the mint.
    _to: indexed(address),       # Recipient of the tokens.
    _amount: uint256,            # Number of tokens minted.
    _data: bytes[256],           # Information provided for the recipient.
    _operatorData: bytes[256]    # Information provided by the operator.
})

Burned: event({
    _operator: indexed(address), # Address which triggered the burn.
    _from: indexed(address),     # Token holder whose tokens are burned.
    _amount: uint256,            # Token holder whose tokens are burned.
    _data: bytes[256],           # Information provided by the token holder.
    _operatorData: bytes[256]    # Information provided by the operator.
})

AuthorizedOperator: event({
    _operator: indexed(address), # Address which became an operator of tokenHolder.
    _holder: indexed(address)    # Address of a token holder which authorized the operator address as an operator.
})

RevokedOperator: event({
    _operator: indexed(address), # Address which was revoked as an operator of tokenHolder.
    _holder: indexed(address)    # Address of a token holder which revoked the operator address as an operator.
})


erc1820Registry: ERC1820Registry
erc1820RegistryAddress: constant(address) = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24

# TODO: decide which size to use
NO_OF_DEFAULT_OPERATORS: constant(uint256) = 5
MAX_LENGTH_NAME: constant(uint256) = 64
MAX_LENGTH_SYMBOL: constant(uint256) = 32

name: public(string[MAX_LENGTH_NAME])
symbol: public(string[MAX_LENGTH_SYMBOL])

totalSupply: public(uint256)
granularity: public(uint256)

balanceOf: public(map(address, uint256))

defaultOperatorsList: address[NO_OF_DEFAULT_OPERATORS]
defaultOperatorsMap: map(address, bool)

operators: map(address, map(address, bool))


@public
def __init__(
    _name: string[MAX_LENGTH_NAME],
    _symbol: string[MAX_LENGTH_SYMBOL],
    _totalSupply: uint256,
    _granularity: uint256,
    _defaultOperators: address[NO_OF_DEFAULT_OPERATORS]
  ):
    self.name = _name
    self.symbol = _symbol
    self.totalSupply = _totalSupply
    # The granularity value MUST be greater than or equal to 1
    assert _granularity >= 1
    self.granularity = _granularity
    self.defaultOperatorsList = _defaultOperators
    for i in range(NO_OF_DEFAULT_OPERATORS):
        assert _defaultOperators[i] != ZERO_ADDRESS
        self.defaultOperatorsMap[_defaultOperators[i]] = True
    self.erc1820Registry = ERC1820Registry(erc1820RegistryAddress)
    self.erc1820Registry.setInterfaceImplementer(self, keccak256("ERC777Token"), self)


@private
def _checkForERC777TokensInterface_Sender(
    _operator: address,
    _from: address,
    _to: address,
    _amount: uint256,
    _data: bytes[256]="",
    _operatorData: bytes[256]=""
  ):
    implementer: address = self.erc1820Registry.getInterfaceImplementer(_from, keccak256("ERC777TokensSender"))
    if implementer != ZERO_ADDRESS:
        ERC777TokensSender(_from).tokensToSend(_operator, _from, _to, _amount, _data, _operatorData)


@private
def _checkForERC777TokensInterface_Recipient(
    _operator: address,
    _from: address,
    _to: address,
    _amount: uint256,
    _data: bytes[256]="",
    _operatorData: bytes[256]=""
  ):
    implementer: address = self.erc1820Registry.getInterfaceImplementer(_to, keccak256("ERC777TokensRecipient"))
    if implementer != ZERO_ADDRESS:
        ERC777TokensRecipient(_to).tokensReceived(_operator, _from, _to, _amount, _data, _operatorData)


@private
def _transferFunds(
    _operator: address,
    _from: address,
    _to: address,
    _amount: uint256,
    _data: bytes[256]="",
    _operatorData: bytes[256]=""
  ):
    # any minting, sending or burning of tokens MUST be a multiple of the granularity value.
    assert _amount % self.granularity == 0

    # check for 'tokensToSend' hook
    if _from.is_contract:
        self._checkForERC777TokensInterface_Sender(_operator, _from, _to, _amount, _data, _operatorData)

    self.balanceOf[_from] -= _amount
    self.balanceOf[_to] += _amount

    # check for 'tokensReceived' hook
    # but only if transfer is not a burn
    if _to != ZERO_ADDRESS:
        if _to.is_contract:
            self._checkForERC777TokensInterface_Recipient(_operator, _from, _to, _amount, _data, _operatorData)


@public
@constant
def defaultOperators() -> address[NO_OF_DEFAULT_OPERATORS]:
    return self.defaultOperatorsList


@public
@constant
def isOperatorFor(_operator: address, _holder: address) -> bool:
    return (self.operators[_holder])[_operator] or self.defaultOperatorsMap[_operator] or _operator == _holder


@public
def authorizeOperator(_operator: address):
    (self.operators[msg.sender])[_operator] = True
    log.AuthorizedOperator(_operator, msg.sender)


@public
def revokeOperator(_operator: address):
    # MUST revert if it is called to revoke the holder as an operator for itself
    assert _operator != msg.sender
    (self.operators[msg.sender])[_operator] = False
    log.RevokedOperator(_operator, msg.sender)


@public
def send(_to: address, _amount: uint256, _data: bytes[256]=""):
    assert _to != ZERO_ADDRESS
    operatorData: bytes[256]=""
    self._transferFunds(msg.sender, msg.sender, _to, _amount, _data, operatorData)
    log.Sent(msg.sender, msg.sender, _to, _amount, _data, operatorData)


@public
def operatorSend(
    _from: address,
    _to: address,
    _amount: uint256,
    _data: bytes[256]="",
    _operatorData: bytes[256]=""
  ):
    assert _to != ZERO_ADDRESS
    assert self.isOperatorFor(msg.sender, _from)
    self._transferFunds(msg.sender, _from, _to, _amount, _data, _operatorData)
    log.Sent(msg.sender, _from, _to, _amount, _data, _operatorData)


@public
def burn(_amount: uint256, _data: bytes[256]=""):
    operatorData: bytes[256]=""
    self._transferFunds(msg.sender, msg.sender, ZERO_ADDRESS, _amount, _data, operatorData)
    self.totalSupply -= _amount
    log.Burned(msg.sender, msg.sender, _amount, _data, operatorData)


@public
def operatorBurn(
    _from: address,
    _amount: uint256,
    _data: bytes[256]="",
    _operatorData: bytes[256]=""
  ):
    # _from: Token holder whose tokens will be burned (or 0x0 to set from to msg.sender).
    fromAddress: address
    if _from == ZERO_ADDRESS:
        fromAddress = msg.sender
    else:
        fromAddress = _from
    assert self.isOperatorFor(msg.sender, fromAddress)
    self._transferFunds(msg.sender, fromAddress, ZERO_ADDRESS, _amount, _data, _operatorData)
    self.totalSupply -= _amount
    log.Burned(msg.sender, fromAddress, _amount, _data, _operatorData)


# NOTE: ERC777 intentionally does not define specific functions to mint tokens.
@public
def mint(
    _to: address,
    _amount: uint256,
    _operatorData: bytes[256]=""
  ):
    assert _to != ZERO_ADDRESS
    # any minting, sending or burning of tokens MUST be a multiple of the granularity value.
    assert _amount % self.granularity == 0
    # only operators are allowed to mint
    assert self.defaultOperatorsMap[msg.sender]
    self.balanceOf[_to] += _amount
    self.totalSupply += _amount
    data: bytes[256]=""
    if _to.is_contract:
        self._checkForERC777TokensInterface_Recipient(msg.sender, ZERO_ADDRESS, _to, _amount, data, _operatorData)
    log.Minted(msg.sender, _to, _amount, data, _operatorData)
