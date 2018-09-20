#!/usr/bin/env bash -e

export DRONE_DEPLOY_TO=${DRONE_DEPLOY_TO:-acp-notprod}
export KUBE_NAMESPACE="REPLACE_ME"
export MONGODB_STORAGE=""

case "${DRONE_DEPLOY_TO}" in
  acp-notprod)
    export KUBE_SERVER="${KUBE_SERVER_ACP_NOTPROD}"
    export KUBE_TOKEN="${KUBE_TOKEN_ACP_NOTPROD}"
    ;;
  *)
    echo "The environment: ${DRONE_DEPLOY_TO} is not configured"
    exit 1
    ;;
esac
