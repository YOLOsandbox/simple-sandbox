#!/bin/bash
# test_security.sh - Validates all security features from documentation

# Test metadata
TEST_NAME="Security"
TEST_DESCRIPTION="Security Validation"
TEST_CATEGORY="security"

source ./test_common.sh

print_header "$TEST_DESCRIPTION"

# FEATURE: Linux Capability Restrictions (Section 4.1)
start_group "Linux Capabilities"
run_test "CAP_NET_RAW denied (no ping)" "! ping -c 1 127.0.0.1 2>/dev/null" "pass"
run_test "CAP_SYS_ADMIN denied (no mount)" "! mount -t tmpfs tmpfs /mnt 2>/dev/null" "pass"
run_test "CAP_NET_ADMIN denied (no network)" "! ip link set lo down 2>/dev/null" "pass"
run_test "CAP_SYS_MODULE denied (no modules)" "! modprobe dummy 2>/dev/null" "pass"

# FEATURE: Filesystem Isolation (Section 4.3)
start_group "Filesystem Isolation"
run_test "Docker config read-only" "! touch /workspace/docker/test 2>/dev/null" "pass"
run_test "DevContainer config read-only" "! touch /workspace/.devcontainer/test 2>/dev/null" "pass"
run_test "No host block devices" "! test -e /dev/sda && ! test -e /dev/nvme0n1" "pass"
run_test "No Docker socket" "! test -e /var/run/docker.sock" "pass"

# FEATURE: Sudo Restrictions (Section 4.5)
start_group "Sudo Restrictions"
run_test "No root shell via sudo" "! sudo -n bash -c 'whoami' 2>/dev/null" "pass"
run_test "No arbitrary sudo commands" "! sudo -n ls /root 2>/dev/null" "pass"
run_test "APT commands allowed" "sudo apt-get check >/dev/null 2>&1" "pass"

# FEATURE: Container Isolation
start_group "Container Isolation"
run_test "Cannot access Docker daemon" "! docker ps 2>/dev/null" "pass"
run_test "Limited process view (<100)" "[ \$(ps aux | wc -l) -lt 100 ]" "pass"
run_test "PID namespace exists" "test -e /proc/1/ns/pid" "pass"

# FEATURE: Resource Limits
start_group "Resource Limits"
run_test "Process limit ≤1000" "[ \$(ulimit -u) -le 1000 ]" "pass"
run_test "File descriptor limit ≤8192" "[ \$(ulimit -n) -le 8192 ]" "pass"

print_summary
exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)