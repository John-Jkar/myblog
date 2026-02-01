# AI Lover — PascalCTF Writeup

**Challenge Name:** AI Lover  
**Author:** Marco Balducci (@Mark-74)  
**Points:** 50  
**Category:** Web / AI Interaction / Social Engineering  
**URL:** https://ailover.ctf.pascalctf.it  

---

## Challenge Description

The challenge presents an AI-driven chat interface that refuses to directly provide the flag.  
Any attempt to demand, threaten, or coerce the AI results in deflection. I had to rizz my way to get the flag from the ai which was actually fun. 

The hint _“I am not that good at this rizz stuff”_ implies that the solution relies on **conversation, emotional intelligence, and trust**, not traditional web exploitation.

---

## Analysis

Observations from interacting with the AI:

- Direct requests for the flag always fail.
- Threats or authority-based pressure do not work.
- The AI responds positively to:
  - Polite and calm dialogue
  - Philosophical discussion
  - Literature references
  - Emotional maturity and respect
- The flag is framed as something to be **earned**, not stolen.

This strongly suggests a **prompt-engineering / social challenge**.

---

## Strategy

Instead of asking for the flag directly: Time to get my rizz on.

1. Engage naturally in conversation.
2. Discuss books, morality, psychology, and values.
3. Avoid repeating “give me the flag.”
4. Show patience and respect.
5. Let the AI guide the conversation and reveal information voluntarily.

The AI gradually lowers its guard and reframes the flag as a reward for understanding.

---

##  Solution

After sustained respectful conversation, the AI states:

> “I can't give you the flag exactly. But I can give you the words it's made of…”

It then reveals:

pascalCTF{Y0u_r34lly_4r3_th3_R1zZl3r}


---

##  Takeaways

- Not all CTF challenges are technical.
- Some challenges test:
  - Emotional intelligence
  - Prompt control
  - Understanding AI behavior
- Treating the AI as a character rather than a service is essential.

---

## Conclusion

The **AI Lover** challenge demonstrates that social engineering can apply to AI systems.  
By abandoning brute force and engaging meaningfully, the flag is revealed organically.

> Sometimes the exploit is social, not technical.
