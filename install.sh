#!/usr/bin/env bash
# install PCF and related products

. lib/env.sh
. personal.sh
. lib/setup.sh
. lib/login_ops_manager.sh
. lib/eula.sh
. lib/download_product.sh
. lib/upload_product.sh
. lib/stage_product.sh
. lib/product_guid.sh

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
  echo "$cmd [ pcf ] [ mysql ] [ rabbit ] [ redis ] [ scs ] [ gcp ] [ gemfire ] [ concourse ]"
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

}

cloud_foundry () {
  PCF_RELEASES_URL="https://network.pivotal.io/api/v2/products/elastic-runtime/releases"
  ERT_TILE_FILE="$TMPDIR/cf-${PCF_VERSION}.pivotal"

  accept_eula "elastic-runtime" $PCF_VERSION "yes"
  echo "Downloading Cloud Foundry Elastic Runtime..."
  tile_file=`download_product "elastic-runtime" $PCF_VERSION`
  echo "Uploading Cloud Foundry Elastic Runtime..."
  upload_product $TILE_FILE
  echo "Staging Cloud Foundry Elastic Runtime..."
  stage_product "cf"
  PCF_GUID=`product_guid "cf"`

  # set the load balancers resource configuration
  ROUTER_GUID=`curl -qs --insecure "https://manager.${SUBDOMAIN}/api/v0/staged/products/${PCF_GUID}/jobs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" | jq --raw-output '.jobs [] | select ( .name == "router" ) .guid'`
  ROUTER_RESOURCES=`curl -qs --insecure "https://manager.${SUBDOMAIN}/api/v0/staged/products/${PCF_GUID}/jobs/${ROUTER_GUID}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"`
  ROUTER_LBS="[ \"tcp:$WS_LOAD_BALANCER_NAME\", \"http:$HTTP_LOAD_BALANCER_NAME\" ]"
  curl -qs --insecure -X PUT "https://manager.${SUBDOMAIN}/api/v0/staged/products/${PCF_GUID}/jobs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" -d `echo $ROUTER_RESOURCES | jq ".elb_names = $ROUTER_LBS"`

  TCP_ROUTER_GUID=`curl -qs --insecure "https://manager.${SUBDOMAIN}/api/v0/staged/products/${PCF_GUID}/jobs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" | jq --raw-output '.jobs [] | select ( .name == "tcp_router" ) .guid'`
  TCP_ROUTER_RESOURCES=`curl -qs --insecure "https://manager.${SUBDOMAIN}/api/v0/staged/products/${PCF_GUID}/jobs/${TCP_ROUTER_GUID}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"`
  TCP_ROUTER_LBS="[ \"tcp:$TCP_LOAD_BALANCER_NAME\" ]"
  curl -qs --insecure -X PUT "https://manager.${SUBDOMAIN}/api/v0/staged/products/${PCF_GUID}/jobs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" -d `echo $TCP_ROUTER_RESOURCES | jq ".elb_names = $ROUTER_LBS"`

  BRAIN_GUID=`curl -qs --insecure "https://manager.${SUBDOMAIN}/api/v0/staged/products/${PCF_GUID}/jobs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" | jq --raw-output '.jobs [] | select ( .name == "diego_brain" ) .guid'`
  BRAIN_RESOURCES=`curl -qs --insecure "https://manager.${SUBDOMAIN}/api/v0/staged/products/${PCF_GUID}/jobs/${BRAIN_GUID}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"`
  BRAIN_LBS="[ \"tcp:$SSH_LOAD_BALANCER_NAME\" ]"
  curl -qs --insecure -X PUT "https://manager.${SUBDOMAIN}/api/v0/staged/products/${PCF_GUID}/jobs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" -d `echo $BRAIN_RESOURCES | jq ".elb_names = $BRAIN_LBS"`

}

mysql () {
  accept_eula "p-mysql" $MYSQL_VERSION "yes"
  echo "Downloading MySQL Service..."
  tile_file=`download_product "p-mysql" $MYSQL_VERSION`
  echo "Uploading MySQL Service..."
  upload_product $TILE_FILE
  echo "Staging MySQL Service..."
  stage_product "p-mysql"
  MYSQL_GUID=`product_guid "p-mysql"`
}

rabbit () {
  accept_eula "pivotal-rabbitmq-service" $RABBIT_VERSION "yes"
  echo "Downloading Rabbit MQ Service..."
  tile_file=`download_product "pivotal-rabbitmq-service" $RABBIT_VERSION`
  echo "Uploading Rabbit MQ Service..."
  upload_product $TILE_FILE
  echo "Staging Rabbit MQ Service..."
  stage_product "p-rabbitmq"
  RABBIT_GUID=`product_guid "p-rabbitmq"`
}

redis () {
  accept_eula "p-redis" $REDIS_VERSION "yes"
  echo "Downloading REDIS Service..."
  tile_file=`download_product "pivotal-rabbitmq-service" $REDIS_VERSION`
  echo "Uploading REDIS Service..."
  upload_product $TILE_FILE
  echo "Staging REDIS Service..."
  stage_product "p-redis"
  REDIS_GUID=`product_guid "p-redis"`
}

spring_cloud_services () {
  accept_eula "p-spring-cloud-services" $SCS_VERSION "yes"
  echo "Downloading Spring Cloud Services..."
  tile_file=`download_product "p-spring-cloud-services" $SCS_VERSION`
  echo "Uploading Spring Cloud Services..."
  upload_product $TILE_FILE
  echo "Staging Spring Cloud Services..."
  stage_product "p-spring-cloud-services"
  SCS_GUID=`product_guid "p-spring-cloud-services"`
}

service_broker () {
  # download the broker and make it available
  accept_eula "gcp-service-broker" $GCP_VERSION "yes"
  echo "Downloading GCP Service Broker..."
  tile_file=`download_product "p-spring-cloud-services" $GCP_VERSION`
  echo "Uploading GCP Service Broker..."
  upload_product $TILE_FILE
  echo "Staging GCP Service Broker..."
  stage_product "gcp-service-broker"
  GCP_GUID=`product_guid "gcp-service-broker"`
}

gemfire () {
  accept_eula "p-gemfire" $GEM_VERSION "yes"
  echo "Downloading Gemfire..."
  tile_file=`download_product "p-gemfire" $GEM_VERSION`
  echo "Uploading Gemfire..."
  upload_product $TILE_FILE
  echo "Staging Gemfire..."
  stage_product "p-gemfire"
  GEM_GUID=`product_guid "p-gemfire"`
}

concourse () {
  accept_eula "p-concourse" $CONCOURSE_VERSION "yes"
  echo "Downloading Concourse..."
  tile_file=`download_product "p-concourse" $CONCOURSE_VERSION`
  echo "Uploading Concourse..."
  upload_product $TILE_FILE
  echo "Staging Concourse..."
  stage_product "p-concourse"
  CONCOURSE_GUID=`product_guid "p-concourse"`
}

parse_args $@
env
setup
login_ops_manager
products
