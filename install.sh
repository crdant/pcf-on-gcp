#!/usr/bin/env bash
# install PCF and related products

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/personal.sh"
. "${BASEDIR}/lib/setup.sh"
. "${BASEDIR}/lib/login_ops_manager.sh"
. "${BASEDIR}/lib/eula.sh"
. "${BASEDIR}/lib/download_product.sh"
. "${BASEDIR}/lib/upload_product.sh"
. "${BASEDIR}/lib/stage_product.sh"
. "${BASEDIR}/lib/product_guid.sh"

init () {
  INSTALL_PCF=0
  INSTALL_MYSQL=0
  INSTALL_RABBIT=0
  INSTALL_REDIS=0
  INSTALL_SCS=0
  INSTALL_GCP=0
  INSTALL_GEMFIRE=0
  INSTALL_CONCOURSE=0
  INSTALL_IPSEC=0
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
          "gemfire")
            INSTALL_GEMFIRE=1
            ;;
          "concourse")
            INSTALL_CONCOURSE=1
            ;;
          "ipsec")
            INSTALL_IPSEC=1
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
            INSTALL_GEMFIRE=1
            INSTALL_CONCOURSE=1
            INSTALL_IPSEC=1
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
  INSTALL_GCP=1
}

usage () {
  cmd=`basename $0`
  echo "$cmd [ pcf ] [ mysql ] [ rabbit ] [ redis ] [ scs ] [ gcp ] [ gemfire ] [ concourse ] [ ipsec ]"
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

  if [ "$INSTALL_SCS" -eq 1 ] ; then
    spring_cloud_services
  fi

  if [ "$INSTALL_GCP" -eq 1 ] ; then
    service_broker
  fi

  if [ "$INSTALL_GEMFIRE" -eq 1 ] ; then
    gemfire
  fi

  if [ "$INSTALL_CONCOURSE" -eq 1 ] ; then
    concourse
  fi

  if [ "$INSTALL_IPSEC" -eq 1 ] ; then
    echo "WARNING: Be sure to install the IPSec add-on before any other products"
    ipsec
  fi

}

cloud_foundry () {
  accept_eula "elastic-runtime" "${PCF_VERSION}" "yes"
  echo "Downloading Cloud Foundry Elastic Runtime..."
  tile_file=`download_product "elastic-runtime" "${PCF_VERSION}"`
  echo "Uploading Cloud Foundry Elastic Runtime..."
  upload_product $tile_file
  echo "Staging Cloud Foundry Elastic Runtime..."
  stage_product "cf"
  PCF_GUID=`product_guid "cf"`

  # configure BLOB storage locations
  PROPERTIES_JSON=`envsubst < api-calls/elastic_runtime_blobstore_properties.json`
  set_properties "cf" "${PROPERTIES_JSON}"

  # set the load balancers resource configuration
  ROUTER_GUID=`job_guid cf router`
  ROUTER_RESOURCES=`curl -qs --insecure "${OPS_MANAGER_API_ENDPOINT}/staged/products/${PCF_GUID}/jobs/${ROUTER_GUID}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"`
  ROUTER_LBS="[ \"tcp:$WS_LOAD_BALANCER_NAME\", \"http:$HTTP_LOAD_BALANCER_NAME\" ]"
  ROUTER_RESOURCES=`echo $ROUTER_RESOURCES | jq ".elb_names = $ROUTER_LBS"`
  curl -qs --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/products/${PCF_GUID}/jobs/${ROUTER_GUID}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" -d "${ROUTER_RESOURCES}"

  TCP_ROUTER_GUID=`job_guid cf tcp_router`
  TCP_ROUTER_RESOURCES=`curl -qs --insecure "${OPS_MANAGER_API_ENDPOINT}/staged/products/${PCF_GUID}/jobs/${TCP_ROUTER_GUID}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"`
  TCP_ROUTER_LBS="[ \"tcp:$TCP_LOAD_BALANCER_NAME\" ]"
  TCP_ROUTER_RESOURCES=`echo $TCP_ROUTER_RESOURCES | jq ".elb_names = $TCP_ROUTER_LBS"`
  curl -qs --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/products/${PCF_GUID}/jobs/${TCP_ROUTER_GUID}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" -d "${TCP_ROUTER_RESOURCES}"

  BRAIN_GUID=`job_guid cf diego_brain`
  BRAIN_RESOURCES=`curl -qs --insecure "${OPS_MANAGER_API_ENDPOINT}/staged/products/${PCF_GUID}/jobs/${BRAIN_GUID}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"`
  BRAIN_LBS="[ \"tcp:$SSH_LOAD_BALANCER_NAME\" ]"
  BRAIN_RESOURCES=`echo $BRAIN_RESOURCES | jq ".elb_names = $BRAIN_LBS"`
  curl -qs --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/products/${PCF_GUID}/jobs/${BRAIN_GUID}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" -d "${BRAIN_RESOURCES}"

}

mysql () {
  accept_eula "p-mysql" "${MYSQL_VERSION}" "yes"
  echo "Downloading MySQL Service..."
  tile_file=`download_product "p-mysql" "${MYSQL_VERSION}"`
  echo "Uploading MySQL Service..."
  upload_product $tile_file
  echo "Staging MySQL Service..."
  stage_product "p-mysql"
  MYSQL_GUID=`product_guid "p-mysql"`
}

rabbit () {
  accept_eula "pivotal-rabbitmq-service" "${RABBIT_VERSION}" "yes"
  echo "Downloading Rabbit MQ Service..."
  tile_file=`download_product "pivotal-rabbitmq-service" "${RABBIT_VERSION}"`
  echo "Uploading Rabbit MQ Service..."
  upload_product $tile_file
  echo "Staging Rabbit MQ Service..."
  stage_product "p-rabbitmq"
  RABBIT_GUID=`product_guid "p-rabbitmq"`
}

redis () {
  accept_eula "p-redis" "${REDIS_VERSION}" "yes"
  echo "Downloading REDIS Service..."
  tile_file=`download_product "pivotal-rabbitmq-service" "${REDIS_VERSION}"`
  echo "Uploading REDIS Service..."
  upload_product $tile_file
  echo "Staging REDIS Service..."
  stage_product "p-redis"
  REDIS_GUID=`product_guid "p-redis"`
}

spring_cloud_services () {
  accept_eula "p-spring-cloud-services" "${SCS_VERSION}" "yes"
  echo "Downloading Spring Cloud Services..."
  tile_file=`download_product "p-spring-cloud-services" "${SCS_VERSION}"`
  echo "Uploading Spring Cloud Services..."
  upload_product $tile_file
  echo "Staging Spring Cloud Services..."
  stage_product "p-spring-cloud-services"
  SCS_GUID=`product_guid "p-spring-cloud-services"`
}

service_broker () {
  # download the broker and make it available
  accept_eula "gcp-service-broker" "${GCP_VERSION}" "yes"
  echo "Downloading GCP Service Broker..."
  tile_file=`download_product "gcp-service-broker" "${GCP_VERSION}"`
  echo "Uploading GCP Service Broker..."
  upload_product $tile_file
  echo "Staging GCP Service Broker..."
  stage_product "gcp-service-broker"
  GCP_GUID=`product_guid "gcp-service-broker"`
}

gemfire () {
  accept_eula "p-gemfire" "${GEM_VERSION}" "yes"
  echo "Downloading Gemfire..."
  tile_file=`download_product "p-gemfire" "${GEM_VERSION}"`
  echo "Uploading Gemfire..."
  upload_product $tile_file
  echo "Staging Gemfire..."
  stage_product "p-gemfire"
  GEM_GUID=`product_guid "p-gemfire"`
}

concourse () {
  accept_eula "p-concourse" "${CONCOURSE_VERSION}" "yes"
  echo "Downloading Concourse..."
  tile_file=`download_product "p-concourse" "${CONCOURSE_VERSION}"`
  echo "Uploading Concourse..."
  upload_product $tile_file
  echo "Staging Concourse..."
  stage_product "p-concourse"
  CONCOURSE_GUID=`product_guid "p-concourse"`
}

ipsec () {
  accept_eula "p-ipsec-addon" "${IPSEC_VERSION}" "yes"
  echo "Downloading IPSec Add-on..."
  tile_file=`download_product "p-ipsec-addon" "${IPSEC_VERSION}"`
  echo "Uploading IPSec Add-on..."
  upload_product $tile_file
  echo "Staging IPSec Add-on..."
  stage_product "p-ipsec-addon"
  CONCOURSE_GUID=`product_guid "p-ipsec-addon"`
}

START_TIMESTAMP=`date`
START_SECONDS=`date +%s`
init
parse_args $@
env
echo "Started installing Cloud Foundry components in Google Cloud Platform project ${PROJECT} at ${START_TIMESTAMP}..."
setup
login_ops_manager
products
END_TIMESTAMP=`date`
END_SECONDS=`date +%s`
ELAPSED_TIME=`echo $((END_SECONDS-START_SECONDS)) | awk '{print int($1/60)":"int($1%60)}'`
echo "Completed installing Cloud Foundry components in Google Cloud Platform project ${PROJECT} at ${END_TIMESTAMP} (elapsed time ${ELAPSED_TIME})."
