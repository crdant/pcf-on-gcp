# common environmnet configuration for these scripts

prepare_env () {
  set_versions
  product_slugs

  DOMAIN_TOKEN=`echo ${DOMAIN} | tr . -`
  SUBDOMAIN="gcp.${DOMAIN}"
  SUBDOMAIN_TOKEN=`echo ${SUBDOMAIN} | tr . -`

  REGION_1="us-east1"
  STORAGE_LOCATION="us"
  AVAILABILITY_ZONE_1="${REGION_1}-b"
  AVAILABILITY_ZONE_2="${REGION_1}-c"
  AVAILABILITY_ZONE_3="${REGION_1}-d"
  SERVICE_ACCOUNT="bosh-opsman-${SUBDOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com"

  DNS_ZONE="${SUBDOMAIN}"
  DNS_TTL=60

  DNS_ZONE=`echo ${SUBDOMAIN} | tr . -`
  DNS_TTL=60
  CIDR="10.0.0.0/20"
  ALL_INTERNET="0.0.0.0/0"
  KEYDIR="${BASEDIR}/keys"
  WORKDIR="${BASEDIR}/work"
  PASSWORD_LIST="${KEYDIR}/password-list"

  INFRASTRUCTURE_CIDR="10.0.0.0/26"
  INFRASTRUCTURE_RESERVED="10.0.0.1"
  INFRASTRUCTURE_GATEWAY="10.0.0.1-10.0.0.10"
  DEPLOYMENT_CIDR="10.1.0.0/22"
  DEPLOYMENT_RESERVED="10.1.0.1"
  DEPLOYMENT_GATEWAY="10.1.0.1-10.1.0.9"
  TILES_CIDR="10.2.0.0/22"
  TILES_RESERVED="10.2.0.1"
  TILES_GATEWAY="10.2.0.1-10.2.0.9"
  SERVICES_CIDR="10.2.0.0/22"
  SERVICES_RESERVED="10.2.0.1"
  SERVICES_GATEWAY="10.2.0.1-10.2.0.9"

  PCF_SYSTEM_DOMAIN=system.${SUBDOMAIN}
  PCF_APPS_DOMAIN=apps.${SUBDOMAIN}
  OPS_MANAGER_HOST="manager"
  OPS_MANAGER_FQDN="${OPS_MANAGER_HOST}.${SUBDOMAIN}"
  OPS_MANAGER_API_ENDPOINT="https://${OPS_MANAGER_FQDN}/api/v0"
  INFRASTRUCTURE_NETWORK_NAME="gcp-${REGION_1}-infrastructure"
  DEPLOYMENT_NETWORK_NAME="gcp-${REGION_1}-deployment"
  TILES_NETWORK_NAME="gcp-${REGION_1}-tiles"
  SERVICE_NETWORK_NAME="gcp-${REGION_1}-services"

  BUILDPACKS_STORAGE_BUCKET="buildpacks-pcf-${SUBDOMAIN_TOKEN}"
  DROPLETS_STORAGE_BUCKET="droplets-pcf-${SUBDOMAIN_TOKEN}"
  PACKAGES_STORAGE_BUCKET="packages-pcf-${SUBDOMAIN_TOKEN}"
  RESOURCES_STORAGE_BUCKET="resources-pcf-${SUBDOMAIN_TOKEN}"

  # OPS_MANAGER_VERSION="1.9.5"
  OPS_MANAGER_VERSION="1.10.6"
  OPS_MANAGER_VERSION_TOKEN=`echo ${OPS_MANAGER_VERSION} | tr . -`
  # PCF_VERSION="1.9.10"
  PCF_VERSION="1.10.0-rc.5"
  STEMCELL_VERSION="3263.20"
  MYSQL_VERSION="1.9.0"
  RABBIT_VERSION="1.7.14"
  REDIS_VERSION="1.7.3"SSH
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
  ISOLATION_VERSION="1.10.0-rc.2"

  SSH_LOAD_BALANCER_NAME="pcf-ssh-${SUBDOMAIN_TOKEN}"
  HTTP_LOAD_BALANCER_NAME="pcf-http-router-${SUBDOMAIN_TOKEN}"
  WS_LOAD_BALANCER_NAME="pcf-websockets-${SUBDOMAIN_TOKEN}"
  TCP_LOAD_BALANCER_NAME="pcf-tcp-router-${SUBDOMAIN_TOKEN}"

  BROKER_DB_USER="pcf"

  # set variables for passwords if they are available
  if [ -e ${PASSWORD_LIST} ] ; then
    . ${PASSWORD_LIST}
  fi

}

set_versions () {
  OPS_MANAGER_VERSION="1.10.4"
  OPS_MANAGER_VERSION_TOKEN=`echo ${OPS_MANAGER_VERSION} | tr . -`
  PCF_VERSION="1.10.7"
  STEMCELL_VERSION="3363.15"
  MYSQL_VERSION="1.9.1"
  RABBIT_VERSION="1.8.1"
  REDIS_VERSION="1.8.0.beta.121"
  PCC_VERSION="1.0.1"
  SCS_VERSION="1.3.4"
  SERVICE_BROKER_VERSION="1.2.0"
  WINDOWS_VERSION="1.10.0"
  ISOLATION_VERSION="1.10.4"
  IPSEC_VERSION="1.5.37"
  PUSH_VERSION="1.8.1"
  SSO_VERSION="1.3.2"
}

product_slugs () {
  PCF_SLUG="elastic-runtime"
  PCF_OPSMAN_SLUG="cf"
  OPS_MANAGER_SLUG="ops-manager"
  MYSQL_SLUG="p-mysql"
  REDIS_SLUG="p-redis"
  RABBIT_SLUG="p-rabbitmq"
  SERVICE_BROKER_SLUG="pcf-service-broker-for-aws"
  SCS_SLUG="p-spring-cloud-services"
  PCC_SLUG="cloud-cache"
  PUSH_SLUG="push-notification-service"
  SSO_SLUG="p-identity"
  ISOLATION_SLUG="isolation-segment"
  SCHEDULER_SLUG="p-scheduler-for-pcf"
  WINDOWS_SLUG="runtime-for-windows"
}
