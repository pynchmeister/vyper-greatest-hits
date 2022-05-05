# @title Simplified Vyper Dynamic Array for uint256 v1
# @notice Use at your own risk

MAXVAL: constant(uint256) = 2**255
ls: map(uint256, uint256)
currMax: public(uint256)

@public
@constant
def get(_idx: uint256) -> uint256:
    assert _idx < self.currMax
    return self.ls[_idx]

@public
@constant
def length() -> uint256:
    return self.currMax

@public
def set(_idx: uint256, _val: uint256):
    self.ls[_idx] = _val

@public
def append(_val: uint256):
    self.set(self.currMax, _val)
    self.currMax += 1

@public
def detach():
    assert self.currMax > 0
    self.currMax -= 1

@public
def remove(_idx: uint256):
    assert self.currMax > 0
    assert self.currMax > _idx
    i: uint256
    for not_i in range(MAXVAL):
        i = convert(not_i, uint256)
        if i == self.currMax - 1:
            self.currMax -= 1
            return
        elif i >= _idx and i < self.currMax - 1:
            self.set(i, self.get(i + 1))
