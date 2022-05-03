from vyper.interfaces import ERC20
from interfaces import (ETHFlash, ERC20Flash)

malicious: bool
token: address

@public
def __init__(_malicious: bool, _token: address):
    self.malicious = _malicious
    self.token = _token

@public
@payable
def __default__():
    pass

@public
def ethDeFi(loan: uint256(wei), interest: uint256(wei)):
    to_return: uint256(wei) = loan + interest
    assert self.balance >= to_return
    if (not self.malicious):
        ETHFlash(msg.sender).returnLoan(value=to_return)

@public
def erc20DeFi(loan: uint256, interest: uint256):
    to_return: uint256 = loan + interest
    assert ERC20(self.token).balanceOf(self) >= to_return
    if (not self.malicious):
        ERC20(self.token).transfer(msg.sender, to_return)

@public
def flash_loan_eth(eth_flash: address, amount: uint256(wei)):
    ETHFlash(eth_flash).flash(amount)

@public
def flash_loan_erc20(erc20_flash: address, amount: uint256):
    ERC20Flash(erc20_flash).flash(amount)
