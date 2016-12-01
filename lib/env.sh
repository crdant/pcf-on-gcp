# common environmnet configuration for these scripts

env () {
  REGION_1="us-east1"
  STORAGE_LOCATION="us"
  AVAILABILITY_ZONE_1="${REGION_1}-b"
  AVAILABILITY_ZONE_2="${REGION_1}-c"
  AVAILABILITY_ZONE_3="${REGION_1}-d"

  DOMAIN_TOKEN=`echo ${DOMAIN} | tr . -`
  SUBDOMAIN="gcp.${DOMAIN}"
  DNS_ZONE=`echo ${SUBDOMAIN} | tr . -`
  DNS_TTL=300
  CIDR="10.0.0.0/20"
  ALL_INTERNET="0.0.0.0/0"
  KEYDIR="${BASEDIR}/keys"

  OPS_MANAGER_VERSION="1.8.10"
  OPS_MANAGER_VERSION_TOKEN=`echo ${OPS_MANAGER_VERSION} | tr . -`
  PCF_VERSION="1.8.16"
  MYSQL_VERSION="1.8.0-edge.15"
  RABBIT_VERSION="1.7.6"
  REDIS_VERSION="1.6.2"
  SCS_VERSION="1.3.0"
  GCP_VERSION="2.0.1 (BETA)"
  GCP_VERSION_TOKEN=`echo ${GCP_VERSION} | tr . - | tr ' ' - | tr -d ')' | tr -d '(' | tr '[:upper:]' '[:lower:]'`
  GCP_VERSION_NUM=`echo ${GCP_VERSION} | sed 's/[^0-9.]*//g'`
  GEM_VERSION="1.6.3"
  CONCOURSE_VERSION="1.0.0-edge.3"

  SSH_LOAD_BALANCER_NAME="pcf-ssh-${DOMAIN_TOKEN}"
  HTTP_LOAD_BALANCER_NAME="pcf-http-router-${DOMAIN_TOKEN}"
  WS_LOAD_BALANCER_NAME="pcf-websockets-${DOMAIN_TOKEN}"
  TCP_LOAD_BALANCER_NAME="pcf-tcp-router-${DOMAIN_TOKEN}"
}
