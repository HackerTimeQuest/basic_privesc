# 🔓 HackerTime — Basic Privilege Escalation

A self-contained Linux VM designed for hands-on practical privilege escalation training.
Get an initial foothold as `appuser` and exploit four different misconfigurations to reach root.

## What you'll practice

| # | Technique | Real-world relevance |
|---|-----------|----------------------|
| 1 | SUID binary exploitation | Found in almost every engagement |
| 2 | Abusing cron jobs | Common in poorly maintained systems |
| 3 | Sudo misconfigurations | GTFOBins / writable sudoers |
| 4 | Weak file permissions | /etc/passwd, .ssh keys, config files |

## Prerequisites

- Docker Desktop or VirtualBox + Vagrant
- Basic Linux navigation and reading
- Familiarity with SSH

## Quick start

```bash
git clone <repo-url>
cd basic_privesc
./scripts/setup.sh
```

This provisions a local VM with the vulnerable target. Then:

```bash
ssh appuser@<lab-ip>   # password: wareh0use!
```

Read `lab.md` for the full story and rules before connecting.

## Safety

- All traffic is contained to a host-only or Docker network — nothing reaches the internet
- Run `./scripts/reset.sh` to revert the VM to its initial state at any time
- Run `./scripts/validate.sh` to confirm all flags are in their correct starting positions (asserts pass when flags are NOT placed)

## Contributing

All contributions welcome. Follow the folder structure at root of this repo.
