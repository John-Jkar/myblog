
+++
title = "Daily Alpacahack - XOR (Crypto / Easy) Writeup"
date = 2026-03-12T00:00:00Z
draft = false
tags = ["crypto", "xor", "ctf"]
categories = ["CTF Writeups"]
+++

# Daily Alpacahack Writeup: XOR (Crypto / Easy) 
**Category:** Crypto  
**Difficulty:** Easy  
## Challenge Description

We're given a Python encryption script and a ciphertext hex string.

```python
import os
import secrets
import string
from itertools import cycle

flag = os.getenv("FLAG", "Alpaca{FAKEFAKEFAKEFAKE}").encode()
assert flag.startswith(b"Alpaca{")

# key = b"???????", e.g, abcdefg
key = b"".join(secrets.choice(string.ascii_letters).encode() for _ in range(7))
assert len(key) == 7

c = bytes([c1 ^ c2 for c1, c2 in zip(flag, cycle(key))])
print(c.hex())

```

**Ciphertext:**

```
031b13072d280a2c1816392f3b041d07020d2f1619232817153b24141d000c3925281a3704161b

```
## Analysis

The encryption scheme is a **repeating-key XOR cipher**:

-   A random 7-byte key is generated using `secrets.choice(string.ascii_letters)`
-   The flag is XOR'd against the key, repeating the key cyclically with `itertools.cycle`

XOR has the useful property:

```
A ^ B = C  →  C ^ A = B

```

So if we know both the ciphertext and the original plaintext, we can recover the key:

```
key = ciphertext ^ plaintext

```

----------

## Exploit: Known-Plaintext Attack

We know the flag format is `Alpaca{...}`, meaning the first 7 bytes of the plaintext are always `Alpaca{`.

Crucially, **7 bytes = exactly the key length**. This means the first 7 bytes of ciphertext were encrypted with exactly one full cycle of the key — giving us a direct, clean recovery.


**Recovered key: `BwcfNIq`**
## Solve Script

```python
from itertools import cycle

ciphertext = bytes.fromhex("031b13072d280a2c1816392f3b041d07020d2f1619232817153b24141d000c3925281a3704161b")
known = b"Alpaca{"

# XOR known plaintext prefix against ciphertext to recover key
key = bytes([c ^ p for c, p in zip(ciphertext, known)])

# Decrypt full ciphertext with recovered key
flag = bytes([c ^ k for c, k in zip(ciphertext, cycle(key))])

print(f"Key:  {key}")
print(f"Flag: {flag.decode()}")

```

**Output:**

```
Key:  b'BwcfNIq'
Flag: Alpaca{nou_aru_paka_ha_tsume_wo_kakusu}

```

## Flag

```
Alpaca{nou_aru_paka_ha_tsume_wo_kakusu}

```
## Takeaway

This challenge demonstrates a **known-plaintext attack** against a repeating-key XOR cipher.

The attack works because:

1.  We know the flag prefix `Alpaca{` — 7 bytes of plaintext
2.  The key is exactly 7 bytes long
3.  XOR-ing the known plaintext with the ciphertext directly reveals the full key
4.  With the full key, decrypting the rest of the flag is trivial

The flag itself is a play on the Japanese proverb **能ある鷹は爪を隠す** (_"A capable hawk hides its talons"_), with "taka" (hawk) replaced by "paka" (alpaca) — a nod to the CTF's theme.