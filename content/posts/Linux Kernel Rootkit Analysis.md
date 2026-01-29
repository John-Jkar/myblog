---
title: "Linux Kernel Rootkit Analysis – Singularity Rootkit"
date: 2026-01-29
categories: [DFIR, Malware Analysis, Linux, Rootkits]
tags: [LKM, kernel, forensics, reverse engineering]
---

# 🔍 Linux Kernel Rootkit Analysis – Singularity Rootkit easy malops practice challenge

## Overview
Today I kicked off will some malware analysis from malops.io. It was my first time to analyse a rootkit and i twas very insightful.
In this blog Iam going to talk about my experience while analysing the rootkit
In this analysis, we examine a **Linux kernel rootkit** recovered during a DFIR investigation.  
The malicious kernel module demonstrates advanced stealth capabilities, including:

- Kernel module self‑hiding
- Process and port hiding
- Privilege escalation via a magic trigger
- Concealed C2 communication
- Anti‑forensics mechanisms

The sample (`singularity.ko`) was analyzed **statically** using **IDA Free / Cutter** on Kali Linux.

---

## Sample Information

| Field | Value |
|------|------|
| Filename | `singularity.ko` |
| Type | Linux Kernel Module (LKM) |
| Architecture | x86_64 |
| Analysis Tools | IDA Free, Cutter, strings, nm |

---

## Rootkit Initialization

### Primary Initialization Function

Although the kernel exports `init_module`, the rootkit redirects execution to its own initializer.

**Primary initialization function:**


# singularity_init 
This function orchestrates the setup of all malicious features.

---

## Feature Initialization Functions

Inside `singularity_init`, multiple **feature‑specific initialization routines** are invoked, including:

- Process hiding
- File and directory hiding
- TCP port hiding
- Privilege escalation
- Anti‑forensics cleanup
- Rootkit self‑hiding

Each feature is modularized and initialized independently.

---

## Anti‑Forensics: Kernel Thread Creation

The function responsible for clearing kernel taint flags and hiding forensic traces is:

# reset_tainted_init

### Kernel Thread Details

A kernel thread is created using `kthread_create_on_node`.

**Hardcoded thread name:**

# zer0t

The thread’s PID is immediately hidden to evade detection.

---

## Process Hiding Capability

The rootkit maintains an internal array for tracking hidden PIDs:

```c
int hidden_pids[32];
```
# Module Self‑Hiding

To remain stealthy, the rootkit removes itself from kernel module lists.

## Responsible Function
***module_hide_current***
This function:

-Unlinks the module from kernel lists

-Removes its kobject

-Preserves state for potential restoration

# Network Stealth & TCP Hiding
## Hooked Network Functions

The rootkit hooks kernel TCP sequence handlers:

-tcp4_seq_show

-tcp6_seq_show

## This allows it to hide connections from:
-netstat
-ss
-/proc/net/tcp

# Command & Control (C2)
## Hardcoded IPv4 Address

The C2 server IP is embedded directly in the TCP hook logic:
***192.168.5.128***

## Hardcoded C2 Port:
The port appears in network byte order:
***0xA146***
After endian conversion:
***0x46A1 → 18081***
C2 Port:
***18081***

# Privilege Escalation Mechanism
## Trigger Method

Privilege escalation is implemented by hooking getuid().

Conditions:
-Calling process must be bash
-A magic string must be present in process memory

# Magic Word
***MAGIC=babyelephant***
When detected, the rootkit executes:
```
prepare_creds();
commit_creds();
```
Granting root privileges.

# Hooks Installed for Privilege Escalation

The function become_root_init installs syscall hooks to enable escalation.

## Total Hooks Installed
***10***
# Backdoor Network Protocol

The backdoor listens by hooking kernel TCP structures.

## Hooked protocol:
***TCP***
## Conclusion

This rootkit represents a highly modular Linux kernel backdoor featuring:

-Strong stealth via kernel‑level hiding

-Reliable privilege escalation

-Concealed C2 infrastructure

-Anti‑forensics through kernel taint cleanup

The analysis demonstrates why memory forensics and offline kernel analysis are essential when live systems show no visible indicators of compromise.

# References & Tools

-IDA Free

-Cutter

-Linux Kernel Source

-/proc filesystem internals











