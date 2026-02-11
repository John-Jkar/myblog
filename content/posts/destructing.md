+++
title = "Destructuring Challenge Writeup"
date = 2026-02-11T08:00:00Z
draft = false
+++

# Destructuring Challenge Writeup

**Challenge:** destructuring  
**Category:** Misc  
**Difficulty:** Easy  
**Solves:** 57  
**Author:** ark  

## Challenge Description

"Introduction to modern JavaScript!"

The challenge provides a netcat connection:

nc 34.170.146.252 25646

## Initial Analysis

We're given a Node.js script that implements a 5-stage challenge. Each stage uses JavaScript destructuring to extract values from JSON input. Let's examine the code structure:

```javascript
const stages = [
  // Stage 0
  (json) => {
    const { a: _0, b: _1 } = json;
    return [_0, _1];
  },
  // ... more stages
];
```

The script:
1. Loops through each stage (0-4)
2. Prompts for JSON input with `json>`
3. Parses the JSON and applies the destructuring pattern
4. Checks if the result equals `[0, 1, 2, 3, ...]` (each value equals its index)
5. If all stages pass, reveals the flag from `process.env.FLAG`

## Understanding Destructuring

JavaScript destructuring allows extracting values from objects and arrays into variables. For example:

```javascript
// Object destructuring
const { a: x, b: y } = { a: 10, b: 20 };
// x = 10, y = 20

// Array destructuring
const [, , x, y] = [1, 2, 3, 4];
// x = 3, y = 4 (skips first two elements)

// Nested destructuring
const { a: [, x, { b: y }] } = { a: [1, 2, { b: 3 }] };
// x = 2, y = 3
```

## Solution Approach

For each stage, we need to construct JSON that places values `0, 1, 2, 3, ...` at the exact positions where the destructuring pattern expects them.

### Stage 0

**Pattern:**
```javascript
const { a: _0, b: _1 } = json;
```

**Analysis:**
- Extracts `json.a` into `_0` (should be 0)
- Extracts `json.b` into `_1` (should be 1)

**Solution:**
```json
{"a":0,"b":1}
```

### Stage 1

**Pattern:**
```javascript
const [, , _0, _1, _2, , , _3, _4] = json;
```

**Analysis:**
- Array destructuring with holes (commas skip elements)
- `_0 = json[2]` (should be 0)
- `_1 = json[3]` (should be 1)
- `_2 = json[4]` (should be 2)
- `_3 = json[7]` (should be 3)
- `_4 = json[8]` (should be 4)

**Solution:**
```json
[null,null,0,1,2,null,null,3,4]
```

### Stage 2

**Pattern:**
```javascript
const {a: [, , { b: _0, c: [{ d: _1 }] }] } = json;
```

**Analysis:**
- Nested object and array destructuring
- `_0 = json.a[2].b` (should be 0)
- `_1 = json.a[2].c[0].d` (should be 1)

**Solution:**
```json
{"a":[null,null,{"b":0,"c":[{"d":1}]}]}
```

### Stage 3

**Pattern:**
```javascript
const { a: { a: { a: { a: _0, b: _1 }, b: { a: _2, b: _3 }, c: [, _4, , _5, _6] }, b: [{ a: _7 }, [_8, _9, _10, , _11]] } } = json;
```

**Analysis:**
This extracts 12 values from a deeply nested structure:
- `_0 = json.a.a.a.a` → 0
- `_1 = json.a.a.a.b` → 1
- `_2 = json.a.a.b.a` → 2
- `_3 = json.a.a.b.b` → 3
- `_4 = json.a.a.c[1]` → 4
- `_5 = json.a.a.c[3]` → 5
- `_6 = json.a.a.c[4]` → 6
- `_7 = json.a.b[0].a` → 7
- `_8 = json.a.b[1][0]` → 8
- `_9 = json.a.b[1][1]` → 9
- `_10 = json.a.b[1][2]` → 10
- `_11 = json.a.b[1][4]` → 11

**Solution:**
```json
{"a":{"a":{"a":{"a":0,"b":1},"b":{"a":2,"b":3},"c":[null,4,null,5,6]},"b":[{"a":7},[8,9,10,null,11]]}}
```

### Stage 4

**Pattern:**
This is the most complex stage with **374 variables** (_0 through _373) extracted from an extremely deeply nested structure. The destructuring pattern spans multiple lines and includes:
- Nested objects 6-8 levels deep
- Arrays within objects within arrays
- Mixed array and object destructuring
- Holes in array destructuring (skipped elements)

**Strategy:**
Rather than manually parsing the entire pattern, I wrote a script to systematically build the JSON structure by:
1. Analyzing each variable assignment path
2. Creating the nested structure level by level
3. Placing each number (0-373) at its corresponding path

The resulting JSON is approximately 4KB in size due to the extreme nesting.

**Solution:**
See `stage4.json` file (too large to include in writeup inline)

## Building the Solution Script

I created a Node.js script to generate all the JSON inputs:

```javascript
// Stage 0
const stage0 = { a: 0, b: 1 };

// Stage 1
const stage1 = [null, null, 0, 1, 2, null, null, 3, 4];

// Stage 2
const stage2 = {
  a: [null, null, { b: 0, c: [{ d: 1 }] }]
};

// Stage 3
const stage3 = {
  a: {
    a: {
      a: { a: 0, b: 1 },
      b: { a: 2, b: 3 },
      c: [null, 4, null, 5, 6]
    },
    b: [
      { a: 7 },
      [8, 9, 10, null, 11]
    ]
  }
};

// Stage 4 - see full implementation
const stage4 = { /* very large nested structure */ };
```

## Exploitation

Connect to the challenge server:
```bash
nc 34.170.146.252 25646
```

For each `json>` prompt, paste the corresponding stage's JSON input:

```
Stage: 0
const { a: _0, b: _1 } = json;
json> {"a":0,"b":1}
Nice!

Stage: 1
const [, , _0, _1, _2, , , _3, _4] = json;
json> [null,null,0,1,2,null,null,3,4]
Nice!

Stage: 2
const {a: [, , { b: _0, c: [{ d: _1 }] }] } = json;
json> {"a":[null,null,{"b":0,"c":[{"d":1}]}]}
Nice!

Stage: 3
const { a: { a: { a: { a: _0, b: _1 }, ... } } } = json;
json> {"a":{"a":{"a":{"a":0,"b":1},"b":{"a":2,"b":3},"c":[null,4,null,5,6]},"b":[{"a":7},[8,9,10,null,11]]}}
Nice!

Stage: 4
const { a: [{ a: { a: { a: [{ a: _0, ... } } } }] } = json;
json> [paste stage4.json contents]
Nice!

Here's your flag: [FLAG]
```

## Key Takeaways

1. **JavaScript Destructuring**: This challenge provides excellent practice with JavaScript's destructuring syntax, including:
   - Object destructuring with renaming
   - Array destructuring with holes
   - Nested destructuring patterns
   - Mixed object/array destructuring

2. **Pattern Matching**: The challenge requires careful analysis of nested patterns to determine the exact path to each variable.

3. **Automation**: For complex stages (especially Stage 4), automation is essential. Manually constructing 374-variable destructuring would be error-prone and time-consuming.

4. **JSON Structure**: Understanding how JavaScript destructuring maps to JSON structure is crucial - objects use `{}` and properties, arrays use `[]` and indices.

## Files

- `stage0.json` - Stage 0 input
- `stage1.json` - Stage 1 input
- `stage2.json` - Stage 2 input
- `stage3.json` - Stage 3 input
- `stage4.json` - Stage 4 input (4KB file)
- `solve.js` - Script to generate all inputs
- `solution.md` - Quick reference guide

## Flag

After successfully completing all 5 stages, the server reveals the flag stored in the environment variable.