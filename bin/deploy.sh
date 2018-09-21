#!/usr/bin/env bash

source bin/env.sh

log() {
  (2>/dev/null echo -e "$@")
}

info()   { log "--- $@"; }
error()  { log "[error] $@"; }
failed() { log "[failed] $@"; exit 1; }

info "kube api url: ${KUBE_SERVER}"
info "namespace: ${KUBE_NAMESPACE}"

export KUBE_CERTIFICATE_AUTHORITY="https://raw.githubusercontent.com/UKHomeOffice/acp-ca/master/${DRONE_DEPLOY_TO}.crt"

info "deploying to environment"
kd --check-interval=5s \
   --timeout=5m \
   -f kube/statefulset.yaml \
   -f kube/service.yaml \
   -f kube/network-policy.yaml
if [[ $? -ne 0 ]]; then
  failed "rollout of deployment"
  exit 1
fi

exit $?
