FROM ubuntu:20.04

LABEL maintainer="hacker-time-labs"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        openssh-server cron nano curl gcc make git \
        python3 lsof net-tools procps sudo && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---- Flags ----
RUN mkdir -p /root && \
    echo 'HT{SUID_m4st3ry_t0ol}' > /root/flag1.txt && \
    echo 'HT{cr0n_1s_y0ur_fr13nd}' > /root/flag2.txt && \
    echo 'HT{n4n0_g4n3r4l_p3t_3sc}' > /root/flag3.txt && \
    echo 'HT{p4sswd_wn_b4d_id3a}' > /root/flag4.txt && \
    chmod 600 /root/flag*.txt

# ---- Create appuser ----
RUN useradd -m -s /bin/bash appuser && \
    echo 'appuser:wareh0use!' | chpasswd

# ---- SUID binary: logviewer ----
COPY files/vulnerable_apps/logviewer.c /tmp/logviewer.c
RUN gcc /tmp/logviewer.c -o /usr/local/bin/logviewer && \
    chmod u+s /usr/local/bin/logviewer && \
    rm /tmp/logviewer.c

# ---- Writable cron script ----
RUN mkdir -p /opt/scripts
COPY --chown=root:root files/vulnerable_apps/report_template.sh /opt/scripts/report.sh
RUN chmod 777 /opt/scripts/report.sh

# ---- Root cron entry ----
RUN mkdir -p /etc/cron.d
COPY files/vulnerable_apps/cron_entry /etc/cron.d/report-gen
RUN chmod 644 /etc/cron.d/report-gen

# ---- Sudo misconfiguration ----
RUN echo 'appuser ALL=(ALL) NOPASSWD: /usr/bin/nano /etc/hosts' \
        > /etc/sudoers.d/appuser-nano && \
    chmod 440 /etc/sudoers.d/appuser-nano

# ---- Weak /etc/passwd permissions ----
RUN chmod 777 /etc/passwd

# ---- Offline resources ----
RUN mkdir -p /opt/tools /opt/hints
COPY files/vulnerable_apps/gtfobins_nano.html /opt/tools/
COPY files/hints/ /opt/hints/

# ---- Backup directory for reset ---
RUN mkdir -p /opt/scripts/backup && \
    chmod -R 755 /opt/scripts/backup

# ---- Provisioning sentinel ----
RUN touch /opt/.lab-provisioned

# ---- Start services ----
RUN mkdir -p /run/sshd
EXPOSE 22

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
