#!/usr/bin/env bash
# start instances running at the IaaS level

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/personal.sh"
. "${BASEDIR}/lib/login_ops_manager.sh"
. "${BASEDIR}/lib/unlock_ops_manager.sh"

. "${BASEDIR}/lib/setup.sh"

vms () {
  # pause all bosh managed VMs
  for instance in `gcloud compute --project ${PROJECT} instances list --filter='tags.items:pcf-vms' --uri`; do
      gcloud compute --project ${PROJECT} instances start "${instance}" --quiet &
  done
}

ops_manager () {
  # pause Ops Manager
  gcloud compute --project "${PROJECT}" instances start "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone "${AVAILABILITY_ZONE_1}" --quiet
  unlock_ops_manager
}



bosh_cck () {
  # connect to ops manager director and run bosh cloud check
  echo "Fill in an SSH to the ops manager and execute bosh cck (or maybe just do it from here)"
}

prepare_env
setup
ops_manager

vms
