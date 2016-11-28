export ACCOUNT="cdantonio@pivotal.io"
exportPROJECT="fe-cdantonio"
exportDOMAIN=crdant.io

export REGION_1="us-east1"
export AVAILABILITY_ZONE_1="${REGION_1}-b"
export STORAGE_LOCATION="us"
export DOMAIN_TOKEN=`echo ${DOMAIN} | tr . -`
export SUBDOMAIN="gcp.${DOMAIN}"
export DNS_ZONE=`echo ${SUBDOMAIN} | tr . -`
export DNS_TTL=300
export CIDR="10.0.0.0/20"
export ALL_INTERNET="0.0.0.0/0"
export OPS_MANAGER_VERSION="1.8.10"
export OPS_MANAGER_VERSION_TOKEN=`echo ${OPS_MANAGER_VERSION} | tr . -`
export PCF_VERSION="1.8.16"
