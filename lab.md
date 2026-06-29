---
title: "HackerTime Lab — Basic Privilege Escalation"
version: "1.0"
difficulty: "Beginner"
estimated_time: "1–2 hours"
tags: [linux, privesc, suid, cron, sudo, permissions]
---

## Scenario

You've just scored a foothold on **WackyCorp's** warehouse management server through a web application vulnerability (not part of this lab). You are logged in as the **`appuser`** account and your mission now is simple:

> **Escalate your privileges and gain full control of the system.**

While you investigate, you spot four text files the root user seems to care about — each one counts as a "cap" demonstrating a different escalation path:

```
/root/flag1.txt   (SUID path)
/root/flag2.txt   (Cron path)
/root/flag3.txt   (Sudo path)
/root/flag4.txt   (Permissions path)
```

Submitting any one flag proves you've successfully escalated. Finding all four workshops every vector.

## How you get in

| Protocol | Host | User | Password |
|----------|------|------|----------|
| SSH | `192.168.49.10` (Vagrant) or `localhost:2222` (Docker) | `appuser` | `wareh0use!` |

> If you're using the Vagrant provider the VM gets a host-only IP at `192.168.49.10`. Docker compose maps port `2222` on your host to the SSH server inside the container.

## Rules

1. **Work locally only.** Knocking on any address other than the VM must not give you results. This lab is intentionally isolated.
2. **All exploitation is expected from inside the box** once you SSH in. No external nmap or masscan is needed.
3. **Do what real pentesters do:** Enumerate, think creatively, take notes.
4. **4 flags, 4 techniques.** Each flag corresponds to one privilege-escalation vector. You do NOT need to find all four, but the walkthrough shows you how.

## What to expect

The server is a standard Ubuntu 20.04 LTS machine — nothing exotic on the surface. Your job is the same as in the field:

1. Confirm who you are and what you can do (`id`, `sudo -l`, `env`, etc.)
2. Enumerate the system thoroughly (SUID binaries, cron, writable files, kernel version, Docker socket, …)
3. Find misconfigurations and abuse them
4. Collect the flags and consider yourself hired ☕

## Hints

If you're completely stuck there are three optional hint files:

```
echo <your-flag-here>       # submit only the flag text
```

To view numbered hints without spoiling the solution, SSH into the box and cat the files at `/opt/hints/`. There are three levels of increasing specificity.

Good luck, hacker. The warehouse is waiting.
