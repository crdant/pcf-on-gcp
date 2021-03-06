# make the environment for these scripts available in your current shell
if [ -n "$ZSH_VERSION" ]; then
  BASEDIR=`dirname ${(%):-%N}`
elif [ -n "$BASH_VERSION" ]; then
  BASEDIR=`dirname ${BASH_SOURCE[0]}`
else
  # doesn't likely work but it's something to set it as
  BASEDIR=`dirname $0`
fi

. "${BASEDIR}/lib/util.sh"
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/personal.sh"
. "${BASEDIR}/lib/credentials.sh"
. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/lib/eula.sh"
. "${BASEDIR}/lib/generate_passphrase.sh"
. "${BASEDIR}/lib/ssl_certificates.sh"
. "${BASEDIR}/lib/guid.sh"
. "${BASEDIR}/lib/jobs.sh"
. "${BASEDIR}/lib/login_ops_manager.sh"
. "${BASEDIR}/lib/networks_azs.sh"
. "${BASEDIR}/lib/products.sh"
. "${BASEDIR}/lib/properties.sh"
. "${BASEDIR}/lib/random_phrase.sh"
. "${BASEDIR}/lib/resources.sh"
. "${BASEDIR}/lib/assets.sh"
. "${BASEDIR}/lib/setup.sh"
. "${BASEDIR}/lib/elastic_runtime.sh"
. "${BASEDIR}/lib/ops_manager.sh"
. "${BASEDIR}/lib/director.sh"

prepare_env
overrides


export ACCOUNT
export PROJECT
export DOMAIN

export REGION_1
export AVAILABILITY_ZONE_1
export AVAILABILITY_ZONE_2
export AVAILABILITY_ZONE_3
export STORAGE_LOCATION

export DOMAIN_TOKEN
export SUBDOMAIN
export DNS_ZONE
export DNS_TTL
export CIDR
export SERVICES_CIDR
export ALL_INTERNET
export KEYDIR
export WORKDIR
export PASSWORD_LIST

export PCF_SYSTEM_DOMAIN
export PCF_APPS_DOMAIN
export OPS_MANAGER_HOST
export OPS_MANAGER_FQDN
export OPS_MANAGER_API_ENDPOINT
export DIRECTOR_NETWORK_NAME
export SERVICES_NETWORK_NAME
export SERVICE_ACCOUNT

export BUILDPACKS_STORAGE_BUCKET
export DROPLETS_STORAGE_BUCKET
export PACKAGES_STORAGE_BUCKET
export RESOURCES_STORAGE_BUCKET

export OPS_MANAGER_VERSION
export OPS_MANAGER_VERSION_TOKEN
export PCF_VERSION
export STEMCELL_VERSION
export MYSQL_VERSION
export RABBIT_VERSION
export REDIS_VERSION
export GCP_VERSION
export GCP_VERSION_TOKEN
export GCP_VERSION_NUM
export SCS_VERSION
export GEM_VERSION
export CONCOURSE_VERSION
export IPSEC_VERSION
export PUSH_VERSION
export STACKDRIVER_VERSION
export STACKDRIVER_VERSION_TOKEN
export STACKDRIVER_VERSION_NUM

# versions
export OPS_MANAGER_VERSION
export OPS_MANAGER_VERSION_TOKEN
export PCF_VERSION
export STEMCELL_VERSION
export MYSQL_VERSION
export RABBIT_VERSION
export REDIS_VERSION
export PCC_VERSION
export SCS_VERSION
export SERVICE_BROKER_VERSION
export WINDOWS_VERSION
export ISOLATION_VERSION
export IPSEC_VERSION
export PUSH_VERSION
export SSO_VERSION
export SCHEDULER_VERSION

# slugs
export PCF_SLUG
export PCF_OPSMAN_SLUG
export OPS_MANAGER_SLUG
export MYSQL_SLUG
export REDIS_SLUG
export RABBIT_SLUG
export SERVICE_BROKER_SLUG
export SCS_SLUG
export PCC_SLUG
export PUSH_SLUG
export SSO_SLUG
export IPSEC_SLUG
export ISOLATION_SLUG
export SCHEDULER_SLUG
export WINDOWS_SLUG
export STACKDRIVER_SLUG
export SCHEDULER_SLUG

export SSH_LOAD_BALANCER_NAME
export HTTP_LOAD_BALANCER_NAME
export WS_LOAD_BALANCER_NAME
export TCP_LOAD_BALANCER_NAME

export ADMIN_PASSWORD
export DECRYPTION_PASSPHRASE
export DB_ROOT_PASSWORD
export BROKER_DB_USER_PASSWORD
export RABBIT_ADMIN_PASSWORD
export STACKDRIVER_NOZZLE_PASSWORD
