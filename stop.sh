#!/usr/bin/env bash
# stop running instances at the IaaS level

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/personal.sh"

. "${BASEDIR}/lib/setup.sh"

vms () {
  # pause all bosh managed VMs
  for instance in `gcloud compute --project ${PROJECT} instances list --filter='tags.items:pcf-vms' --uri`; do
      gcloud compute --project ${PROJECT} instances stop "${instance}" --quiet &
  done

}

ops_manager () {
  # pause Ops Manager
  gcloud compute --project "${PROJECT}" instances stop "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone "${AVAILABILITY_ZONE_1}" --quiet
}

prepare_env
setup
vms
ops_manager
