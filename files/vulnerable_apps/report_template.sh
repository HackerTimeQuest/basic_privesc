#!/bin/bash
# Daily warehouse report
echo "=== Warehouse Daily Report ===" > /var/tmp/report.txt
date >> /var/tmp/report.txt
df -h >> /var/tmp/report.txt
uptime >> /var/tmp/report.txt
echo "Report complete."
