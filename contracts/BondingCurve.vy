# Simple Bonding Curve Contract in Vyper

from vyper.interfaces import ERC20

# Event for token purchases
Purchase: event({_from: indexed(address), _amount: uint256, _cost: uint256})

# Event for token sales
Sale: event({_from: indexed(address), _amount: uint256, _revenue: uint256})

collateral_token: ERC20

pool_balance: uint256
token_supply: uint256

# Contract owner
owner: address

@external
def __init__(collateral: address):
    self.collateral_token = ERC20(collateral)
    self.owner = msg.sender

@external
def buyTokens(amount: uint256) -> bool:
    assert amount > 0, "Amount must be greater than 0"

    # Calculate the cost based on the bonding curve formula
    cost = self.getBuyCost(amount)

    # Transfer collateral tokens from the buyer to the contract
    assert self.collateral_token.transferFrom(msg.sender, self, cost), "Collateral transfer failed"

    # Update the pool balance and token supply
    self.pool_balance += cost
    self.token_supply += amount

    # Emit the Purchase event
    log Purchase(msg.sender, amount, cost)

    return True

@external
def sellTokens(amount: uint256) -> bool:
    assert amount > 0, "Amount must be greater than 0"

    # Calculate the revenue based on the bonding curve formula
    revenue = self.getSellRevenue(amount)

    # Transfer collateral tokens from the contract to the seller
    assert self.collateral_token.transfer(msg.sender, revenue), "Collateral transfer failed"

    # Update the pool balance and token supply
    self.pool_balance -= revenue
    self.token_supply -= amount

    # Emit the Sale event
    log Sale(msg.sender, amount, revenue)

    return True

@view
def getBuyCost(amount: uint256) -> uint256:
    return (amount * (self.pool_balance + self.token_supply)) // self.token_supply

@view
def getSellRevenue(amount: uint256) -> uint256:
    return (amount * self.pool_balance) // self.token_supply

@view
def getCollateralToken() -> address:
    return self.collateral_token

@view
def getPoolBalance() -> uint256:
    return self.pool_balance

@view
def getTokenSupply() -> uint256:
    return self.token_supply
