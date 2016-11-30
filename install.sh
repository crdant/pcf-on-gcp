#!/usr/bin/env bash
# install PCF and related products

. lib/env.sh
. personal.sh
. lib/login_ops_manager.sh
. lib/eula.sh
. lib/download_product.sh
. lib/upload_product.sh
. lib/stage_product.sh
. lib/product_guid.sh

products () {
  cloud_foundry
  mysql
  rabbit
  redis
  spring_cloud_services
  service_broker
}

cloud_foundry () {
  PCF_RELEASES_URL="https://network.pivotal.io/api/v2/products/elastic-runtime/releases"
  ERT_TILE_FILE="$TMPDIR/cf-${PCF_VERSION}.pivotal"

  accept_eula "elastic-runtime" $PCF_VERSION "yes"
  echo "Downloading Cloud Foundry Elastic Runtime..."
  tile_file=`download_product "elastic-runtime" $PCF_VERSION`
  echo "Uploading Cloud Foundry Elastic Runtime..."
  upload_product $tile_file
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

  # provide the necessary DNS records for the internal MySQL database
  gcloud dns record-sets transaction start -z "${DNS_ZONE}"
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "mysql.${SUBDOMAIN}" --ttl "${DNS_TTL}" --type A "10.0.15.98" "10.0.15.99"
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}"

}

mysql () {
  accept_eula "p-mysql" $MYSQL_VERSION "yes"
  echo "Downloading MySQL Service..."
  tile_file=`download_product "p-mysql" $MYSQL_VERSION`
  echo "Uploading MySQL Service..."
  upload_product $tile_file
  echo "Staging MySQL Service..."
  stage_product "p-mysql"
  MYSQL_GUID=`product_guid "p-mysql"`
}

rabbit () {
  accept_eula "pivotal-rabbitmq-service" $RABBIT_VERSION "yes"
  echo "Downloading Rabbit MQ Service..."
  tile_file=`download_product "pivotal-rabbitmq-service" $RABBIT_VERSION`
  echo "Uploading Rabbit MQ Service..."
  upload_product $tile_file
  echo "Staging Rabbit MQ Service..."
  stage_product "p-rabbitmq"
  RABBIT_GUID=`product_guid "p-rabbitmq"`
}

redis () {
  accept_eula "p-redis" $REDIS_VERSION "yes"
  echo "Downloading REDIS Service..."
  tile_file=`download_product "pivotal-rabbitmq-service" $REDIS_VERSION`
  echo "Uploading REDIS Service..."
  upload_product $tile_file
  echo "Staging REDIS Service..."
  stage_product "p-redis"
  REDIS_GUID=`product_guid "p-redis"`
}

spring_cloud_services () {
  accept_eula "p-redis" $SCS_VERSION "yes"
  echo "Downloading Spring Cloud Services..."
  tile_file=`download_product "p-spring-cloud-services" $SCS_VERSION`
  echo "Uploading Spring Cloud Services..."
  upload_product $tile_file
  echo "Staging Spring Cloud Services..."
  stage_product "p-spring-cloud-services"
  SCS_GUID=`product_guid "p-spring-cloud-services"`
}

service_broker () {
  # prepare for the google service broker
  gcloud iam service-accounts create "service-broker-${DOMAIN_TOKEN}" --display-name bosh
  gcloud iam service-accounts keys create ${PROJECT}-service-broker-${DOMAIN_TOKEN}.json --iam-account service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/owner"
  gcloud sql --project="${PROJECT}" instances create "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" --assign-ip --require-ssl --authorized-networks="${ALL_INTERNET}" --region=${REGION_1}  --gce-zone=${AVAILABILITY_ZONE_1}
  gcloud sql --project="${PROJECT}" instances set-root-password "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" --password="crest-tory-hump-anode"
  # server connection requirements
  gcloud --format json sql --project="${PROJECT}" instances describe "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" | jq --raw-output '.serverCaCert .cert ' > gcp-service-broker-db-server.crt
  gcloud --format json sql --project="${PROJECT}" instances describe "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" | jq --raw-output ' .ipAddresses [0] .ipAddress ' > gcp-service-broker-db.ip
  # client connection requirements
  gcloud sql --project="${PROJECT}" ssl-certs create "pcf.${SUBDOMAIN}" gcp-service-broker-db-client.key --instance "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}"
  gcloud sql --project="${PROJECT}" --format=json ssl-certs describe "pcf.${SUBDOMAIN}" --instance "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" | jq --raw-output ' .cert ' > gcp-service-broker-db-client.crt
  # setup a user
  gcloud beta sql --project="${PROJECT}" users create "pcf" "%" --password "arachnid-souvenir-brunch" --instance "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}"

  # setup a database for the servicebroker
  GCP_AUTH_TOKEN=`gcloud auth application-default print-access-token`
  curl -q -X POST "https://www.googleapis.com/sql/v1beta4/projects/fe-cdantonio/instances/gcp-service-broker-2-0-1-crdant-io/databases" \
    -H "Authorization: Bearer $GCP_AUTH_TOKEN" -H 'Content-Type: application/json' -d '{ "instance": "gcp-service-broker-2-0-1-crdant-io", "name": "servicebroker", "project": "fe-cdantonio" }'

  # setup a database and add permissions for the servicebroker user
  mysql -uroot -pcrest-tory-hump-anode -h `cat gcp-service-broker-db.ip` --ssl-ca=gcp-service-broker-db-server.crt \
    --ssl-cert=gcp-service-broker-db-client.crt --ssl-key=gcp-service-broker-db-client.key <<SQL
  GRANT ALL PRIVILEGES ON servicebroker.* TO 'pcf'@'%' WITH GRANT OPTION;
SQL

  # download the broker and make it available
  accept_eula "gcp-service-broker" $GCP_VERSION "yes"
  echo "Downloading GCP Service Broker..."
  tile_file=`download_product "p-spring-cloud-services" $GCP_VERSION`
  echo "Uploading GCP Service Broker..."
  upload_product $tile_file
  echo "Staging GCP Service Broker..."
  stage_product "gcp-service-broker"
  GCP_GUID=`product_guid "gcp-service-broker"`
}

env
setup
login_ops_manager
products
