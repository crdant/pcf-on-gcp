#!/usr/bin/env bash
# install PCF and related products

BASEDIR=`dirname $0`
GCPDIR="${BASEDIR}/../pcf-on-gcp"
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/personal.sh"
. "${GCPDIR}/lib/login_ops_manager.sh"
. "${BASEDIR}/lib/ops_manager.sh"
. "${BASEDIR}/lib/elastic_runtime.sh"
. "${BASEDIR}/lib/rabbitmq.sh"
. "${GCPDIR}/lib/eula.sh"
. "${BASEDIR}/lib/products.sh"
. "${GCPDIR}/lib/guid.sh"
. "${GCPDIR}/lib/networks_azs.sh"
. "${GCPDIR}/lib/properties.sh"
. "${GCPDIR}/lib/resources.sh"
. "${GCPDIR}/lib/credentials.sh"


init () {
  INSTALL_PCF=0
  INSTALL_MYSQL=0
  INSTALL_RABBIT=0
  INSTALL_REDIS=0
  INSTALL_SCS=0
  INSTALL_AWS=0
  INSTALL_PCC=0
  INSTALL_IPSEC=0
  INSTALL_PUSH=0
  INSTALL_ISOLATION=0
  INSTALL_WINDOWS=0
  INSTALL_SCHEDULER=0
  INSTALL_STACKDRIVER=0
}

parse_args () {
  if [ $# -eq 0 ] ; then
    set_defaults
  else
    while [ $# -gt 0 ] ; do
      product=$1
      case $product in
          "pcf")
            INSTALL_PCF=1
            ;;
          "mysql")
            INSTALL_MYSQL=1
            ;;
          "rabbit")
            INSTALL_RABBIT=1
            ;;
          "redis")
            INSTALL_REDIS=1
            ;;
          "scs")
            INSTALL_SCS=1
            ;;
          "gcp")
            INSTALL_GCP=1
            ;;
          "pcc")
            INSTALL_PCC=1
            ;;
          "scheduler")
            INSTALL_SCHEDULER=1
            ;;
          "notifications")
            INSTALL_PUSH=1
            ;;
          "ipsec")
            INSTALL_IPSEC=1
            ;;
          "isolation")
            INSTALL_ISOLATION=1
            ;;
          "windows")
            INSTALL_WINDOWS=1
            ;;
          "stackdriver")
            INSTALL_STACKDRIVER=1
            ;;
          "default")
            set_defaults
            ;;
          "all")
            INSTALL_PCF=1
            INSTALL_MYSQL=1
            INSTALL_RABBIT=1
            INSTALL_REDIS=1
            INSTALL_SCS=1
            INSTALL_GCP=1
            INSTALL_PCC=1
            INSTALL_SCHEDULER=1
            INSTALL_IPSEC=1
            INSTALL_PUSH=1
            INSTALL_ISOLATION=1
            INSTALL_WINDOWS=1
            INSTALL_STACKDRIVER=1
            ;;
          "--help")
            usage
            exit 1
            ;;
          *)
            usage
            exit 1
            ;;
      esac
      shift
    done
  fi

}

set_defaults () {
  INSTALL_PCF=1
  INSTALL_MYSQL=1
  INSTALL_RABBIT=1
  INSTALL_REDIS=1
  INSTALL_SCS=1
  INSTALL_AWS=1
  INSTALL_PCC=1
}

usage () {
  cmd=`basename $0`
  echo "$cmd [ pcf ] [isolation] [windows] [ mysql ] [ rabbit ] [ redis ] [ scs ] [ gcp ] [ pcc ] [ scheduler ] [ notifications ]"
}

products () {

  if [ "$INSTALL_PCF" -eq 1 ] ; then
    cloud_foundry
  fi

  if [ "$INSTALL_MYSQL" -eq 1 ] ; then
    mysql
  fi

  if [ "$INSTALL_RABBIT" -eq 1 ] ; then
    rabbit
  fi

  if [ "$INSTALL_REDIS" -eq 1 ] ; then
    redis
  fi

  if [ "$INSTALL_PCC" -eq 1 ] ; then
    cloud_cache
  fi

  if [ "$INSTALL_SCS" -eq 1 ] ; then
    spring_cloud_services
  fi

  if [ "$INSTALL_AWS" -eq 1 ] ; then
    service_broker
  fi

  if [ "$INSTALL_PUSH" -eq 1 ] ; then
    push_notifications
  fi

  if [ "$INSTALL_ISOLATION" -eq 1 ] ; then
    isolation_segments
  fi

  if [ "$INSTALL_WINDOWS" -eq 1 ] ; then
    windows
  fi

  if [ "$INSTALL_IPSEC" -eq 1 ] ; then
    echo "WARNING: Be sure to install the IPSec add-on before any other products"
    ipsec
  fi

}

stemcell () {
  login_ops_manager
  echo "Downloading latest product stemcell ${STEMCELL_VERSION}..."
  accept_eula "stemcells" "${STEMCELL_VERSION}" "yes"
  stemcell_file=`download_stemcell ${STEMCELL_VERSION}`
  echo "Uploading stemcell to Operations Manager..."
  upload_stemcell $stemcell_file
}

services_stemcell () {
  if [ -z "${SERVICES_STEMCELL_UPLOADED}" ] ; then
    login_ops_manager
    echo "Downloading stemcell ${SERVICES_STEMCELL_VERSION} for services..."
    accept_eula "stemcells" "${SERVICES_STEMCELL_VERSION}" "yes"
    stemcell_file=`download_stemcell ${SERVICES_STEMCELL_VERSION}`
    echo "Uploading stemcell ($stemcell_file) to Operations Manager..."
    upload_stemcell $stemcell_file
    SERVICE_STEMCELL_UPLOADED="yes"
  fi
}

cloud_foundry () {
  add_to_install "Cloud Foundry Elastic Runtime" "${PCF_SLUG}" "${PCF_VERSION}" "${PCF_OPSMAN_SLUG}"
  store_var PCF_GUID "${guid}"
  stemcell

  # configure the elastic runtime
  set_networks_azs "${PCF_OPSMAN_SLUG}"
  set_pcf_domains
  set_pcf_networking
  set_pcf_containers
  set_pcf_security_acknowledgement
  set_pcf_rds_database
  set_pcf_advanced_features

  # set the load balancers resource configuration
  ROUTER_RESOURCES=`get_resources cf router`
  ROUTER_LBS="[ \"tcp:$WS_LOAD_BALANCER_NAME\", \"http:$HTTP_LOAD_BALANCER_NAME\" ]"
  ROUTER_RESOURCES=`echo $ROUTER_RESOURCES | jq ".elb_names = $ROUTER_LBS"`
  set_resources cf router "${ROUTER_RESOURCES}"

  TCP_ROUTER_RESOURCES=`get_resources cf tcp_router`
  TCP_ROUTER_LBS="[ \"tcp:$TCP_LOAD_BALANCER_NAME\" ]"
  TCP_ROUTER_RESOURCES=`echo $TCP_ROUTER_RESOURCES | jq ".elb_names = $TCP_ROUTER_LBS"`
  set_resources cf tcp_router "${TCP_ROUTER_RESOURCES}"

  BRAIN_RESOURCES=`get_resources cf diego_brain`
  BRAIN_LBS="[ \"tcp:$SSH_LOAD_BALANCER_NAME\" ]"
  BRAIN_RESOURCES=`echo $BRAIN_RESOURCES | jq ".elb_names = $BRAIN_LBS"`
  set_resources cf diego_brain "${BRAIN_RESOURCES}"
}

mysql () {
  add_to_install "MYSQL Broker" "${MYSQL_SLUG}" "${MYSQL_VERSION}"
  store_var MYSQL_GUID "${GUID}"
  set_networks_azs "${MYSQL_SLUG}"
  services_stemcell
}

rabbit () {
  add_to_install "Rabbit MQ Broker" "${RABBIT_SLUG}" "${RABBIT_VERSION}"
  store_var RABBIT_GUID "${GUID}"
  set_networks_azs "${RABBIT_SLUG}"
  set_rabbit_config
  set_rabbit_single_node_plan
  services_stemcell
}

redis () {
  add_to_install "Redis Service Broker" "${REDIS_SLUG}" "${REDIS_VERSION}"
  store_var REDIS_GUID "${GUID}"
  set_networks_azs "${REDIS_SLUG}"
  services_stemcell
}

cloud_cache () {
  add_to_install "Spring Cloud Services" "${PCC_SLUG}" "${PCC_VERSION}"
  store_var PCC_GUID "${GUID}"
  set_networks_azs "${PCC_SLUG}"
  services_stemcell
}

spring_cloud_services () {
  add_to_install "Spring Cloud Services" "${SCS_SLUG}" "${SCS_VERSION}"
  store_var SCS_GUID "${GUID}"
  set_networks_azs "${SCS_SLUG}"
  services_stemcell
}

service_broker () {
  add_to_install "AWS Service Broker" "${SERVICE_BROKER_SLUG}" "${SERVICE_BROKER_VERSION}"
  store_var SERVICE_BROKER_GUID "${GUID}"

  # since sed works a line at a time, translate newlines to a character that isn't Base64, then
  # replace that character with an escaped newline
  CLIENT_KEY=`cat "${KEYDIR}/gcp-service-broker-db-client.key" | tr '\n' '%' | sed 's/%/\\\n/g'`
  CLIENT_CERT=`cat "${KEYDIR}/gcp-service-broker-db-client.crt" | tr '\n' '%' | sed 's/%/\\\n/g'`
  SERVER_CERT=`cat "${KEYDIR}/gcp-service-broker-db-server.crt" | tr '\n' '%' | sed 's/%/\\\n/g'`
  SERVICE_ACCOUNT_CREDENTIALS=`cat "${KEYDIR}/${PROJECT}-service-broker-${SUBDOMAIN_TOKEN}.json" | jq -c '.' | sed 's/\"/\\\"/g'`
  BROKER_DB_HOST=`cat "${WORKDIR}/gcp-service-broker-db.ip"`

  set_networks_azs "gcp-service-broker"

  PROPERTIES_JSON=`export SERVICE_ACCOUNT_CREDENTIALS BROKER_DB_HOST BROKER_DB_USER BROKER_DB_USER_PASSWORD CLIENT_KEY CLIENT_CERT SERVER_CERT ; envsubst < api-calls/gcp-service-broker-properties.json ; unset SERVICE_ACCOUNT_CREDENTIALS BROKER_DB_HOST BROKER_DB_USER BROKER_DB_USER_PASSWORD CLIENT_KEY CLIENT_CERT SERVER_CERT`
  set_properties "gcp-service-broker" "${PROPERTIES_JSON}"

}

windows () {
  add_to_install "Runtime for Windows" "${WINDOWS_SLUG}" "${WINDOWS_VERSION}"
  store_var WINDOWS_GUID "${GUID}"
  windows_stemcell
}

windows_stemcell () {
  login_ops_manager
  echo "Downloading latest Windows stemcell ${WINDOWS_STEMCELL_VERSION}..."
  accept_eula "stemcells-windows-server" ${WINDOWS_STEMCELL_VERSION} "yes"
  stemcell_file=`download_stemcell ${WINDOWS_STEMCELL_VERSION}`
  echo "Uploading Windows stemcell to Operations Manager..."
  upload_stemcell $stemcell_file
}

push_notifications () {
  add_to_install "Push Notifications" "${PUSH_SLUG}" "${PUSH_VERSION}"
  store_var PUSH_GUID "${GUID}"
  set_networks_azs "${PUSH_SLUG}"
}

isolation_segments () {
  add_to_install "Isolation Segments" "${ISOLATION_SLUG}" "${ISOLATION_VERSION}"
  store_var ISOLATION_GUID "${GUID}"
  set_networks_azs "${ISOLATION_SLUG}"
}

scheduler () {
  add_to_install "Isolation Segments" "${SCHEDULER_SLUG}" "${SCHEDULER_VERSION}"
  store_var SCHEDULER_GUID "${GUID}"
  set_networks_azs "${SCHEDULER_SLUG}"
}


stackdriver () {
  add_to_install "Stackdriver Nozzle" "${STACKDRIVER_SLUG}" "${STACKDRIVER_VERSION_NUM}"
  store_var STACKDRIVER_GUID "${GUID}"

  # create UAA user
  uaac target "https://uaa.${PCF_SYSTEM_DOMAIN}" --skip-ssl-validation
  # NOTE: the secret being set here will not work, it is not correct and the correct one does not appear
  #       to be available without decoding installation.yml...stay tuned
  local uaa_admin_secret=`get_credential cf .uaa.admin_client_credentials`
  uaac token client get admin -s "${uaa_admin_secret}"
  uaac -t user add stackdriver-nozzle --password ${STACKDRIVER_NOZZLE_PASSWORD} --emails na
  # these probably need Cloud Foundry installed before you can do anything with them
  uaac -t member add cloud_controller.admin_read_only stackdriver-nozzle
  uaac -t member add doppler.firehose stackdriver-nozzle
}

ipsec () {
  accept_eula "p-ipsec-addon" "${IPSEC_VERSION}" "yes"
  echo "Downloading IPSec Add-on..."
  addon_file=`download_addon "p-ipsec-addon" "${IPSEC_VERSION}"`
  echo "Uploading IPSec Add-on to the BOSH Director..."
  upload_addon $addon_file
}

add_to_install() {
  product_name=${1}
  pivnet_slug="${2}"
  version="${3}"
  opsman_slug="${4}"

  if [ -z "${opsman_slug}" ] ; then
    opsman_slug="${2}"
  fi

  if product_not_available "${pivnet_slug}" "${version}" ; then
    # download the broker and make it available
    accept_eula "${pivnet_slug}" "${version}" "yes"
    echo "Downloading ${product_name}..."
    tile_file=`download_tile "${pivnet_slug}" "${version}"`
    echo "Uploading ${product_name}..."
    upload_tile $tile_file
  fi
  echo "Staging ${product_name} (${opsman_slug})..."
  stage_product "${opsman_slug}" "${version}"
  GUID=`product_guid "${opsman_slug}"`
}

START_TIMESTAMP=`date`
START_SECONDS=`date +%s`
init
parse_args $@
prepare_env
set_versions
echo "Started installing Cloud Foundry components on Amazon Web Services for ${SUBDOMAIN} at ${START_TIMESTAMP}..."
login_ops_manager
products
END_TIMESTAMP=`date`
END_SECONDS=`date +%s`
ELAPSED_TIME=`echo $((END_SECONDS-START_SECONDS)) | awk '{print int($1/60)":"int($1%60)}'`
echo "Completed installing Cloud Foundry components in Amazon Web Services for ${SUBDOMAIN} at ${END_TIMESTAMP} (elapsed time ${ELAPSED_TIME})."
