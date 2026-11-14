#!/bin/sh
set -eu

printf '%s\n' "$*" >> "${TEST_STATE}/calls"
case "$1" in --request-timeout=*) shift;; esac
case "$1" in --server=*) shift;; esac
scenario="${TEST_SCENARIO}"

case "$1 $2" in
  'get nodes')
    [ "${scenario}" != vip_api_failure ] || exit 1
    echo 'node-a node-b'
    ;;
  'get lease')
    [ "${scenario}" != lease_api_failure ] || exit 1
    renewed=$(date -u +%FT%TZ)
    case "${scenario}" in
      vip_missing_renewal|synology_missing_renewal) renewed='';;
      vip_expired|synology_expired)
        renewed=$(date -u -d "@$(( $(date -u +%s) - 120 ))" +%FT%TZ)
        ;;
    esac
    case "$*" in
      *leaseTransitions*)
        owner=node-a
        if [ "${scenario}" = vip_handoff ] && [ -f "${TEST_STATE}/restarted-kube-vip-node-b" ]; then
          owner=node-b
        fi
        echo "${owner}|2|${renewed}|15"
        ;;
      *)
        [ "${scenario}" != synology_missing_lease ] || exit 0
        holder=synology-csi-controller-0
        case "$*" in *snapshot-controller-leader*) holder=synology-csi-snapshotter-test;; esac
        case "$*" in *external-resizer*) holder=synology-csi-controller-1;; esac
        echo "${holder}|${renewed}|15"
        ;;
    esac
    ;;
  'get node')
    [ "${scenario}" != vip_label_read_failure ] || exit 1
    if [ "$3" = node-a ] && [ "${scenario}" != vip_label_failure ]; then
      echo 192.0.2.8
    fi
    ;;
  'get svc') ;;
  'get pods')
    case "$*" in
      *spec.nodeName=node-a*) echo kube-vip-node-a;;
      *spec.nodeName=node-b*) echo kube-vip-node-b;;
      *)
        [ "${scenario}" != synology_api_failure ] || exit 1
        [ "${scenario}" != synology_empty ] || exit 0
        printf '%s\n' pod/synology-csi-controller-0 pod/synology-csi-controller-1 pod/synology-csi-node-test
        ;;
    esac
    ;;
  'get pod')
    if [ "${scenario}" = synology_unready ]; then
      echo '|false'
    else
      echo '|true'
    fi
    ;;
  'create -f')
    manifest=$(cat)
    pod=$(printf '%s\n' "${manifest}" | awk '/^  name: / {print $2; exit}')
    case "${pod}" in
      vip-check-*)
        result=CLEAN
        case "${pod}" in
          *node-a)
            result=PRESENT
            if [ "${scenario}" = vip_missing_holder ] && [ ! -f "${TEST_STATE}/restarted-kube-vip-node-a" ]; then
              result=CLEAN
            fi
            ;;
          *node-b)
            case "${scenario}" in vip_stale|vip_handoff) result=PRESENT;; esac
            ;;
        esac
        echo "${result}" > "${TEST_STATE}/${pod}"
        ;;
      vip-clear-*) echo REMOVED > "${TEST_STATE}/${pod}";;
      *) echo "Unexpected pod: ${pod}" >&2; exit 1;;
    esac
    ;;
  'wait --for=jsonpath='*)
    [ "${scenario}" != vip_probe_failure ] || exit 1
    ;;
  'logs '*)
    case "$2" in
      vip-check-*|vip-clear-*) cat "${TEST_STATE}/$2";;
      *)
        [ "${scenario}" != synology_log_failure ] || exit 1
        if [ "${scenario}" = synology_dsm_failure ] && [ "$2" = synology-csi-controller-0 ] \
          && [ ! -f "${TEST_STATE}/restarted-synology-csi-controller-0" ]; then
          echo 'Failed to add DSM'
        else
          echo 'Listening for connections'
        fi
        ;;
    esac
    ;;
  'delete pod')
    case "$3" in
      kube-vip-*|synology-csi-*) touch "${TEST_STATE}/restarted-$3";;
    esac
    ;;
  'label node')
    [ "${scenario}" != vip_label_failure ] || exit 1
    ;;
  'rollout status') ;;
  *) echo "Unexpected kubectl call: $*" >&2; exit 1;;
esac
