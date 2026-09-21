#!/bin/bash

pass=0
fail=0

check_allow() {
    # $1=host $2=port $3=περιγραφή
    if nc -z -w3 "$1" "$2" 2>/dev/null; then
        echo "PASS (allow): $3"
        pass=$((pass+1))
    else
        echo "FAIL (allow): $3 — should connect"
        fail=$((fail+1))
    fi
}

check_deny() {
    if nc -z -w3 "$1" "$2" 2>/dev/null; then
        echo "FAIL (deny): $3 — should be blocked"
        fail=$((fail+1))
    else
        echo "PASS (deny): $3"
        pass=$((pass+1))
    fi
}

echo "=== Allow tests ==="
check_allow 10.0.20.10 9100 "infra->master metrics"
check_allow 10.0.30.10 9187 "infra->db postgres metrics"
check_allow 10.0.20.10 6443 "infra->master k3s API"

echo "=== Deny tests ==="
check_deny 10.0.30.10 22 "infra->db SSH (should block)"

echo "==="
echo "PASS: $pass  FAIL: $fail"
[ $fail -eq 0 ]
