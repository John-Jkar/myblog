+++
title = "AAAAAAAAEEEEEEEESSSSSSSS - CTF Writeup"
date = 2026-02-15T06:00:00Z
draft = false
tags = ["crypto", "aes", "ecb", "oracle attack", "ctf"]
categories = ["CTF Writeups"]
+++
# AAAAAAAAEEEEEEEESSSSSSSS - Alpacahack challenge writeup

**Category:** Crypto  
**Difficulty:** Medium  
**Solves:** 21  
**Author:** hiikunz

## Challenge Description

We're given a Python script that encrypts a flag using AES-ECB mode with a twist - each character of the flag is repeated 8 times before encryption. We can also query an encryption oracle with arbitrary plaintexts.

```python
for c in flag:
    ffffffffllllllllaaaaaaaagggggggg += bytes([c] * 8)
ciphertext = cipher.encrypt(ffffffffllllllllaaaaaaaagggggggg)

```

## Initial Analysis

Let's break down what the code does:

1.  **Flag format**: 32 bytes total, format `Alpaca{...}`
2.  **Character repetition**: Each character is repeated 8 times
3.  **Total plaintext**: 32 characters × 8 repetitions = 256 bytes
4.  **Encryption**: AES-ECB mode (Electronic Codebook)
5.  **Blocks**: 256 bytes ÷ 16 bytes per block = 16 blocks

### Understanding the Encoding

If the flag is `Alpaca{test_flag_here______}`, the plaintext becomes:

```
AAAAAAAALLLLLLLLPPPPPPPPAAAAAAAA...

```

Where each character appears 8 times consecutively.

### Block Structure

Since AES uses 16-byte blocks and each character occupies 8 bytes:

```
Block 0 (bytes 0-15):   flag[0]*8 + flag[1]*8   = "AAAAAAAA" + "LLLLLLLL"
Block 1 (bytes 16-31):  flag[2]*8 + flag[3]*8   = "PPPPPPPP" + "AAAAAAAA"
Block 2 (bytes 32-47):  flag[4]*8 + flag[5]*8   = "CCCCCCCC" + "AAAAAAAA"
...
Block 15 (bytes 240-255): flag[30]*8 + flag[31]*8

```

Each block contains exactly 2 flag characters!

## The Vulnerability: ECB Mode

AES-ECB has a critical weakness: **identical plaintext blocks always produce identical ciphertext blocks**.

Since we can query the encryption oracle with any plaintext, we can:

1.  Create test plaintexts with the same structure (character repeated 8 times + character repeated 8 times)
2.  Send them to the oracle
3.  Compare the resulting ciphertext with the leaked ciphertext
4.  When they match, we've found those 2 characters!

## Attack Strategy

For each of the 16 blocks:

1.  Extract the target ciphertext block from the leaked data
2.  Try all possible pairs of characters from the charset (60 characters)
3.  For each pair `(c1, c2)`:
    -   Create plaintext: `c1*8 + c2*8` (16 bytes total)
    -   Send to oracle and get ciphertext
    -   Compare with target block
4.  When match found → we've recovered 2 flag characters!

### Complexity

-   Charset size: 60 characters (`A-Z`, `a-z`, `{`, `}`, `_`)
-   Combinations per block: 60 × 60 = 3,600
-   Total blocks: 16
-   **Worst case queries**: 16 × 3,600 = 57,600

This is completely feasible!

## Solution Code

```python
#!/usr/bin/env python3
import socket

# Flag charset
flag_charset = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz{}_"

HOST = "34.170.146.252"
PORT = 50373

def recv_until(sock, delimiter):
    """Receive data until delimiter is found"""
    data = b""
    while delimiter not in data:
        chunk = sock.recv(1)
        if not chunk:
            break
        data += chunk
    return data

def send_query(sock, plaintext_bytes):
    """Send a plaintext query and get the ciphertext response"""
    query = plaintext_bytes.hex() + "\n"
    sock.sendall(query.encode())
    
    # Receive response
    response = recv_until(sock, b"\n")
    hex_part = response.decode().split("ciphertext(hex): ")[1].strip()
    return bytes.fromhex(hex_part)

def main():
    # Connect to the server
    print(f"[*] Connecting to {HOST}:{PORT}...")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))
    print("[+] Connected!")
    
    # Receive the leaked ciphertext
    recv_until(sock, b"ciphertext(hex): ")
    leaked_line = recv_until(sock, b"\n")
    leaked_ct_hex = leaked_line.decode().strip()
    leaked_ct = bytes.fromhex(leaked_ct_hex)
    
    print(f"[*] Leaked ciphertext: {leaked_ct_hex[:64]}...")
    print(f"[*] Starting attack...\n")
    
    # Wait for prompt
    recv_until(sock, b"plaintext to encrypt (hex): ")
    
    flag = bytearray(32)
    
    # Recover flag 2 characters at a time
    for block_idx in range(16):
        print(f"[*] Block {block_idx:2d}/16...", end=' ', flush=True)
        
        target_block = leaked_ct[block_idx * 16:(block_idx + 1) * 16]
        
        found = False
        query_count = 0
        
        for c1 in flag_charset:
            if found:
                break
            for c2 in flag_charset:
                query_count += 1
                
                # Create test plaintext: c1*8 + c2*8
                test_plaintext = bytes([c1] * 8 + [c2] * 8)
                
                # Query oracle
                test_ct = send_query(sock, test_plaintext)
                
                if test_ct == target_block:
                    flag[2*block_idx] = c1
                    flag[2*block_idx + 1] = c2
                    print(f"'{chr(c1)}{chr(c2)}' ({query_count} queries)")
                    found = True
                    break
        
        if not found:
            print(f"NOT FOUND!")
            break
    
    sock.close()
    
    print(f"\n{'='*60}")
    print(f"[+] FLAG: {flag.decode()}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()

```

## Running the Exploit

```bash
$ python3 solve.py
[*] Connecting to 34.170.146.252:50373...
[+] Connected!
[*] Leaked ciphertext: dbbf7c0ea989bd5af7f153f7b101f64b...
[*] Starting attack...

[*] Block  0/16... 'Al' (156 queries)
[*] Block  1/16... 'pa' (289 queries)
[*] Block  2/16... 'ca' (98 queries)
[*] Block  3/16... '{E' (412 queries)
[*] Block  4/16... 'CB' (234 queries)
[*] Block  5/16... '_m' (567 queries)
...

============================================================
[+] FLAG: Alpaca{ECB_m0d3_l3aks_pl41nt3xt} (fake flag)
============================================================

```

## Key Takeaways

### Why ECB Mode is Dangerous

1.  **Deterministic**: Same plaintext → same ciphertext
2.  **No diffusion**: Each block is encrypted independently
3.  **Pattern leakage**: Repeated patterns in plaintext are visible in ciphertext

### What Made This Attack Possible

1.  **Character repetition**: Creates a predictable structure
2.  **ECB mode**: No randomization between blocks
3.  **Encryption oracle**: Allows us to test arbitrary plaintexts
4.  **Known charset**: Limited search space (60 characters)

### Real-World Implications

-   **Never use ECB mode** for anything beyond simple key wrapping
-   Always use authenticated encryption (GCM, ChaCha20-Poly1305)
-   This attack works even without knowing the key!
-   Visual example: The famous [ECB penguin](https://blog.filippo.io/the-ecb-penguin/)

## Flag

```
Alpaca{ECB_m0d3_l3aks_pl41nt3xt} (fake flag)

```

----------
