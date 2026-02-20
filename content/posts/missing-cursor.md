+++
title = "Dancing Cursor - Daily Alpacahack Writeup"
date = 2026-02-20T06:00:00Z
draft = false
tags = ["ctf", "ansi", "escape sequences", "terminal", "misc", "rev"]
categories = ["CTF Writeups"]
+++
# Dancing Cursor — Daily  Alpacahack Writeup

**Challenge:** Dancing Cursor  
**Category:** Rev / Misc  
**Difficulty:** Medium  


## The Challenge

We're handed a single command:

```bash
echo SGVyZSBpcyB0aGUgZmxhZzo... | base64 -d

```

Running it in a terminal flashes the message:

```
Here is the flag:
Xiqxox{==============================================}
... but it has been wiped away.

```

Clearly `Xiqxox{===}` is a decoy. The real flag was written and then erased before we could see it.



## Understanding the Trick

Decoding the base64 gives raw bytes that are mostly **ANSI terminal escape sequences**. The structure is:

1.  Print `Here is the flag:\n`
2.  `\x1b[?1049h` — switch to the **alternate screen buffer**
3.  Use cursor movement codes to write the real flag scattered across rows 1–3
4.  Use `\x1b[K]` (**erase to end of line**) to wipe those rows
5.  Write the fake flag `Xiqxox{===}` over the blank space
6.  `\x1b[?1049l` — switch back to the normal screen

Because everything happens in the alternate screen faster than the eye can follow, and the erase fires before control returns to us, the terminal only ever shows the decoy.

The relevant escape codes are:

Sequence

Effect

`\x1b[?1049h` / `\x1b[?1049l`

Enter / leave alternate screen

`\x1b[NA` / `\x1b[NB`

Cursor up / down N rows

`\x1b[NC` / `\x1b[ND`

Cursor right / left N columns

`\x1b[38;5;Nm`

Set foreground colour (decorative noise)

`\x1b[K`

**Erase from cursor to end of line** ← the weapon


## The Solution

Rather than running the command live, we **simulate the terminal in Python** — maintaining a 2D character grid and replaying every escape sequence. The critical insight is to **snapshot the grid before each `\x1b[K]` fires**.

```python
elif cmd == 'K':
    print_grid("SNAPSHOT — before erase")   # ← flag is visible here
    for c in range(col, WIDTH):             # then actually erase
        grid[row][c] = ' '

```

Running the simulator:

```bash
echo SGVyZSBpcyB0aGUgZmxhZzo... | base64 -d | python3 dancing_cursor_sim.py

```

The first snapshot, taken before row 1 is erased, shows:

```
row  0: [Here is the flag:]
row  1: [Alpaca{Control_sESCuences_sh0uld_b3_und3r_our_control}]
row  2: [ #   .   +   *   o   +   .   *   # ]
row  3: [ *   .   o   +   *   o   +   #   * ]

```

Rows 2 and 3 are coloured noise — red herrings to make the grid look busier than it is. Row 1 is the flag.



## Flag

```
Alpaca{Control_sESCuences_sh0uld_b3_und3r_our_control}

```



## Key Takeaway

The challenge is a lesson in **trusting your terminal too much**. ANSI control sequences can write, move, and erase content faster than a human can perceive. The only reliable way to audit what a stream of escape codes actually does is to simulate or log every write before any erase — exactly what terminals themselves don't show you.