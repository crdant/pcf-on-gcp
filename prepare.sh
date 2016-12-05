#!/usr/bin/env bash
# prepare to install PCF on GCP

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/personal.sh"
. "${BASEDIR}/lib/setup.sh"
. "${BASEDIR}/lib/login_ops_manager.sh"

network () {
  # create a network (parameterize the network name and project later)
  echo "Creating network, subnet, and firewall rules..."

  gcloud compute --project "${PROJECT}" networks create "pcf-${DOMAIN_TOKEN}" --description "Network for ${DOMAIN} Cloud Foundry installation. Creating with a single subnet." --mode "custom"

  # create a single subnet in us-east1 (parameterize REGION_1 and names later)
  gcloud compute --project "${PROJECT}" networks subnets create "pcf-${REGION_1}-${DOMAIN_TOKEN}" --network "pcf-${DOMAIN_TOKEN}" --region "${REGION_1}" --range ${CIDR}

  # create necessary firewall rules
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-allow-internal-traffic-${DOMAIN_TOKEN}" --allow "tcp:0-65535,udp:0-65535,icmp" --description "Enable traffic between all VMs managed by Ops Manager and BOSH" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${CIDR}
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-opsmanager-${DOMAIN_TOKEN}" --allow "tcp:22,tcp:80,tcp:443" --description "Allow web and SSH access to the Ops Manager" --network "pcf-${DOMAIN_TOKEN}" --source-ranges "${ALL_INTERNET}" --target-tags "pcf-opsmanager"
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-load-balancers-${DOMAIN_TOKEN}" --allow "tcp:80,tcp:443,tcp:2222,tcp:8080" --description "Allow web, log, and SSH access to the load balancers" --network "pcf-${DOMAIN_TOKEN}" --source-ranges "${ALL_INTERNET}" --target-tags "pcf-lb"
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-tcp-load-balancers-${DOMAIN_TOKEN}" --allow "tcp:1024-65535" --description "Allow access to load balancers for TCP routing" --network "pcf-${DOMAIN_TOKEN}" --source-ranges "${ALL_INTERNET}" --target-tags "pcf-tcp-lb"

  # create additional firewall rules that are not in the documentation but seem to be necessary based on my experiments
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-bosh-${DOMAIN_TOKEN}" --allow "tcp:22,tcp:80,tcp:443" --description "Allow web and SSH access from internal sources to the BOSH director" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${CIDR} --target-tags "bosh"
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-cloud-controller-${DOMAIN_TOKEN}" --allow "tcp:80,tcp:443" --description "Allow web access from internal sources to the cloud controller" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${CIDR} --target-tags "cloud-controller"

  echo "Google Network for BOSH Director: pcf-${DOMAIN_TOKEN}/pcf-${REGION_1}-${DOMAIN_TOKEN}/${REGION_1}"
}

security () {
  echo "Creating services accounts and SSH keys..."

  # create a service account and give it a key (parameterize later), not sure why it doesn't have a project specified but that seems right
  gcloud iam service-accounts create bosh-opsman-${DOMAIN_TOKEN} --display-name bosh
  gcloud iam service-accounts keys create "${KEYDIR}/${PROJECT}-bosh-opsman-${DOMAIN_TOKEN}.json" --iam-account bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/editor"
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/compute.instanceAdmin"
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/compute.networkAdmin"
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/compute.storageAdmin"

  # setup VCAP SSH for all boxen, this will erase existing SSH keys (FIX!)
  ssh-keygen -P "" -t rsa -f ${KEYDIR}/vcap-key -b 4096 -C vcap@local
  sed -i.gcp '1s/^/vcap: /' ${KEYDIR}/vcap-key.pub
  gcloud compute --project="${PROJECT}" project-info add-metadata --metadata-from-file sshKeys=${KEYDIR}/vcap-key.pub
  mv ${KEYDIR}/vcap-key.pub.gcp ${KEYDIR}/vcap-key.pub

  echo "Service account bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com and added SSH key to project (private key file: ${KEYDIR}/vcap-key)..."
}

ssl_certs () {
  echo "Creating SSL certificate for load balancers..."

  COMMON_NAME="*.${SUBDOMAIN}"
  COUNTRY="US"
  STATE="MA"
  CITY="Cambridge"
  ORGANIZATION="${DOMAIN}"
  ORG_UNIT="Cloud"
  EMAIL="${ACCOUNT}"
  ALT_NAMES="DNS:*.${SUBDOMAIN},DNS:*.${PCF_SYSTEM_DOMAIN},DNS:*.pcf.${SUBDOMAIN},DNS:*.${PCF_APPS_DOMAIN},DNS:*.login.${PCF_SYSTEM_DOMAIN},DNS:*.uaa.${PCF_SYSTEM_DOMAIN}"
  SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

  openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout ${TMPDIR}/${DOMAIN_TOKEN}.key -out ${TMPDIR}/${DOMAIN_TOKEN}.crt -subj "${SUBJECT}" -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=${ALT_NAMES}\n"))

  echo "SSL certificate created and stored at ${TMPDIR}/${DOMAIN_TOKEN}.crt..."
}

load_balancers () {
  # setup the load balancers
  gcloud compute --project "${PROJECT}" instance-groups unmanaged create "pcf-instances-${AVAILABILITY_ZONE_1}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --description "Includes VM instances that are managed as part of the PCF install in ${AVAILABILITY_ZONE_1}."
  gcloud compute --project "${PROJECT}" instance-groups unmanaged create "pcf-instances-${AVAILABILITY_ZONE_2}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_2} --description "Includes VM instances that are managed as part of the PCF install in ${AVAILABILITY_ZONE_2}."
  gcloud compute --project "${PROJECT}" instance-groups unmanaged create "pcf-instances-${AVAILABILITY_ZONE_3}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_3} --description "Includes VM instances that are managed as part of the PCF install in ${AVAILABILITY_ZONE_3}."

  # SSH
  gcloud compute --project "${PROJECT}" addresses create "${SSH_LOAD_BALANCER_NAME}" --region "${REGION_1}"
  gcloud compute --project "${PROJECT}" target-pools create "${SSH_LOAD_BALANCER_NAME}" --description "Target pool for load balancing SSH access to PCF instances" --region "${REGION_1}" --session-affinity "NONE"
  gcloud compute --project "${PROJECT}" forwarding-rules create "${SSH_LOAD_BALANCER_NAME}" --description "Forwarding rule for load balancing SSH access to PCF instances" --region "${REGION_1}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-ssh-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "2222" --target-pool "${SSH_LOAD_BALANCER_NAME}"

  # HTTP(S)
  gcloud compute --project "${PROJECT}" addresses create "${HTTP_LOAD_BALANCER_NAME}" --global
  gcloud compute --project "${PROJECT}" http-health-checks create "pcf-http-router-health-check-${DOMAIN_TOKEN}" --description "Health check for load balancing web access to PCF instances" --request-path "/health" --port="8080" --timeout "5s" --healthy-threshold "2" --unhealthy-threshold "2"
  gcloud compute --project "${PROJECT}" backend-services create "${HTTP_LOAD_BALANCER_NAME}" --description "Backend services for load balancing web access to PCF instances" --session-affinity "NONE"  --http-health-checks "pcf-http-router-health-check-${DOMAIN_TOKEN}"
  gcloud compute --project "${PROJECT}" backend-services add-backend "pcf-http-router-${DOMAIN_TOKEN}" --instance-group "pcf-instances-${AVAILABILITY_ZONE_1}-${DOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_1}" --description "Backend to map HTTP load balancing to the appropriate instances in ${AVAILABILITY_ZONE_1}."
  gcloud compute --project "${PROJECT}" backend-services add-backend "pcf-http-router-${DOMAIN_TOKEN}" --instance-group "pcf-instances-${AVAILABILITY_ZONE_2}-${DOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_2}" --description "Backend to map HTTP load balancing to the appropriate instances in ${AVAILABILITY_ZONE_2}."
  gcloud compute --project "${PROJECT}" backend-services add-backend "pcf-http-router-${DOMAIN_TOKEN}" --instance-group "pcf-instances-${AVAILABILITY_ZONE_3}-${DOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_3}" --description "Backend to map HTTP load balancing to the appropriate instances in ${AVAILABILITY_ZONE_3}."
  gcloud compute --project "${PROJECT}" url-maps create "${HTTP_LOAD_BALANCER_NAME}" --default-service "${HTTP_LOAD_BALANCER_NAME}" --description "URL Map for HTTP load balancer for access to PCF instances"
  gcloud compute --project "${PROJECT}" ssl-certificates create "pcf-router-ssl-cert-${DOMAIN_TOKEN}" --certificate "${TMPDIR}/${DOMAIN_TOKEN}.crt"  --private-key "${TMPDIR}/${DOMAIN_TOKEN}.key"
  gcloud compute --project "${PROJECT}" target-http-proxies create "pcf-router-http-proxy-${DOMAIN_TOKEN}" --url-map  "${HTTP_LOAD_BALANCER_NAME}" --description "Backend services for load balancing HTTP access to PCF instances"
  gcloud compute --project "${PROJECT}" target-https-proxies create "pcf-router-https-proxy-${DOMAIN_TOKEN}" --url-map "${HTTP_LOAD_BALANCER_NAME}" --ssl-certificate "pcf-router-ssl-cert-${DOMAIN_TOKEN}" --description "Backend services for load balancing HTTPS access to PCF instances"
  gcloud compute --project "${PROJECT}" forwarding-rules create --global "pcf-http-router-${DOMAIN_TOKEN}-forwarding-rule" --description "Forwarding rule for load balancing web (plain-text) access to PCF instances." --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/global/addresses/pcf-http-router-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "80" --target-http-proxy "pcf-router-http-proxy-${DOMAIN_TOKEN}"
  gcloud compute --project "${PROJECT}" forwarding-rules create --global "pcf-http-router-${DOMAIN_TOKEN}-forwarding-rule2" --description "Forwarding rule for load balancing web (SSL) access to PCF instances." --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/global/addresses/pcf-http-router-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "443" --target-https-proxy "pcf-router-https-proxy-${DOMAIN_TOKEN}"

  # Websockets (documentation says it reuses a bunch of stuff from the HTTP LB)
  gcloud compute --project "${PROJECT}" addresses create "${WS_LOAD_BALANCER_NAME}" --region "${REGION_1}"
  gcloud compute --project "${PROJECT}" target-pools create "${WS_LOAD_BALANCER_NAME}" --description "Target pool for load balancing web access to PCF instances" --region "${REGION_1}" --session-affinity "NONE"  --http-health-check "pcf-http-router-health-check-${DOMAIN_TOKEN}"
  gcloud compute --project "${PROJECT}" forwarding-rules create "${WS_LOAD_BALANCER_NAME}" --description "Forwarding rule for load balancing web access to PCF instances." --region "${REGION_1}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-websockets-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "443" --target-pool "${WS_LOAD_BALANCER_NAME}"

  # TCP Routing
  gcloud compute --project "${PROJECT}" addresses create "${TCP_LOAD_BALANCER_NAME}" --region "${REGION_1}"
  gcloud compute --project "${PROJECT}" target-pools create "${TCP_LOAD_BALANCER_NAME}" --description "Target pool for load balancing web access to PCF instances" --region "${REGION_1}" --session-affinity "NONE"
  gcloud compute --project "${PROJECT}" forwarding-rules create "${TCP_LOAD_BALANCER_NAME}" --description "Forwarding rule for load balancing web access to PCF instances." --region "${REGION_1}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-tcp-router-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "1024-65535" --target-pool "${TCP_LOAD_BALANCER_NAME}"
  echo "Load balancers for Router: tcp:pcf-websockets-${DOMAIN_TOKEN},http:pcf-http-router-${DOMAIN_TOKEN}"
  echo "Load balancer for Deigo Brain: tcp:pcf-ssh-${DOMAIN_TOKEN}"
  echo "Load balancer for TCP Router: tcp:pcf-tcp-router-${DOMAIN_TOKEN}"
}

dns () {
  gcloud dns managed-zones create ${DNS_ZONE} --dns-name "${SUBDOMAIN}." --description "Zone for ${SUBDOMAIN}"

  # NB: By default update_root_dns won't do anything. See lib/customization_hooks.sh for more info.
  update_root_dns
  echo "Waiting for ${DNS_TTL} seconds for the Root DNS to sync up..."
  sleep "${DNS_TTL}"

  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"

  # HTTP/S router
  HTTP_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${HTTP_LOAD_BALANCER_NAME}" --global  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "*.${PCF_APPS_DOMAIN}" --ttl "${DNS_TTL}" --type A "${HTTP_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "*.${PCF_SYSTEM_DOMAIN}" --ttl "${DNS_TTL}" --type A "${HTTP_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"

  # ssh router
  SSH_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${SSH_LOAD_BALANCER_NAME}" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "ssh.${PCF_SYSTEM_DOMAIN}" --ttl "${DNS_TTL}" --type A "${SSH_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"

  # websockets router
  WS_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${WS_LOAD_BALANCER_NAME}" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "doppler.${PCF_SYSTEM_DOMAIN}" --ttl "${DNS_TTL}" --type A "${WS_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "loggregator.${PCF_SYSTEM_DOMAIN}" --ttl "${DNS_TTL}" --type A "${WS_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"

  # tcp router
  TCP_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${TCP_LOAD_BALANCER_NAME}" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "tcp.${SUBDOMAIN}" --ttl "${DNS_TTL}" --type A "${TCP_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"

  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"
}

blobstore () {
  # create storage buckets for ERT file storage -- uncertain permissions are needed
  gsutil mb -l ${STORAGE_LOCATION} gs://buildpacks-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://buildpacks-pcf-${DOMAIN_TOKEN}
  gsutil mb -l ${STORAGE_LOCATION} gs://droplets-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://droplets-pcf-${DOMAIN_TOKEN}
  gsutil mb -l ${STORAGE_LOCATION} gs://packages-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://packages-pcf-${DOMAIN_TOKEN}
  gsutil mb -l ${STORAGE_LOCATION} gs://resources-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://resources-pcf-${DOMAIN_TOKEN}
}

ops_manager () {
  OPS_MANAGER_RELEASES_URL="https://network.pivotal.io/api/v2/products/ops-manager/releases"
  OPS_MANAGER_YML="${TMPDIR}/ops-manager-on-gcp.yml"

  # download the Ops Manager YAML file to find the image we're using
  FILES_URL=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" $OPS_MANAGER_RELEASES_URL | jq --raw-output ".releases[] | select( .version == \"$OPS_MANAGER_VERSION\" ) ._links .product_files .href"`
  DOWNLOAD_POST_URL=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" $FILES_URL | jq --raw-output '.product_files[] | select( .name | test ("GCP.*yml") ) ._links .download .href'`
  DOWNLOAD_URL=`curl -qsf -X POST -d "" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token $PIVNET_TOKEN" $DOWNLOAD_POST_URL -w "%{url_effective}\n"`
  IMAGE_URI=`curl -qsf "${DOWNLOAD_URL}" | grep ".us" | sed 's/us: //'`

  # Ops Manager instance
  gcloud compute --project "${PROJECT}" images create "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}" --family "pcf-ops-manager" --description "Primary disk for Pivotal Cloud Foundry Operations Manager" --source-uri "https://storage.googleapis.com/$IMAGE_URI"

  # make sure we can get to it
  gcloud compute --project "${PROJECT}" addresses create "pcf-ops-manager-${DOMAIN_TOKEN}" --region "${REGION_1}"
  OPS_MANAGER_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "pcf-ops-manager-${DOMAIN_TOKEN}" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "manager.${SUBDOMAIN}" --ttl "${DNS_TTL}" --type A ${OPS_MANAGER_ADDRESS} --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"

  gcloud compute --project "${PROJECT}" instances create "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --machine-type "n1-standard-1" --subnet "pcf-${REGION_1}-${DOMAIN_TOKEN}" --private-network-ip "10.0.0.4" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-ops-manager-${DOMAIN_TOKEN}" --maintenance-policy "MIGRATE" --scopes bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com="https://www.googleapis.com/auth/cloud-platform" --tags "http-server","https-server","pcf-opsmanager" --image-family "pcf-ops-manager" --boot-disk-size "200" --boot-disk-type "pd-standard" --boot-disk-device-name "pcf-operations-manager"
  ssh-keygen -P "" -t rsa -f ${KEYDIR}/ubuntu-key -b 4096 -C ubuntu@local
  sed -i.gcp '1s/^/ubuntu: /' ${KEYDIR}/ubuntu-key.pub
  gcloud compute instances add-metadata "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone "${AVAILABILITY_ZONE_1}" --metadata-from-file "ssh-keys=${KEYDIR}/ubuntu-key.pub"
  mv ${KEYDIR}/ubuntu-key.pub.gcp ${KEYDIR}/ubuntu-key.pub

  # noticed I was getting 502 errors on the setup calls below, so sleeping to see if that helps
  sleep 60

  # now let's get ops manager going
  SETUP_JSON=`envsubst < api-calls/setup.json`
  curl --insecure "${OPS_MANAGER_API_ENDPOINT}/setup" -X POST -H "Content-Type: application/json" -d $SETUP_JSON

  # log in to the ops_manager so the script can manipulate it later
  login_ops_manager

  # prepare for downloading products from the Pivotal Network

  curl --insecure "${OPS_MANAGER_API_ENDPOINT}/settings/pivotal_network_settings" -X PUT \
      -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
      -H "Content-Type: application/json" -d "{ \"pivotal_network_settings\": { \"api_token\": \"$PIVNET_TOKEN\" } }"
}

cloud_foundry () {
  # provide the necessary DNS records for the internal MySQL database
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "mysql.${SUBDOMAIN}" --ttl "${DNS_TTL}" --type A "10.0.15.98" "10.0.15.99" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml"
}

service_broker () {
  # prepare for the google service broker
  gcloud iam service-accounts create "service-broker-${DOMAIN_TOKEN}" --display-name bosh
  gcloud iam service-accounts keys create "${KEYDIR}/${PROJECT}-service-broker-${DOMAIN_TOKEN}.json" --iam-account service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/owner"
  gcloud sql --project="${PROJECT}" instances create "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" --assign-ip --require-ssl --authorized-networks="${ALL_INTERNET}" --region=${REGION_1}  --gce-zone=${AVAILABILITY_ZONE_1}
  gcloud sql --project="${PROJECT}" instances set-root-password "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" --password="${DB_ROOT_PASSWORD}"
  # server connection requirements
  gcloud --format json sql --project="${PROJECT}" instances describe "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" | jq --raw-output '.serverCaCert .cert ' > "${KEYDIR}/gcp-service-broker-db-server.crt"
  gcloud --format json sql --project="${PROJECT}" instances describe "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" | jq --raw-output ' .ipAddresses [0] .ipAddress ' > "${TMPDIR}/gcp-service-broker-db.ip"
  # client connection requirements
  gcloud sql --project="${PROJECT}" ssl-certs create "pcf.${SUBDOMAIN}" "${KEYDIR}/gcp-service-broker-db-client.key" --instance "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}"
  gcloud sql --project="${PROJECT}" --format=json ssl-certs describe "pcf.${SUBDOMAIN}" --instance "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}" | jq --raw-output ' .cert ' > "${KEYDIR}/gcp-service-broker-db-client.crt"
  # setup a user
  gcloud beta sql --project="${PROJECT}" users create "pcf" "%" --password "${DB_USER_PASSWORD}" --instance "gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}"

  # setup a database for the servicebroker
  GCP_AUTH_TOKEN=`gcloud auth application-default print-access-token`
  curl -q -X POST "https://www.googleapis.com/sql/v1beta4/projects/${PROJECT}/instances/gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}/databases" \
    -H "Authorization: Bearer $GCP_AUTH_TOKEN" -H 'Content-Type: application/json' -d "{ \"instance\": \"gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}\", \"name\": \"servicebroker\", \"project\": \"${PROJECT}\" }"

  # setup a database and add permissions for the servicebroker user
  mysql -uroot -p${DB_ROOT_PASSWORD} -h `cat "${TMPDIR}/gcp-service-broker-db.ip"` --ssl-ca="${KEYDIR}/gcp-service-broker-db-server.crt" \
    --ssl-cert="${KEYDIR}/gcp-service-broker-db-client.crt" --ssl-key="${KEYDIR}/gcp-service-broker-db-client.key" <<SQL
  GRANT ALL PRIVILEGES ON servicebroker.* TO 'pcf'@'%' WITH GRANT OPTION;
SQL
}

START_TIMESTAMP=`date`
START_SECONDS=`date +%s`
env
echo "Started preparing Google Cloud Platform project ${PROJECT} to install Cloud Foundry at ${START_TIMESTAMP}..."
setup
network
security
ssl_certs
load_balancers
dns
blobstore
ops_manager
cloud_foundry
service_broker
END_TIMESTAMP=`date`
END_SECONDS=`date +%s`
ELAPSED_TIME=`echo $((END_SECONDS-START_SECONDS)) | awk '{print int($1/60)":"int($1%60)}'`
echo "Completed preparing Google Cloud Platform project ${PROJECT} to install Cloud Foundry at ${END_TIMESTAMP} (elapsed time ${ELAPSED_TIME})."
