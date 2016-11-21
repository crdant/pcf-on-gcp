# teardown PCF on GCP
# currently handles only the resources that prepare.sh creates, and will fail due to dependencies if resources
# created by OpsManager (or otherwise) that depend on these prerequisites still exist

env () {
  ACCOUNT="cdantonio@pivotal.io"
  PROJECT="fe-cdantonio"
  REGION="us-east1"
  AVAILABILITY_ZONE="us-east1-b"
  DOMAIN="crdant.io"
  DOMAIN_TOKEN=`echo ${DOMAIN} | tr . -`
  SUBDOMAIN="gcp.${DOMAIN}"
  DNS_ZONE=`echo ${SUBDOMAIN} | tr . -`
  CIDR="10.0.0.0/20"
  ALL_INTERNET="0.0.0.0/0"
}

setup () {
  # make sure our API components are up-to-date
  gcloud components update

  # log in (parameterize later)
  gcloud auth login cdantonio@pivotal.io
  gcloud config set project ${PROJECT}
  gcloud config set compute/zone ${AVAILABILITY_ZONE}
  gcloud config set compute/region ${REGION}
}

vms () {
  # pause all bosh managed VMs
  for instance in `gcloud compute --project ${PROJECT} instances list --filter='tags.items:pcf-vms' --uri`; do
      gcloud compute --project ${PROJECT} instances stop "${instance}" --quiet &
  done

}

ops_manager () {
  # pause Ops Manager
  gcloud compute --project "${PROJECT}" instances stop "pcf-ops-manager-187" --zone "${AVAILABILITY_ZONE}" --quiet
}

env
setup
vms
ops_manager
