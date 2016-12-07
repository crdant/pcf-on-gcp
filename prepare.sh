#!/usr/bin/env bash
# prepare to install PCF on GCP

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
env

. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/personal.sh"
. "${BASEDIR}/lib/setup.sh"
. "${BASEDIR}/lib/login_ops_manager.sh"
. "${BASEDIR}/lib/random_phrase.sh"
. "${BASEDIR}/lib/generate_passphrase.sh"
. "${BASEDIR}/lib/configure_networks_azs.sh"

network () {
  # create a network (parameterize the network name and project later)
  echo "Creating network, subnet, and firewall rules..."

  gcloud compute --project "${PROJECT}" networks create "pcf-${DOMAIN_TOKEN}" --description "Network for ${DOMAIN} Cloud Foundry installation. Creating with a single subnet." --mode "custom" --no-user-output-enabled

  # create a single subnet in us-east1 (parameterize REGION_1 and names later)
  gcloud compute --project "${PROJECT}" networks subnets create "pcf-${REGION_1}-${DOMAIN_TOKEN}" --network "pcf-${DOMAIN_TOKEN}" --region "${REGION_1}" --range ${CIDR} --no-user-output-enabled

  # create necessary firewall rules
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-allow-internal-traffic-${DOMAIN_TOKEN}" --allow "tcp:0-65535,udp:0-65535,icmp" --description "Enable traffic between all VMs managed by Ops Manager and BOSH" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${CIDR} --no-user-output-enabled
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-opsmanager-${DOMAIN_TOKEN}" --allow "tcp:22,tcp:80,tcp:443" --description "Allow web and SSH access to the Ops Manager" --network "pcf-${DOMAIN_TOKEN}" --source-ranges "${ALL_INTERNET}" --target-tags "pcf-opsmanager" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-load-balancers-${DOMAIN_TOKEN}" --allow "tcp:80,tcp:443,tcp:2222,tcp:8080" --description "Allow web, log, and SSH access to the load balancers" --network "pcf-${DOMAIN_TOKEN}" --source-ranges "${ALL_INTERNET}" --target-tags "pcf-lb" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-tcp-load-balancers-${DOMAIN_TOKEN}" --allow "tcp:1024-65535" --description "Allow access to load balancers for TCP routing" --network "pcf-${DOMAIN_TOKEN}" --source-ranges "${ALL_INTERNET}" --target-tags "pcf-tcp-lb" --no-user-output-enabled

  # create firewall rule for the IPSec AddOn
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-ipsec-${DOMAIN_TOKEN}" --allow "udp:500,ah,esp" --description "Enable IPSec access to the network" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${ALL_INTERNET} --no-user-output-enabled

  # create additional firewall rules that are not in the documentation but seem to be necessary based on my experiments
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-bosh-${DOMAIN_TOKEN}" --allow "tcp:22,tcp:80,tcp:443" --description "Allow web and SSH access from internal sources to the BOSH director" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${CIDR} --target-tags "bosh" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" firewall-rules create "pcf-access-cloud-controller-${DOMAIN_TOKEN}" --allow "tcp:80,tcp:443" --description "Allow web access from internal sources to the cloud controller" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${CIDR} --target-tags "cloud-controller" --no-user-output-enabled

  echo "Google Network for BOSH Director: pcf-${DOMAIN_TOKEN}/pcf-${REGION_1}-${DOMAIN_TOKEN}/${REGION_1}"
}

security () {
  echo "Creating services accounts and SSH keys..."

  # create a service account and give it a key (parameterize later), not sure why it doesn't have a project specified but that seems right
  gcloud iam service-accounts create bosh-opsman-${DOMAIN_TOKEN} --display-name bosh --no-user-output-enabled
  gcloud iam service-accounts keys create "${KEYDIR}/${PROJECT}-bosh-opsman-${DOMAIN_TOKEN}.json" --iam-account bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com  --no-user-output-enabled
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/editor" --no-user-output-enabled
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/compute.instanceAdmin" --no-user-output-enabled
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/compute.networkAdmin" --no-user-output-enabled
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/compute.storageAdmin" --no-user-output-enabled

  # setup VCAP SSH for all boxen, this will erase existing SSH keys (FIX!)
  ssh-keygen -P "" -t rsa -f ${KEYDIR}/vcap-key -b 4096 -C vcap@local > /dev/null
  sed -i.gcp '1s/^/vcap: /' ${KEYDIR}/vcap-key.pub
  gcloud compute --project="${PROJECT}" project-info add-metadata --metadata-from-file sshKeys=${KEYDIR}/vcap-key.pub --no-user-output-enabled
  mv ${KEYDIR}/vcap-key.pub.gcp ${KEYDIR}/vcap-key.pub

  passwords

  echo "Created service account bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com and added SSH key to project (private key file: ${KEYDIR}/vcap-key)..."
}

passwords () {
  ADMIN_PASSWORD=`generate_passphrase 4`
  DECRYPTION_PASSPHRASE=`generate_passphrase 5`
  DB_ROOT_PASSWORD=`generate_passphrase 3`
  DB_USER_PASSWORD=`generate_passphrase 3`
  cat <<PASSWORD_LIST > "${PASSWORD_LIST}"
ADMIN_PASSWORD=${ADMIN_PASSWORD}
DECRYPTION_PASSPHRASE=${DECRYPTION_PASSPHRASE}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
DB_USER_PASSWORD=${DB_USER_PASSWORD}
PASSWORD_LIST
  chmod 700 "${PASSWORD_LIST}"
}

ssl_certs () {
  echo "Creating SSL certificate for load balancers..."

  COMMON_NAME="*.${SUBDOMAIN}"
  COUNTRY="US"
  STATE="MA"
  CITY="Cambridge"
  ORGANIZATION="${DOMAIN}"
  ORG_UNIT="Cloud Foundry"
  EMAIL="${ACCOUNT}"
  ALT_NAMES="DNS:*.${SUBDOMAIN},DNS:*.${PCF_SYSTEM_DOMAIN},DNS:*.pcf.${SUBDOMAIN},DNS:*.${PCF_APPS_DOMAIN},DNS:*.login.${PCF_SYSTEM_DOMAIN},DNS:*.uaa.${PCF_SYSTEM_DOMAIN}"
  SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

  openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout "${TMPDIR}/${DOMAIN_TOKEN}.key" -out "${TMPDIR}/${DOMAIN_TOKEN}.crt" -subj "${SUBJECT}" -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=${ALT_NAMES}\n")) > /dev/null

  echo "SSL certificate for load balanacers created and stored at ${TMPDIR}/${DOMAIN_TOKEN}.crt, private key stored at ${TMPDIR}/${DOMAIN_TOKEN}.key."
  echo "The certificate is a wildcard for the following domains: ${ALT_NAMES}"

  echo "Creating SSL certificate for CF router..."

  COMMON_NAME="*.${SUBDOMAIN}"
  COUNTRY="US"
  STATE="MA"
  CITY="Cambridge"
  ORGANIZATION="${DOMAIN}"
  ORG_UNIT="Cloud Foundry Router"
  EMAIL="${ACCOUNT}"
  ALT_NAMES="DNS:*.${SUBDOMAIN},DNS:*.${PCF_SYSTEM_DOMAIN},DNS:*.pcf.${SUBDOMAIN},DNS:*.${PCF_APPS_DOMAIN},DNS:*.login.${PCF_SYSTEM_DOMAIN},DNS:*.uaa.${PCF_SYSTEM_DOMAIN}"
  SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

  openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout "${TMPDIR}/pcf-router-${DOMAIN_TOKEN}.key" -out "${TMPDIR}/pcf-router-${DOMAIN_TOKEN}.crt" -subj "${SUBJECT}" -reqexts SAN -extensions SAN -config <(cat /etc/ssl/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=${ALT_NAMES}\n")) > /dev/null

  echo "SSL certificate for CF router created and stored at ${TMPDIR}/pcf-router-${DOMAIN_TOKEN}.crt, private key stored at ${TMPDIR}/pcf-router-${DOMAIN_TOKEN}.key."
  echo "The certificate is a wildcard for the following domains: ${ALT_NAMES}"

}

load_balancers () {

  echo "Creating SSH, HTTPS(S), WebSocket, and TCP Routing load balancers..."
  # setup the load balancers
  echo "Creating instance groups for each availability zone (${AVAILABILITY_ZONE_1}, ${AVAILABILITY_ZONE_2}, ${AVAILABILITY_ZONE_3})..."
  gcloud compute --project "${PROJECT}" instance-groups unmanaged create "pcf-instances-${AVAILABILITY_ZONE_1}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --description "Includes VM instances that are managed as part of the PCF install in ${AVAILABILITY_ZONE_1}." --no-user-output-enabled
  gcloud compute --project "${PROJECT}" instance-groups unmanaged create "pcf-instances-${AVAILABILITY_ZONE_2}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_2} --description "Includes VM instances that are managed as part of the PCF install in ${AVAILABILITY_ZONE_2}." --no-user-output-enabled
  gcloud compute --project "${PROJECT}" instance-groups unmanaged create "pcf-instances-${AVAILABILITY_ZONE_3}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_3} --description "Includes VM instances that are managed as part of the PCF install in ${AVAILABILITY_ZONE_3}." --no-user-output-enabled
  echo "Instance groups pcf-instances-${AVAILABILITY_ZONE_1}-${DOMAIN_TOKEN}, pcf-instances-${AVAILABILITY_ZONE_2}-${DOMAIN_TOKEN}, and pcf-instances-${AVAILABILITY_ZONE_3}-${DOMAIN_TOKEN} created."

  # SSH
  echo "Creating SSH load balancer..."
  gcloud compute --project "${PROJECT}" addresses create "${SSH_LOAD_BALANCER_NAME}" --region "${REGION_1}" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" target-pools create "${SSH_LOAD_BALANCER_NAME}" --description "Target pool for load balancing SSH access to PCF instances" --region "${REGION_1}" --session-affinity "NONE" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" forwarding-rules create "${SSH_LOAD_BALANCER_NAME}" --description "Forwarding rule for load balancing SSH access to PCF instances" --region "${REGION_1}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-ssh-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "2222" --target-pool "${SSH_LOAD_BALANCER_NAME}" --no-user-output-enabled
  echo "SSH load balancer ${SSH_LOAD_BALANCER_NAME} created..."

  # HTTP(S)
  echo "Creating HTTP(S) load balancer..."
  gcloud compute --project "${PROJECT}" addresses create "${HTTP_LOAD_BALANCER_NAME}" --global --no-user-output-enabled
  gcloud compute --project "${PROJECT}" http-health-checks create "pcf-http-router-health-check-${DOMAIN_TOKEN}" --description "Health check for load balancing web access to PCF instances" --request-path "/health" --port="8080" --timeout "5s" --healthy-threshold "2" --unhealthy-threshold "2" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" backend-services create "${HTTP_LOAD_BALANCER_NAME}" --description "Backend services for load balancing web access to PCF instances" --global --session-affinity "NONE"  --http-health-checks "pcf-http-router-health-check-${DOMAIN_TOKEN}" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" backend-services add-backend "pcf-http-router-${DOMAIN_TOKEN}" --global --instance-group "pcf-instances-${AVAILABILITY_ZONE_1}-${DOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_1}" --description "Backend to map HTTP load balancing to the appropriate instances in ${AVAILABILITY_ZONE_1}." --no-user-output-enabled
  gcloud compute --project "${PROJECT}" backend-services add-backend "pcf-http-router-${DOMAIN_TOKEN}" --global --instance-group "pcf-instances-${AVAILABILITY_ZONE_2}-${DOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_2}" --description "Backend to map HTTP load balancing to the appropriate instances in ${AVAILABILITY_ZONE_2}." --no-user-output-enabled
  gcloud compute --project "${PROJECT}" backend-services add-backend "pcf-http-router-${DOMAIN_TOKEN}" --global --instance-group "pcf-instances-${AVAILABILITY_ZONE_3}-${DOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_3}" --description "Backend to map HTTP load balancing to the appropriate instances in ${AVAILABILITY_ZONE_3}." --no-user-output-enabled
  gcloud compute --project "${PROJECT}" url-maps create "${HTTP_LOAD_BALANCER_NAME}" --default-service "${HTTP_LOAD_BALANCER_NAME}" --description "URL Map for HTTP load balancer for access to PCF instances" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" ssl-certificates create "pcf-router-ssl-cert-${DOMAIN_TOKEN}" --certificate "${TMPDIR}/${DOMAIN_TOKEN}.crt"  --private-key "${TMPDIR}/${DOMAIN_TOKEN}.key" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" target-http-proxies create "pcf-router-http-proxy-${DOMAIN_TOKEN}" --url-map  "${HTTP_LOAD_BALANCER_NAME}" --description "Backend services for load balancing HTTP access to PCF instances"  --no-user-output-enabled
  gcloud compute --project "${PROJECT}" target-https-proxies create "pcf-router-https-proxy-${DOMAIN_TOKEN}" --url-map "${HTTP_LOAD_BALANCER_NAME}" --ssl-certificate "pcf-router-ssl-cert-${DOMAIN_TOKEN}" --description "Backend services for load balancing HTTPS access to PCF instances" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" forwarding-rules create --global "pcf-http-router-${DOMAIN_TOKEN}-forwarding-rule" --description "Forwarding rule for load balancing web (plain-text) access to PCF instances." --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/global/addresses/pcf-http-router-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "80" --target-http-proxy "pcf-router-http-proxy-${DOMAIN_TOKEN}" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" forwarding-rules create --global "pcf-http-router-${DOMAIN_TOKEN}-forwarding-rule2" --description "Forwarding rule for load balancing web (SSL) access to PCF instances." --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/global/addresses/pcf-http-router-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "443" --target-https-proxy "pcf-router-https-proxy-${DOMAIN_TOKEN}" --no-user-output-enabled
  echo "HTTP(S) load balancer ${HTTP_LOAD_BALANCER_NAME} created."

  # Websockets (documentation says it reuses a bunch of stuff from the HTTP LB)
  echo "Created Websockets load balancer..."
  gcloud compute --project "${PROJECT}" addresses create "${WS_LOAD_BALANCER_NAME}" --region "${REGION_1}" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" target-pools create "${WS_LOAD_BALANCER_NAME}" --description "Target pool for load balancing web access to PCF instances" --region "${REGION_1}" --session-affinity "NONE"  --http-health-check "pcf-http-router-health-check-${DOMAIN_TOKEN}" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" forwarding-rules create "${WS_LOAD_BALANCER_NAME}" --description "Forwarding rule for load balancing web access to PCF instances." --region "${REGION_1}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-websockets-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "443" --target-pool "${WS_LOAD_BALANCER_NAME}" --no-user-output-enabled
  echo "Websockets load balancer ${WS_LOAD_BALANCER_NAME} created."

  # TCP Routing
  echo "Creating TCP routing load balancer..."
  gcloud compute --project "${PROJECT}" addresses create "${TCP_LOAD_BALANCER_NAME}" --region "${REGION_1}" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" target-pools create "${TCP_LOAD_BALANCER_NAME}" --description "Target pool for load balancing web access to PCF instances" --region "${REGION_1}" --session-affinity "NONE" --no-user-output-enabled
  gcloud compute --project "${PROJECT}" forwarding-rules create "${TCP_LOAD_BALANCER_NAME}" --description "Forwarding rule for load balancing web access to PCF instances." --region "${REGION_1}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-tcp-router-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "1024-65535" --target-pool "${TCP_LOAD_BALANCER_NAME}" --no-user-output-enabled
  echo "TCP load balancer ${TCP_LOAD_BALANCER_NAME} created."

  echo "You will need the following values to configure the PCF tile in Operations Managers if you do not use install.sh (it will set them for you)"
  echo "  Load balancers for Router: tcp:pcf-websockets-${DOMAIN_TOKEN},http:pcf-http-router-${DOMAIN_TOKEN}"
  echo "  Load balancer for Deigo Brain: tcp:pcf-ssh-${DOMAIN_TOKEN}"
  echo "  Load balancer for TCP Router: tcp:pcf-tcp-router-${DOMAIN_TOKEN}"
}

dns () {
  echo "Configuring DNS entries for all load balancers"
  gcloud dns managed-zones create ${DNS_ZONE} --dns-name "${SUBDOMAIN}." --description "Zone for ${SUBDOMAIN}" --no-user-output-enabled

  # NB: By default update_root_dns won't do anything. See lib/customization_hooks.sh for more info.
  update_root_dns
  echo "Waiting for ${DNS_TTL} seconds for the Root DNS to sync up..."
  sleep "${DNS_TTL}"

  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled

  # HTTP/S router
  HTTP_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${HTTP_LOAD_BALANCER_NAME}" --global  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "*.${PCF_APPS_DOMAIN}" --ttl "${DNS_TTL}" --type A "${HTTP_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "*.${PCF_SYSTEM_DOMAIN}" --ttl "${DNS_TTL}" --type A "${HTTP_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled

  # ssh router
  SSH_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${SSH_LOAD_BALANCER_NAME}" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "ssh.${PCF_SYSTEM_DOMAIN}" --ttl "${DNS_TTL}" --type A "${SSH_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled

  # websockets router
  WS_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${WS_LOAD_BALANCER_NAME}" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "doppler.${PCF_SYSTEM_DOMAIN}" --ttl "${DNS_TTL}" --type A "${WS_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "loggregator.${PCF_SYSTEM_DOMAIN}" --ttl "${DNS_TTL}" --type A "${WS_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled

  # tcp router
  TCP_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${TCP_LOAD_BALANCER_NAME}" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "tcp.${SUBDOMAIN}" --ttl "${DNS_TTL}" --type A "${TCP_ADDRESS}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled

  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  echo "DNS entries configured."
}

blobstore () {
  # create storage buckets for ERT file storage -- uncertain permissions are needed
  echo "Creating storage buckets for storing BLOBs..."
  gsutil mb -l ${STORAGE_LOCATION} gs://${BUILDPACKS_STORAGE_BUCKET}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://${BUILDPACKS_STORAGE_BUCKET}
  gsutil mb -l ${STORAGE_LOCATION} gs://${DROPLETS_STORAGE_BUCKET}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://${DROPLETS_STORAGE_BUCKET}
  gsutil mb -l ${STORAGE_LOCATION} gs://${PACKAGES_STORAGE_BUCKET}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://${PACKAGES_STORAGE_BUCKET}
  gsutil mb -l ${STORAGE_LOCATION} gs://${RESOURCES_STORAGE_BUCKET}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://${RESOURCES_STORAGE_BUCKET}
  echo "Created storage buckets for storing elastic runtime BLOBs."
  echo "You will need the following values to configure the PCF tile in Operations Manager"
  echo "  Buildpack storage: ${BUILDPACKS_STORAGE_BUCKET}"
  echo "  Droplet storage: ${DROPLETS_STORAGE_BUCKET}"
  echo "  Package storage: ${PACKAGES_STORAGE_BUCKET}"
  echo "  Resource storage: ${RESOURCES_STORAGE_BUCKET}"
}

ops_manager () {
  echo "Installing Operations Manager..."
  OPS_MANAGER_RELEASES_URL="https://network.pivotal.io/api/v2/products/ops-manager/releases"
  OPS_MANAGER_YML="${TMPDIR}/ops-manager-on-gcp.yml"

  # download the Ops Manager YAML file to find the image we're using
  echo "Finding the image location for the Pivotal release image for operations manager."
  FILES_URL=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" $OPS_MANAGER_RELEASES_URL | jq --raw-output ".releases[] | select( .version == \"$OPS_MANAGER_VERSION\" ) ._links .product_files .href"`
  DOWNLOAD_POST_URL=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" $FILES_URL | jq --raw-output '.product_files[] | select( .name | test ("GCP.*yml") ) ._links .download .href'`
  DOWNLOAD_URL=`curl -qsf -X POST -d "" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token $PIVNET_TOKEN" $DOWNLOAD_POST_URL -w "%{url_effective}\n"`
  IMAGE_URI=`curl -qsf "${DOWNLOAD_URL}" | grep ".us" | sed 's/us: //'`
  IMAGE_SOURCE_URI="https://storage.googleapis.com/${IMAGE_URI}"
  echo "Located image at ${IMAGE_URI}"

  # Ops Manager instance
  echo "Creating disk image for Operations Manager from the Pivotal provided image..."
  gcloud compute --project "${PROJECT}" images create "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}" --family "pcf-ops-manager" --description "Primary disk for Pivotal Cloud Foundry Operations Manager" --source-uri "${IMAGE_SOURCE_URI}" --no-user-output-enabled
  echo "Operations Manager image created."

  # make sure we can get to it
  echo "Configuring DNS for Operations Manager..."
  gcloud compute --project "${PROJECT}" addresses create "pcf-ops-manager-${DOMAIN_TOKEN}" --region "${REGION_1}" --no-user-output-enabled
  OPS_MANAGER_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "pcf-ops-manager-${DOMAIN_TOKEN}" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "${OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A ${OPS_MANAGER_ADDRESS} --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  echo "Updated Operations Manager DNS for ${OPS_MANAGER_FQDN} to ${OPS_MANAGER_ADDRESS}."

  echo "Creating Operations Manager instance..."
  gcloud compute --project "${PROJECT}" instances create "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --machine-type "n1-standard-1" --subnet "pcf-${REGION_1}-${DOMAIN_TOKEN}" --private-network-ip "10.0.0.4" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-ops-manager-${DOMAIN_TOKEN}" --maintenance-policy "MIGRATE" --scopes bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com="https://www.googleapis.com/auth/cloud-platform" --tags "http-server","https-server","pcf-opsmanager" --image-family "pcf-ops-manager" --boot-disk-size "200" --boot-disk-type "pd-standard" --boot-disk-device-name "pcf-operations-manager" --no-user-output-enabled
  ssh-keygen -P "" -t rsa -f ${KEYDIR}/ubuntu-key -b 4096 -C ubuntu@local > /dev/null
  sed -i.gcp '1s/^/ubuntu: /' ${KEYDIR}/ubuntu-key.pub
  gcloud compute instances add-metadata "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone "${AVAILABILITY_ZONE_1}" --metadata-from-file "ssh-keys=${KEYDIR}/ubuntu-key.pub" --no-user-output-enabled
  mv ${KEYDIR}/ubuntu-key.pub.gcp ${KEYDIR}/ubuntu-key.pub
  echo "Operations Manager instance created..."

  # noticed I was getting 502 and 503 errors on the setup calls below, so sleeping to see if that helps
  echo "Waiting for ${DNS_TTL} seconds for Operations Manager instance to be available and DNS to be updated..."
  sleep ${DNS_TTL}

  # now let's get ops manager going
  echo "Setting up Operations Manager authentication and adminsitrative user..."

  # this line looks a little funny, but it's to make sure we keep the passwords out of the environment
  SETUP_JSON=`export ADMIN_PASSWORD DECRYPTION_PASSPHRASE ; envsubst < api-calls/setup.json ; unset ADMIN_PASSWORD ; unset DECRYPTION_PASSPHRASE`
  curl -qsf --insecure "${OPS_MANAGER_API_ENDPOINT}/setup" -X POST -H "Content-Type: application/json" -d "${SETUP_JSON}"
  echo "Operation manager configured. Your username is admin and password is ${ADMIN_PASSWORD}."

  # log in to the ops_manager so the script can manipulate it later
  login_ops_manager

  # configure networking for BOSH director
  # looks funny, but it keeps us from polluting the environment
  DIRECTOR_NETWORK_SETTINGS=`export DIRECTOR_NETWORK_NAME AVAILABILITY_ZONE_1 ; envsubst < api-calls/director_networks_azs.json ; unset  DIRECTOR_NETWORK_NAME AVAILABILITY_ZONE_1`
  configure_networks_azs "p-bosh" "${DIRECTOR_NETWORK_SETTINGS}"

  # prepare for downloading products from the Pivotal Network
  echo "Providing Pivotal Network settings to Operations Manager..."
  curl -qsf --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/settings/pivotal_network_settings" \
      -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
      -H "Content-Type: application/json" -d "{ \"pivotal_network_settings\": { \"api_token\": \"$PIVNET_TOKEN\" } }"
  echo "Operations Manager installed and prepared for tile configruation."
}

cloud_foundry () {
  echo "Preparing for Elastic Runtime installation..."

  echo "Creating DNS entry for MySQL proxy..."
  # provide the necessary DNS records for the internal MySQL database
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "mysql.${SUBDOMAIN}" --ttl "${DNS_TTL}" --type A "10.0.15.98" "10.0.15.99" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled

  echo "Finished preparing for Elastic Runtime installation."
}

service_broker () {
  echo "Preparing for GCP Service Broker installation..."

  # prepare for the google service broker
  echo "Setting up service account service-broker-${DOMAIN_TOKEN}"
  gcloud iam service-accounts create "service-broker-${DOMAIN_TOKEN}" --display-name "Google Cloud Platform Service Broker" --no-user-output-enabled
  gcloud iam service-accounts keys create "${KEYDIR}/${PROJECT}-service-broker-${DOMAIN_TOKEN}.json" --iam-account service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com --no-user-output-enabled
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/owner" --no-user-output-enabled
  echo "Service account service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com created."

  GCP_BROKER_DATABASE_NAME="gcp-service-broker-${GCP_VERSION_TOKEN}-${DOMAIN_TOKEN}-"`random_phrase`
  # TODO: store this in a file that won't go away if we reboot
  echo "${GCP_BROKER_DATABASE_NAME}" > "${TMPDIR}/gcp-service-broker-db.name"
  echo "Creating ${GCP_BROKER_DATABASE_NAME} database for service broker..."
  gcloud sql --project="${PROJECT}" instances create "${GCP_BROKER_DATABASE_NAME}" --assign-ip --require-ssl --authorized-networks="${ALL_INTERNET}" --region=${REGION_1}  --gce-zone=${AVAILABILITY_ZONE_1} --no-user-output-enabled
  gcloud sql --project="${PROJECT}" instances set-root-password "${GCP_BROKER_DATABASE_NAME}" --password="${DB_ROOT_PASSWORD}" --no-user-output-enabled
  # server connection requirements
  gcloud --format json sql --project="${PROJECT}" instances describe "${GCP_BROKER_DATABASE_NAME}" | jq --raw-output '.serverCaCert .cert ' > "${KEYDIR}/gcp-service-broker-db-server.crt"
  gcloud --format json sql --project="${PROJECT}" instances describe "${GCP_BROKER_DATABASE_NAME}" | jq --raw-output ' .ipAddresses [0] .ipAddress ' > "${TMPDIR}/gcp-service-broker-db.ip"
  # client connection requirements
  gcloud sql --project="${PROJECT}" ssl-certs create "pcf.${SUBDOMAIN}" "${KEYDIR}/gcp-service-broker-db-client.key" --instance "${GCP_BROKER_DATABASE_NAME}" --no-user-output-enabled
  gcloud sql --project="${PROJECT}" --format=json ssl-certs describe "pcf.${SUBDOMAIN}" --instance "${GCP_BROKER_DATABASE_NAME}" | jq --raw-output ' .cert ' > "${KEYDIR}/gcp-service-broker-db-client.crt"
  # setup a user
  gcloud beta sql --project="${PROJECT}" users create "pcf" "%" --password "${DB_USER_PASSWORD}" --instance "${GCP_BROKER_DATABASE_NAME}" --no-user-output-enabled

  # setup a MYSQL database for the servicebroker in the instance we created
  GCP_AUTH_TOKEN=`gcloud auth application-default print-access-token`
  curl -q -X POST "https://www.googleapis.com/sql/v1beta4/projects/${PROJECT}/instances/${GCP_BROKER_DATABASE_NAME}/databases" \
    -H "Authorization: Bearer $GCP_AUTH_TOKEN" -H 'Content-Type: application/json' -d "{ \"instance\": \"${GCP_BROKER_DATABASE_NAME}\", \"name\": \"servicebroker\", \"project\": \"${PROJECT}\" }"

  # setup a database and add permissions for the servicebroker user
  mysql -uroot -p${DB_ROOT_PASSWORD} -h `cat "${TMPDIR}/gcp-service-broker-db.ip"` --ssl-ca="${KEYDIR}/gcp-service-broker-db-server.crt" \
    --ssl-cert="${KEYDIR}/gcp-service-broker-db-client.crt" --ssl-key="${KEYDIR}/gcp-service-broker-db-client.key" <<SQL
  GRANT ALL PRIVILEGES ON servicebroker.* TO 'pcf'@'%' WITH GRANT OPTION;
SQL
  echo "Service broker database created. Configred the service broker tile with user 'pcf' and service account service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com."
  echo "Service broker service account credentials are at ${KEYDIR}/${PROJECT}-service-broker-${DOMAIN_TOKEN}.json"
  echo "To connect to the database, use the following command-line: "
  echo "    mysql -uroot -p${DB_ROOT_PASSWORD} -h `cat \"${TMPDIR}/gcp-service-broker-db.ip\"` --ssl-ca=\"${KEYDIR}/gcp-service-broker-db-server.crt\"  --ssl-cert=\"${KEYDIR}/gcp-service-broker-db-client.crt\" --ssl-key=\"${KEYDIR}/gcp-service-broker-db-client.key\""
}

START_TIMESTAMP=`date`
START_SECONDS=`date +%s`
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
