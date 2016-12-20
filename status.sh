# teardown PCF on GCP
# currently handles only the resources that prepare.sh creates, and will fail due to dependencies if resources
# created by OpsManager (or otherwise) that depend on these prerequisites still exist

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/personal.sh"

. "${BASEDIR}/lib/setup.sh"

setup () {
  printf "%-45s %-35s %-15s\n" "INSTANCE" "JOB" "STATUS"
}

vms () {
  # pause all bosh managed VMs
  for instance in `gcloud compute --project ${PROJECT} instances list --filter='tags.items:pcf-vms' --uri`; do
      INSTANCE_DETAILS=`gcloud --format json compute --project ${PROJECT} instances describe "${instance}" --quiet`
      NAME=`echo "${INSTANCE_DETAILS}" | jq --raw-output ".name"`
      JOB=`echo "${INSTANCE_DETAILS}" | jq --raw-output '.metadata .items [] | select ( .key == "job") .value'`
      STATUS=`echo "${INSTANCE_DETAILS}" | jq --raw-output '.status'`
      printf  "%-45s %-35s %-15s\n" $NAME $JOB $STATUS
  done
}

ops_manager () {
  # pause all bosh managed VMs
  for instance in `gcloud compute --project ${PROJECT} instances list --filter='tags.items:pcf-opsmanager' --uri`; do
      INSTANCE_DETAILS=`gcloud --format json compute --project ${PROJECT} instances describe "${instance}" --quiet | jq '{name, status}'`
      NAME=`echo "${INSTANCE_DETAILS}" | jq --raw-output ".name"`
      JOB="ops_manager"
      STATUS=`echo "${INSTANCE_DETAILS}" | jq --raw-output '.status'`
      printf  "%-45s %-35s %-15s\n" $NAME $JOB $STATUS
  done
}

prepare_env
setup
ops_manager
vms
