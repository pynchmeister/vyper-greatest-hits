# @version 0.2.8
# @notice A wrapper for Lido stETH which follows Yearn Vault conventions
from vyper.interfaces import ERC20

implements: ERC20


interface Lido:
    def getPooledEthByShares(_sharesAmount: uint256) -> uint256: view
    def getSharesByPooledEth(_pooledEthAmount: uint256) -> uint256: view
    def submit(referral: address) -> uint256: payable


event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256


event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256


name: public(String[26])
symbol: public(String[7])
decimals: public(uint256)
version: public(String[1])

balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
totalSupply: public(uint256)

nonces: public(HashMap[address, uint256])
DOMAIN_SEPARATOR: public(bytes32)
DOMAIN_TYPE_HASH: constant(bytes32) = keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
PERMIT_TYPE_HASH: constant(bytes32) = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")

steth: constant(address) = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
patron: constant(address) = 0x55Bc991b2edF3DDb4c520B222bE4F378418ff0fA


@external
def __init__():
    self.name = 'Yearn Lido St. Ether Vault'
    self.symbol = 'yvstETH'
    self.decimals = 18
    self.version = '1'
    self.DOMAIN_SEPARATOR = keccak256(
        concat(
            DOMAIN_TYPE_HASH,
            keccak256(convert(self.name, Bytes[26])),
            keccak256(convert(self.version, Bytes[1])),
            convert(chain.id, bytes32),
            convert(self, bytes32)
        )
    )


@internal
def _mint(owner: address, amount: uint256):
    self.totalSupply += amount
    self.balanceOf[owner] += amount
    log Transfer(ZERO_ADDRESS, owner, amount)


@internal
def _burn(owner: address, amount: uint256):
    self.totalSupply -= amount
    self.balanceOf[owner] -= amount
    log Transfer(owner, ZERO_ADDRESS, amount)


@payable
@external
def __default__():
    """
    @notice Submit ether to Lido and deposit the received stETH into the Vault.
    """
    shares: uint256 = Lido(steth).submit(patron, value=msg.value)
    self._mint(msg.sender, shares)


@external
def deposit(_tokens: uint256 = MAX_UINT256, recipient: address = msg.sender) -> uint256:
    """
    @notice Deposit stETH tokens into the Vault
    @dev
        A user must have approved the contract to spend stETH.
    @param _tokens The amount of stETH tokens to deposit
    @param recipient The account to credit with the minted shares
    @return The amount of minted shares
    """
    tokens: uint256 = min(_tokens, ERC20(steth).balanceOf(msg.sender))
    shares: uint256 = Lido(steth).getSharesByPooledEth(tokens)
    self._mint(recipient, shares)
    assert ERC20(steth).transferFrom(msg.sender, self, tokens)
    return shares


@external
def withdraw(_shares: uint256 = MAX_UINT256, recipient: address = msg.sender) -> uint256:
    """
    @notice Withdraw stETH tokens from the Vault
    @param _shares The amount of shares to burn for stETH
    @param recipient The account to credit with stETH
    @return The amount of withdrawn stETH
    """
    shares: uint256 = min(_shares, self.balanceOf[msg.sender])
    tokens: uint256 = Lido(steth).getPooledEthByShares(shares)
    self._burn(msg.sender, shares)
    assert ERC20(steth).transfer(recipient, tokens)
    return tokens


@view
@external
def pricePerShare() -> uint256:
    """
    @notice Get the vault share to stETH ratio
    @return The value of a single share
    """
    return Lido(steth).getPooledEthByShares(10 ** self.decimals)


@internal
def _transfer(sender: address, receiver: address, amount: uint256):
    assert receiver not in [self, ZERO_ADDRESS]
    self.balanceOf[sender] -= amount
    self.balanceOf[receiver] += amount
    log Transfer(sender, receiver, amount)


@external
def transfer(receiver: address, amount: uint256) -> bool:
    self._transfer(msg.sender, receiver, amount)
    return True


@external
def transferFrom(sender: address, receiver: address, amount: uint256) -> bool:
    if msg.sender != sender and self.allowance[sender][msg.sender] != MAX_UINT256:
        self.allowance[sender][msg.sender] -= amount
        log Approval(sender, msg.sender, self.allowance[sender][msg.sender])
    self._transfer(sender, receiver, amount)
    return True


@external
def approve(spender: address, amount: uint256) -> bool:
    self.allowance[msg.sender][spender] = amount
    log Approval(msg.sender, spender, amount)
    return True


@external
def permit(owner: address, spender: address, amount: uint256, expiry: uint256, signature: Bytes[65]) -> bool:
    assert owner != ZERO_ADDRESS  # dev: invalid owner
    assert expiry == 0 or expiry >= block.timestamp  # dev: permit expired
    nonce: uint256 = self.nonces[owner]
    digest: bytes32 = keccak256(
        concat(
            b'\x19\x01',
            self.DOMAIN_SEPARATOR,
            keccak256(
                concat(
                    PERMIT_TYPE_HASH,
                    convert(owner, bytes32),
                    convert(spender, bytes32),
                    convert(amount, bytes32),
                    convert(nonce, bytes32),
                    convert(expiry, bytes32),
                )
            )
        )
    )
    # NOTE: the signature is packed as r, s, v
    r: uint256 = convert(slice(signature, 0, 32), uint256)
    s: uint256 = convert(slice(signature, 32, 32), uint256)
    v: uint256 = convert(slice(signature, 64, 1), uint256)
    assert ecrecover(digest, v, r, s) == owner  # dev: invalid signature
    self.allowance[owner][spender] = amount
    self.nonces[owner] = nonce + 1
    log Approval(owner, spender, amount)
    return True
