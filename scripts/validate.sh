#!/usr/bin/env bash
# validate.sh — Confirm all four flags and vulnerabilities are correctly placed.
# Exit 0 on success, non-zero on failure.
# Usage: ./scripts/validate.sh [provider] [custom-ssh-target]
#   ./scripts/validate.sh                  # auto-detect provider
#   ./scripts/validate.sh terraform        # use Terraform output IP
#   ./scripts/validate.sh vagrant          # use Vagrant host-only IP
#   ./scripts/validate.sh custom user@host # use custom SSH target

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Determine SSH target based on provider
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

PROVIDER="${1:-auto}"
CUSTOM_TARGET="${2:-}"
SSHOPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"

if [ -n "$CUSTOM_TARGET" ]; then
  TARGET="$CUSTOM_TARGET"
else
  case "$PROVIDER" in
    terraform|azure)
      cd "$LAB_DIR/infrastructure/terraform"
      PUBLIC_IP=$(terraform output -raw public_ip_address 2>/dev/null || echo "")
      if [ -z "$PUBLIC_IP" ]; then
        echo "ERROR: Could not get Terraform output. Have you run setup.sh?" >&2
        exit 1
      fi
      TARGET="azureuser@$PUBLIC_IP"
      ;;
    vagrant)
      TARGET="appuser@192.168.49.10"
      ;;
    auto)
      # Try to auto-detect which provider is running
      if cd "$LAB_DIR/infrastructure/terraform" 2>/dev/null && terraform output public_ip_address &>/dev/null 2>&1; then
        PUBLIC_IP=$(terraform output -raw public_ip_address 2>/dev/null || echo "")
        if [ -n "$PUBLIC_IP" ]; then
          TARGET="azureuser@$PUBLIC_IP"
        fi
      elif vagrant global-status 2>/dev/null | grep -q "running" && vagrant global-status 2>/dev/null | grep -q "hacker-time-privesc"; then
        TARGET="appuser@192.168.49.10"
      else
        echo "ERROR: Could not auto-detect running provider. Specify one: terraform|vagrant" >&2
        exit 1
      fi
      ;;
    *)
      TARGET="${PROVIDER}"
      ;;
  esac
fi

PASS=0
FAIL=0

check() {
  local desc="$1"
  local expected="$2"
  local actual="$3"

  if [ "$actual" = "$expected" ]; then
    echo -e "${GREEN}[PASS]${RESET} ${desc}"
    ((PASS++))
  else
    echo -e "${RED}[FAIL]${RESET} ${desc}  (expected: ${expected}, got: ${actual})"
    ((FAIL++))
  fi
}

echo "═══════════════════════════════════════"
echo "  Validating lab provisioning"
echo "═══════════════════════════════════════"
echo ""

# --- Flag 1: SUID binary exists ---
OUT=$(sshpass -p 'wareh0use!' ssh $SSHOPT "$TARGET" \
  'ls -la /usr/local/bin/logviewer 2>/dev/null | awk "{print \$1}"' 2>/dev/null || echo "MISSING")
check "Flag 1 — logviewer is SUID root" "-rwsr-xr-x" "$OUT"

# --- Flag 2: cron script is world-writable ---
OUT=$(sshpass -p 'wareh0use!' ssh $SSHOPT "$TARGET" \
  'ls -la /opt/scripts/report.sh 2>/dev/null | awk "{print \$1}"' 2>/dev/null || echo "MISSING")
check "Flag 2 — report.sh is world-writable" "-rwxrwxrwx" "$OUT"

# --- Flag 3: sudoers entry exists ---
OUT=$(sshpass -p 'wareh0use!' ssh $SSHOPT "$TARGET" \
  'sudo -l 2>/dev/null | grep -c "nano /etc/hosts" || echo 0' 2>/dev/null || echo "MISSING")
check "Flag 3 — sudo nano rule exists" "1" "$OUT"

# --- Flag 4: /etc/passwd permissions ---
OUT=$(sshpass -p 'wareh0use!' ssh $SSHOPT "$TARGET" \
  'stat -c "%a" /etc/passwd 2>/dev/null || echo "MISSING"' 2>/dev/null || echo "MISSING")
check "Flag 4 — /etc/passwd mode is 777" "777" "$OUT"

# --- Flag content integrity (flags must still be present) ---
for i in 1 2 3 4; do
  OUT=$(sshpass -p 'wareh0use!' ssh $SSHOPT "$TARGET" \
    "sudo cat /root/flag${i}.txt 2>/dev/null | tr -d '[:space:]' || echo GONE" 2>/dev/null || echo "MISSING")
  check "Flag ${i} content intact" "non-empty" \
    "$([ -z "$OUT" ] && echo empty || echo non-empty)"
done

echo ""
echo -e "${YELLOW}───────────────────────────────────────${RESET}"
echo -e "${GREEN}PASS: ${PASS}${RESET}  ${RED}FAIL: ${FAIL}${RESET}"
echo -e "${YELLOW}───────────────────────────────────────${RESET}"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
