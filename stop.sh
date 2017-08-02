#!/usr/bin/env bash
# stop running instances at the IaaS level

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/util.sh"
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
  for instance in `gcloud compute --project ${PROJECT} instances list --filter='tags.items:pcf-opsmanager' --uri`; do
    gcloud compute --project ${PROJECT} instances stop "${instance}" --quiet
  done
}

prepare_env
setup
vms
ops_manager
