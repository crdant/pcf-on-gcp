# teardown PCF on GCP
# currently handles only the resources that prepare.sh creates, and will fail due to dependencies if resources
# created by OpsManager (or otherwise) that depend on these prerequisites still exist

env () {
  ACCOUNT="cdantonio@pivotal.io"
  PROJECT="fe-cdantonio"
  DOMAIN=crdant.io

  REGION_1="us-east1"
  AVAILABILITY_ZONE_1="${REGION_1}-b"
  STORAGE_LOCATION="us"
  DOMAIN_TOKEN=`echo ${DOMAIN} | tr . -`
  SUBDOMAIN="gcp.${DOMAIN}"
  DNS_ZONE=`echo ${SUBDOMAIN} | tr . -`
  DNS_TTL=300
  CIDR="10.0.0.0/20"
  ALL_INTERNET="0.0.0.0/0"
  OPS_MANAGER_VERSION="1.8.10"
  OPS_MANAGER_VERSION_TOKEN=`echo ${OPS_MANAGER_VERSION} | tr . -`
  PCF_VERSION="1.8.16"
}


setup () {
  # make sure our API components are up-to-date
  gcloud components update

  # log in (parameterize later)
  gcloud auth login cdantonio@pivotal.io
  gcloud config set project ${PROJECT}
  gcloud config set compute/zone ${AVAILABILITY_ZONE_1}
  gcloud config set compute/region ${REGION_1}
}

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

env
setup
vms
ops_manager
