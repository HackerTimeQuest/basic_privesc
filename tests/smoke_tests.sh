#!/usr/bin/env bash
# smoke_tests.sh — Container-level integration tests (run inside the target VM)
# Sources the .env file if available for password/flag values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

check() {
  local desc="$1" result="$2" expected="$3"
  if [ "$result" = "$expected" ]; then
    echo -e "${GREEN}[PASS]${RESET} ${desc}"
    ((PASS++)) || true
  else
    echo -e "${RED}[FAIL]${RESET} ${desc}  (expected: ${expected})"
    ((FAIL++)) || true
  fi
}

echo "Running smoke tests …"
echo ""

# 1. appuser exists
check "appuser exists" \
  "$(id -u appuser 2>/dev/null && echo ok || echo fail)" \
  "ok"

# 2. appuser can SSH with password
#    (tested by validate.sh externally)

# 3. logviewer is SUID
MODE=$(stat -c "%a" /usr/local/bin/logviewer 2>/dev/null || echo "000")
check "logviewer SUID bit" "$MODE" "4755"

# 4. logviewer executable
check "logviewer runs" \
  "$(logviewer /etc/hostname 2>/dev/null | head -1)" \
  "wackywarehouse"

# 5. report.sh exists and is 777
MODE=$(stat -c "%a" /opt/scripts/report.sh 2>/dev/null || echo "000")
check "report.sh world-writable" "$MODE" "777"

# 6. cron entry exists
check "cron job in /etc/cron.d" \
  "$(ls /etc/cron.d/report-gen >/dev/null 2>&1 && echo ok || echo fail)" \
  "ok"

# 7. sudoers rule
check "sudo nano allowed" \
  "$(sudo -l 2>&1 | grep -c 'nano /etc/hosts' || echo 0)" \
  "1"

# 8. /etc/passwd mode
MODE=$(stat -c "%a" /etc/passwd)
check "/etc/passwd is world-writable" "$MODE" "1777"

# 9. All four flag files exist
for i in 1 2 3 4; do
  check "flag${i}.txt present" \
    "$(test -f /root/flag${i}.txt && echo ok || echo fail)" \
    "ok"
done

# 10. Hint files exist
for i in 1 2 3; do
  check "hint${i}.txt present" \
    "$(test -f /opt/hints/hint${i}.txt && echo ok || echo fail)" \
    "ok"
done

# 11. SSH server running
check "sshd is active" \
  "$(pgrep -x sshd >/dev/null && echo ok || echo fail)" \
  "ok"

# 12. Provision sentinel
check "provisioning completed" \
  "$(test -f /opt/.lab-provisioned && echo ok || echo fail)" \
  "ok"

echo ""
echo "───────────────────────────"
echo -e "${GREEN}PASS: ${PASS}${RESET}  ${RED}FAIL: ${FAIL}${RESET}"
echo "───────────────────────────"

[ "$FAIL" -eq 0 ] && echo "All checks passed!" && exit 0
echo "Some checks failed." >&2
exit 1
