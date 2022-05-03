# @version ^0.3.3
# @dev Implementation of Ownable.
# Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol


# @dev The owner address
owner: public(address)


# @dev This emits when the ownership of the contract is transfered
# @param previousOwner The previous owner address
# @param newOwner The new owner address
event OwnershipTransferred:
    previousOwner: indexed(address)
    newOwner: indexed(address)


# @dev Initialization of the contract. It sets the deployer as the new owner.
@external
def __init__():
    self.owner = msg.sender
    log OwnershipTransferred(ZERO_ADDRESS, self.owner)


# @dev Throws if called by any account other than the owner.
@internal
def onlyOwner():
    assert msg.sender == self.owner, "Only owner allowed."

    
@internal
def _transferOwnership(newOwner: address):
    oldOwner: address = self.owner
    self.owner = newOwner
    log OwnershipTransferred(oldOwner, newOwner)


# @dev Leaves the contract without owner. Methods with onlyOwner will not be callable anymore.
@external
def renounceOwnership():
    self.onlyOwner()
    self._transferOwnership(ZERO_ADDRESS)


# @dev Transfer the ownership to the new owner
@external
def transferOwnership(newOwner: address):
    self.onlyOwner()
    assert newOwner != ZERO_ADDRESS, "New owner cannot be the zero address."
    self._transferOwnership(newOwner)
