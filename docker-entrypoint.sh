#!/bin/bash
# Docker entrypoint: start SSH and cron on container start
set -e

# Regenerate SSH host keys if missing (first-run)
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    dpkg-reconfigure openssh-server || ssh-keygen -A
fi

mkdir -p /run/sshd
/usr/sbin/sshd

service cron start

echo "[entrypoint] SSH and cron started.  Target is ready."

# Tail syslog so the container stays alive and `docker logs` works
tail -f /var/log/syslog 2>/dev/null || tail -f /dev/null
