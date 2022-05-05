# @title Vyper Dynamic Array for strings v1
# @notice Use at your own risk

# Events
ListReserved: event({list_id: indexed(uint256), owner: indexed(address)})
ValueChanged: event({list_id: indexed(uint256), idx: indexed(uint256), val: indexed(string[100])})

# Globals
maxLs: public(uint256)
lists: map(uint256, map(uint256, string[100]))
owners: map(uint256, address)
currMaxes: map(uint256, uint256)
created: public(bool)

# Public Functions

@public
def __init__():
    self.created = True

@public
def reserveList() -> uint256:
    self.owners[self.maxLs] = msg.sender
    log.ListReserved(self.maxLs, msg.sender)
    self.maxLs += 1
    return self.maxLs

@public
@constant
def get(_ls: uint256, _idx: uint256) -> string[100]:
    assert _idx < self.currMaxes[_ls]
    return self.lists[_ls][_idx]

@public
@constant
def length(_ls: uint256) -> uint256:
    return self.currMaxes[_ls]

@private
def _set(_ls: uint256, _idx: uint256, _val: string[100], _sender: address):
    assert self.owners[_ls] == _sender
    assert _idx <= self.currMaxes[_ls]
    self.lists[_ls][_idx] = _val
    log.ValueChanged(_ls, _idx, _val)

@public
def set(_ls: uint256, _idx: uint256, _val: string[100]):
    self._set(_ls, _idx, _val, msg.sender)

@public
def append(_ls: uint256, _val: string[100]):
    self._set(_ls, self.currMaxes[_ls], _val, msg.sender)
    self.currMaxes[_ls] += 1

@public
def detach(_ls: uint256):
    assert self.owners[_ls] == msg.sender
    assert self.currMaxes[_ls] > 0
    self.currMaxes[_ls] -= 1

@public
def remove(_ls: uint256, _idx: uint256):
    assert self.currMaxes[_ls] > 0
    assert self.currMaxes[_ls] > _idx
    i: uint256
    for not_i in range(MAX_UINT256):
        i = convert(not_i, uint256)
        if i == self.currMaxes[_ls]:
            self.currMaxes[_ls] -= 1
            return
        elif i >= _idx and i < self.currMaxes[_ls] - 1:
            self._set(_ls, i, self.get(_ls, i + 1), msg.sender)
