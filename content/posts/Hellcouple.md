
# HellCouple Aplacahack challenge writeup

## Topic: Discrete Logarithm
The challenge implements a standard Diffie-Hellman key exchange using the 1536-bit MODP group from RFC 3526.

### Relevant parameters:

- Prime: 1536-bit safe prime p

- Generator: g = 2

- Public values:

- alice_public

- bob_public

- Leakage:

- leak = alice_private & (2^1500 - 1)

#### The encrypted flag was produced using:

- SHA256(shared_key) as AES key

- AES in CTR mode

##### Vulnerability

##### Alice’s private key is generated as:
**alice_private = random value < p**
##### But the challenge leaks:
**leak = alice_private mod 2^1500**

##### Since p is 1536 bits, this means:

- 1500 lower bits are known

- Only 36 upper bits are unknown

**So we can express:**
**alice_private = leak + k·2^1500**
##### Where:
**0 ≤ k < 2^36**
**Instead of brute-forcing a 1536-bit key, we only need to search a 36-bit space.**
##### That is:
**2^36 ≈ 68 billion possibilities**


**Too large for naive brute force — but small enough for Baby-Step Giant-Step.**

### Solve script

```python
import hashlib
from Crypto.Cipher import AES
from math import ceil, sqrt

# ---- Given values ----
p = 0xffffffffffffffffc90fdaa22168c234c4c6628b80dc1cd129024e088a67cc74020bbea63b139b22514a08798e3404ddef9519b3cd3a431b302b0a6df25f14374fe1356d6d51c245e485b576625e7ec6f44c42e9a637ed6b0bff5cb6f406b7edee386bfb5a899fa5ae9f24117c4b1fe649286651ece45b3dc2007cb8a163bf0598da48361c55d39a69163fa8fd24cf5f83655d23dca3ad961c62f356208552bb9ed529077096966d670c354e4abc9804f1746c08ca237327ffffffffffffffff
g = 2

alice_public = 1599718256377804952101531599498863772568230618694466120580310027783856775419774715324430490009702307955575844601185230178048816258775546297605599320433889688149788702236901234905522868569967416567225850806042222083340147485157993071805547560375509693951764934940304995906394917881355417525918023021173242172441340007873982292615475287840119272527822675409016385400712544820436845576792437659620501263257558269716031694407258972273378598219915938064730248662540644

bob_public = 1601509205497326911166665651407955633086809897508704527950455620720477838507803621126588237807460352033730891991811162559292107072226732941342412621198125808491110851607803610326932944231441277178997305795098725764729855265846212191447644979975042348063533857732774890088844866567954281331492269751048224888559719840307800593782696008426362668779570407212587612644451479819243906619852333855883749307751229874778873609891502901892234753096522217233589204630723331

leak = 18745015684416423248238358819116531099692322854758287583875043555248837262023679930415710097187512975438125769318401939978478358430852785607010460104247921522906629910012576819904488213243619895103769135299549586169221570769473234206574921382434244366730718275494665736161014808538417501350114510192342412033471326519013144824828968703748628325803878118375663318670612020895929494354336570752213975226257200515892803889402746161532447603042987169336605

encrypted_flag_hex = "fb2f1136cea7c67b1edba34d3741eeac8442e70924b03202352422a28237ee6f3fb6d493"
encrypted_flag = bytes.fromhex(encrypted_flag_hex)

# ---- Setup attack ----
p_2_1500 = 2**1500

h = pow(g, leak, p)
h_inv = pow(h, -1, p)

base = pow(g, p_2_1500, p)
target = (alice_public * h_inv) % p

# ---- Baby Step Giant Step ----
N = 2**36
m = ceil(sqrt(N))

print("[*] Building baby steps...")

baby_steps = {}
current = 1
for j in range(m):
    baby_steps[current] = j
    current = (current * base) % p

print("[*] Giant steps...")

factor = pow(base, -m, p)
gamma = target

k = None

for i in range(m):
    if gamma in baby_steps:
        k = i * m + baby_steps[gamma]
        print("[+] Found k:", k)
        break
    gamma = (gamma * factor) % p

if k is None:
    print("[-] Failed.")
    exit()

# ---- Recover private key ----
alice_private = leak + k * p_2_1500

# ---- Decrypt ----
shared_key = pow(bob_public, alice_private, p)
session_key = hashlib.sha256(
    shared_key.to_bytes(p.bit_length() // 8, "big")
).digest()

nonce = encrypted_flag[:8]
ciphertext = encrypted_flag[8:]

cipher = AES.new(session_key, AES.MODE_CTR, nonce=nonce)
flag = cipher.decrypt(ciphertext)

print("[+] FLAG:", flag.decode())

```
flag **Alpaca{1_hat3_c0u913s:fire:}**                                



