+++
title = "pyjs — CTF Writeup"
date = 2026-03-02T00:00:00Z
draft = false
tags = ["misc", "polyglot", "pyjs", "ctf"]
categories = ["CTF Writeups"]
+++

# pyjs — Daily Alpacahack Writeup

**CTF**: AlpacaHack / SECCON  
**Category**: Misc  
**Difficulty**: Hard  
**Author**: minaminao


## Challenge

We connect to a server running this code:

```python
import subprocess
code = input("Enter your code: ")
res1 = subprocess.run(["runuser", "-u", "nobody", "--", "python3", "-c", code], capture_output=True)
assert res1.returncode == 0 and res1.stdout.strip() == b"I LOVE ALPACA"
res2 = subprocess.run(["runuser", "-u", "nobody", "--", "node", "-e", code], capture_output=True)
assert res2.returncode == 0 and res2.stdout.strip() == b"I LOVE SECCON"
print("Wow... Alpaca{REDACTED}")
```

**Goal**: Submit a single line of code that prints `I LOVE ALPACA` when run as Python and `I LOVE SECCON` when run as Node.js.


## Solution

### Finding a Divergence Point

We need one expression that evaluates differently in Python vs JS. The key is the `in` operator with mixed types:

```
"0" in [1]

```

Runtime

Result

Reason

Python

`False`

String `"0"` is not in a list containing integer `1`

JS

`true`

`"0"` is a valid array index (JS coerces to check property keys)

This gives us a reliable boolean branch that diverges between the two runtimes.

### Converting Bool to Index

To use this as an array index, we multiply by `1`:

```
(('0'in[1]))*1

```

-   Python: `False * 1` → `0`
-   JS: `true * 1` → `1`

The extra parens around `('0'in[1])` are needed because Python's `in` operator has lower precedence than `*`, which would otherwise cause a `TypeError` trying to multiply a list.

### Comma Operator vs Tuple Pitfall

An early attempt used `(a, b)[index]`:

```python
# WRONG
eval(("print('I LOVE ALPACA')","console.log('I LOVE SECCON')")[(('0'in[1]))*1])

```

In Python, `("a", "b")` is a **tuple** — indexable as expected.  
In JS, `("a", "b")` is the **comma operator** — it evaluates both and returns the last value (`"b"`). Indexing into a string with `[1]` then gives a single character, and `eval`-ing that character throws a `ReferenceError`.

**Fix**: Use `[...]` — a list in Python, an array in JS — both support integer indexing correctly.

### Final Payload

```
eval(['print("I LOVE ALPACA")','console.log("I LOVE SECCON")'][(('0'in[1]))*1])

```

**Python execution:**

1.  `'0' in [1]` → `False`
2.  `False * 1` → `0`
3.  `[...][0]` → `'print("I LOVE ALPACA")'`
4.  `eval(...)` → prints `I LOVE ALPACA` ✓

**JS execution:**

1.  `'0' in [1]` → `true`
2.  `true * 1` → `1`
3.  `[...][1]` → `'console.log("I LOVE SECCON")'`
4.  `eval(...)` → prints `I LOVE SECCON` ✓

----------

## Flag

```
Alpaca{}

```


## Key Takeaways

-   **`in` operator divergence**: JS coerces array index lookups to strings, so `"0" in [1]` is `true` in JS but `False` in Python — a reliable polyglot branch point.
-   **Comma operator trap**: `(a, b)` means tuple in Python but comma operator in JS. Use `[a, b]` for cross-language indexable sequences.
-   **`eval` as a bridge**: Hiding language-specific syntax inside strings passed to `eval` lets you write code that's syntactically valid in both languages while executing different logic at runtime.