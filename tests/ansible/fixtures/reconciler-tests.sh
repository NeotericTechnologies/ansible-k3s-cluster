#!/bin/bash
set -eu

root="$1"
scenario="$2"
script="$3"
expected="$4"
mkdir -p "${root}/${scenario}"
export TEST_STATE="${root}/${scenario}" TEST_SCENARIO="${scenario}"
export CONTROL_PLANE_VIP=192.0.2.8 VIP_IFACE=eth0 VIP_CHECK_IMAGE=busybox:test
export STALE_VIP_RECHECK_DELAY=0 NAMESPACE=synology-csi SNAPSHOTS_ENABLED=true
export HOSTNAME=reconciler-test
export KUBERNETES_SERVICE_HOST=192.0.2.1 KUBERNETES_SERVICE_PORT_HTTPS=443
export PATH="${root}/bin:${PATH}"
if [ "${scenario}" = synology_healthy_no_snapshots ]; then
  export SNAPSHOTS_ENABLED=false
fi

status=0
/bin/sh "${root}/${script}.sh" > "${TEST_STATE}/output" 2>&1 || status=$?
if [ "${expected}" = success ]; then
  if [ "${status}" -ne 0 ]; then
    cat "${TEST_STATE}/output" >&2
    exit 1
  fi
else
  if [ "${status}" -eq 0 ] || ! grep -q 'ERROR:' "${TEST_STATE}/output"; then
    cat "${TEST_STATE}/output" >&2
    echo "Expected explicit failure: ${scenario}" >&2
    exit 1
  fi
  if grep -Eq 'result: (NO DRIFT|checked)' "${TEST_STATE}/output"; then
    echo "False success: ${scenario}" >&2
    exit 1
  fi
fi

case "${scenario}" in
  synology_healthy)
    test "$(grep -c '^.*leader .*renewed' "${TEST_STATE}/output")" -eq 5
    grep -q 'synology-csi-controller-1/csi-resizer' "${TEST_STATE}/output"
    ;;
  synology_healthy_no_snapshots)
    test "$(grep -c '^.*leader .*renewed' "${TEST_STATE}/output")" -eq 3
    ! grep -Eq 'get lease (external-snapshotter|snapshot-controller)' "${TEST_STATE}/calls"
    ;;
  vip_missing_holder)
    test -f "${TEST_STATE}/restarted-kube-vip-node-a"
    grep -q 'DRIFT CORRECTED' "${TEST_STATE}/output"
    ;;
  vip_stale)
    test -f "${TEST_STATE}/restarted-kube-vip-node-b"
    grep -q 'vip-clear-' "${TEST_STATE}/calls"
    ;;
  vip_handoff)
    test -f "${TEST_STATE}/restarted-kube-vip-node-b"
    ! grep -q 'vip-clear-' "${TEST_STATE}/calls"
    ;;
  synology_dsm_failure)
    test -f "${TEST_STATE}/restarted-synology-csi-controller-0"
    ! test -f "${TEST_STATE}/restarted-synology-csi-controller-1"
    ;;
esac
case "${scenario}" in
  vip_expired|vip_missing_renewal|vip_probe_failure|vip_api_failure|vip_label_read_failure|lease_api_failure)
    ! grep -Eq ' (label node|delete pod kube-vip-)' "${TEST_STATE}/calls"
    ;;
  synology_expired|synology_missing_renewal|synology_missing_lease|synology_unready|synology_api_failure|synology_log_failure|synology_empty|synology_healthy|synology_healthy_no_snapshots)
    ! grep -Eq ' (delete pod synology-csi-|patch lease|delete lease|create lease)' "${TEST_STATE}/calls"
    ;;
esac
echo "PASS ${scenario}"
