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

  SERVICE_ACCOUNT_NAME=`name_service_account pcf-deployment`
  SERVICE_ACCOUNT="${SERVICE_ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com"
  BROKER_SERVICE_ACCOUNT_NAME=`name_service_account service-broker`
  BROKER_SERVICE_ACCOUNT="${BROKER_SERVICE_ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com"
  NOZZLE_SERVICE_ACCOUNT_NAME=`name_service_account nozzle`
  NOZZLE_SERVICE_ACCOUNT="${NOZZLE_SERVICE_ACCOUNT_NAME}@${PROJECT}.iam.gserviceaccount.com"

  DNS_ZONE="${SUBDOMAIN}"
  DNS_TTL=60

  DNS_ZONE=`echo ${SUBDOMAIN} | tr . -`
  DNS_TTL=60
  CIDR="10.0.0.0/12"
  ALL_INTERNET="0.0.0.0/0"
  KEYDIR="${BASEDIR}/keys"
  WORKDIR="${BASEDIR}/work"
  PASSWORD_LIST="${KEYDIR}/password-list"
  ENV_OUTPUTS="${WORKDIR}/installed-env.sh"

  DNS_SERVERS="8.8.8.8,8.8.4.4"
  INFRASTRUCTURE_CIDR="10.0.0.0/26"
  INFRASTRUCTURE_RESERVED="10.0.0.1"
  INFRASTRUCTURE_GATEWAY="10.0.0.1-10.0.0.10"
  DEPLOYMENT_CIDR="10.1.0.0/22"
  DEPLOYMENT_RESERVED="10.1.0.1"
  DEPLOYMENT_GATEWAY="10.1.0.1-10.1.0.9"
  TILES_CIDR="10.2.0.0/22"
  TILES_RESERVED="10.2.0.1"
  TILES_GATEWAY="10.2.0.1-10.2.0.9"
  SERVICES_CIDR="10.3.0.0/22"
  SERVICES_RESERVED="10.3.0.1"
  SERVICES_GATEWAY="10.3.0.1-10.3.0.9"

  PCF_SYSTEM_DOMAIN=system.${SUBDOMAIN}
  PCF_APPS_DOMAIN=apps.${SUBDOMAIN}
  OPS_MANAGER_HOST="manager"
  OPS_MANAGER_FQDN="${OPS_MANAGER_HOST}.${SUBDOMAIN}"
  OPS_MANAGER_API_ENDPOINT="https://${OPS_MANAGER_FQDN}/api/v0"
  INFRASTRUCTURE_NETWORK_NAME="gcp-${REGION_1}-infrastructure"
  DEPLOYMENT_NETWORK_NAME="gcp-${REGION_1}-deployment"
  TILES_NETWORK_NAME="gcp-${REGION_1}-tiles"
  SERVICES_NETWORK_NAME="gcp-${REGION_1}-services"

  BUILDPACKS_STORAGE_BUCKET="buildpacks-pcf-${SUBDOMAIN_TOKEN}"
  DROPLETS_STORAGE_BUCKET="droplets-pcf-${SUBDOMAIN_TOKEN}"
  PACKAGES_STORAGE_BUCKET="packages-pcf-${SUBDOMAIN_TOKEN}"
  RESOURCES_STORAGE_BUCKET="resources-pcf-${SUBDOMAIN_TOKEN}"

  SSH_LOAD_BALANCER_NAME="pcf-ssh-${SUBDOMAIN_TOKEN}"
  HTTP_LOAD_BALANCER_NAME="pcf-http-router-${SUBDOMAIN_TOKEN}"
  WS_LOAD_BALANCER_NAME="pcf-websockets-${SUBDOMAIN_TOKEN}"
  TCP_LOAD_BALANCER_NAME="pcf-tcp-router-${SUBDOMAIN_TOKEN}"

  BROKER_DB_USER="pcf"

  # set variables for passwords if they are available
  if [ -e ${PASSWORD_LIST} ] ; then
    . ${PASSWORD_LIST}
  fi

  # set variables for various created elements
  if [ -e "${ENV_OUTPUTS}" ] ; then
    . ${ENV_OUTPUTS}
  fi
}

set_versions () {
  OPS_MANAGER_VERSION="1.11.1"
  OPS_MANAGER_VERSION_TOKEN=`echo ${OPS_MANAGER_VERSION} | tr . -`
  PCF_VERSION="1.11.0"
  STEMCELL_VERSION="3421.3"
  SERVICES_STEMCELL_VERSION="3363.25"

  MYSQL_VERSION="2.0.0"
  RABBIT_VERSION="1.8.7"
  REDIS_VERSION="1.8.2"
  PCC_VERSION="1.0.4"
  SCS_VERSION="1.4.0"
  SERVICE_BROKER_VERSION="3.4.1"
  WINDOWS_VERSION="1.11.0"
  ISOLATION_VERSION="1.11.0"
  IPSEC_VERSION="1.6.3"
  PUSH_VERSION="1.9.0"
  SSO_VERSION="1.4.2"
  SCHEDULER_VERSION="1.0.2-beta"
  STACKDRIVER_VERSION="1.0.3"
  STACKDRIVER_VERSION_TOKEN=`echo ${STACKDRIVER_VERSION} | tr . - | tr ' ' - | tr -d ')' | tr -d '(' | tr '[:upper:]' '[:lower:]'`
}

product_slugs () {
  PCF_SLUG="elastic-runtime"
  PCF_OPSMAN_SLUG="cf"
  OPS_MANAGER_SLUG="ops-manager"
  MYSQL_SLUG="pivotal-mysql"
  REDIS_SLUG="p-redis"
  RABBIT_SLUG="p-rabbitmq"
  SERVICE_BROKER_SLUG="gcp-service-broker"
  SCS_SLUG="p-spring-cloud-services"
  PCC_SLUG="cloud-cache"
  PUSH_SLUG="push-notification-service"
  SSO_SLUG="p-identity"
  IPSEC_SLUG="p-ipsec-addon"
  ISOLATION_SLUG="isolation-segment"
  SCHEDULER_SLUG="p-scheduler-for-pcf"
  WINDOWS_SLUG="runtime-for-windows"
  STACKDRIVER_SLUG="gcp-stackdriver-nozzle"
}


store_var () {
  variable="${1}"
  value="${2}"

  if [ -z "${value}" ] ; then
    code="echo \$${variable}"
    value=`eval $code`
  fi

  eval "$variable=${value}"
  echo "$variable=${value}" >> "${ENV_OUTPUTS}"
}

store_json_var () {
  json="${1}"
  variable="${2}"
  jspath="${3}"

  value=`echo "${json}" | jq --raw-output "${jspath}"`
  store_var ${variable} ${value}
}
