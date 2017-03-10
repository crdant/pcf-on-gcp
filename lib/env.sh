# common environmnet configuration for these scripts

prepare_env () {
  REGION_1="us-east1"
  STORAGE_LOCATION="us"
  AVAILABILITY_ZONE_1="${REGION_1}-b"
  AVAILABILITY_ZONE_2="${REGION_1}-c"
  AVAILABILITY_ZONE_3="${REGION_1}-d"

  DOMAIN_TOKEN=`echo ${DOMAIN} | tr . -`
  SUBDOMAIN="gcp.${DOMAIN}"
  DNS_ZONE=`echo ${SUBDOMAIN} | tr . -`
  DNS_TTL=60
  CIDR="10.0.0.0/20"
  SERVICES_CIDR="10.1.0.0/23"
  ALL_INTERNET="0.0.0.0/0"
  KEYDIR="${BASEDIR}/keys"
  WORKDIR="${BASEDIR}/work"
  PASSWORD_LIST="${KEYDIR}/password-list"

  PCF_SYSTEM_DOMAIN=system.${SUBDOMAIN}
  PCF_APPS_DOMAIN=apps.${SUBDOMAIN}
  OPS_MANAGER_HOST="manager"
  OPS_MANAGER_FQDN="${OPS_MANAGER_HOST}.${SUBDOMAIN}"
  OPS_MANAGER_API_ENDPOINT="https://${OPS_MANAGER_FQDN}/api/v0"
  DIRECTOR_NETWORK_NAME="gcp-${REGION_1}"
  SERVICE_NETWORK_NAME="gcp-${REGION_1}-services"
  SERVICE_ACCOUNT="bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com"

  BUILDPACKS_STORAGE_BUCKET="buildpacks-pcf-${DOMAIN_TOKEN}"
  DROPLETS_STORAGE_BUCKET="droplets-pcf-${DOMAIN_TOKEN}"
  PACKAGES_STORAGE_BUCKET="packages-pcf-${DOMAIN_TOKEN}"
  RESOURCES_STORAGE_BUCKET="resources-pcf-${DOMAIN_TOKEN}"

  OPS_MANAGER_VERSION="1.9.5"
  OPS_MANAGER_VERSION_TOKEN=`echo ${OPS_MANAGER_VERSION} | tr . -`
  PCF_VERSION="1.9.10"
  STEMCELL_VERSION="3263"
  MYSQL_VERSION="1.9.0"
  RABBIT_VERSION="1.7.13"
  REDIS_VERSION="1.7.2"
  SCS_VERSION="1.3.3"
  GCP_VERSION="3.1.2 (BETA)"
  GCP_VERSION_TOKEN=`echo ${GCP_VERSION} | tr . - | tr ' ' - | tr -d ')' | tr -d '(' | tr '[:upper:]' '[:lower:]'`
  GCP_VERSION_NUM=`echo ${GCP_VERSION} | sed 's/[^0-9.]*//g'`
  GEM_VERSION="1.6.6"
  CONCOURSE_VERSION="1.0.0-edge.9"
  IPSEC_VERSION="1.5.37"
  STACKDRIVER_VERSION="0.0.1 (BETA)"
  STACKDRIVER_VERSION_TOKEN=`echo ${STACKDRIVER_VERSION} | tr . - | tr ' ' - | tr -d ')' | tr -d '(' | tr '[:upper:]' '[:lower:]'`
  STACKDRIVER_VERSION_NUM=`echo ${STACKDRIVER_VERSION} | sed 's/[^0-9.]*//g'`
  PUSH_VERSION="1.8.0"

  SSH_LOAD_BALANCER_NAME="pcf-ssh-${DOMAIN_TOKEN}"
  HTTP_LOAD_BALANCER_NAME="pcf-http-router-${DOMAIN_TOKEN}"
  WS_LOAD_BALANCER_NAME="pcf-websockets-${DOMAIN_TOKEN}"
  TCP_LOAD_BALANCER_NAME="pcf-tcp-router-${DOMAIN_TOKEN}"

  BROKER_DB_USER="pcf"

  # set variables for passwords if they are available
  if [ -e ${PASSWORD_LIST} ] ; then
    . ${PASSWORD_LIST}
  fi

}
