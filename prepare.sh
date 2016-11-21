# prepare to install PCF on GCP

env () {
  ACCOUNT="cdantonio@pivotal.io"
  PROJECT="fe-cdantonio"
  REGION="us-east1"
  AVAILABILITY_ZONE="us-east1-b"
  DOMAIN=crdant.io
  DOMAIN_TOKEN=`echo ${DOMAIN} | tr . -`
  SUBDOMAIN="gcp.${DOMAIN}"
  DNS_ZONE=`echo ${SUBDOMAIN} | tr . -`
  DNS_TTL=300
  CIDR="10.0.0.0/20"
  ALL_INTERNET="0.0.0.0/0"
}

setup () {
  # make sure our API components up-to-date
  gcloud components update

  # log in (parameterize later)
  gcloud auth login ${ACCOUNT}
  gcloud config set project ${PROJECT}
  gcloud config set compute/zone ${AVAILABILITY_ZONE}
  gcloud config set compute/region ${REGION}
}

network () {
  # create a network (parameterize the network name and project later)
  gcloud compute --project ${PROJECT} networks create "pcf-${DOMAIN_TOKEN}" --description "Network for crdant.io Cloud Foundry installation. Creating with a single subnet." --mode "custom"

  # create a single subnet in us-east1 (parameterize region and names later)
  gcloud compute --project ${PROJECT} networks subnets create "pcf-us-east1-${DOMAIN_TOKEN}" --network "pcf-${DOMAIN_TOKEN}" --region "${REGION}" --range ${CIDR}

  # create necessary firewall rules
  gcloud compute --project ${PROJECT} firewall-rules create "pcf-allow-internal-traffic-${DOMAIN_TOKEN}" --allow tcp:0-65535,udp:0-65535,icmp --description "Enable traffic between all VMs managed by Ops Manager and BOSH" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${CIDR}
  gcloud compute --project ${PROJECT} firewall-rules create "pcf-access-opsmanager-${DOMAIN_TOKEN}" --allow tcp:22,tcp:80,tcp:443 --description "Allow web and SSH access to the Ops Manager" --network "pcf-${DOMAIN_TOKEN}" --source-ranges "${ALL_INTERNET}" --target-tags "pcf-opsmanager"
  gcloud compute --project ${PROJECT} firewall-rules create "pcf-access-load-balancers-${DOMAIN_TOKEN}" --allow tcp:80,tcp:443,tcp:2222,tcp:8080 --description "Allow web, log, and SSH access to the load balancers" --network "pcf-${DOMAIN_TOKEN}" --source-ranges "${ALL_INTERNET}" --target-tags "pcf-lb"
  gcloud compute --project ${PROJECT} firewall-rules create "pcf-access-tcp-load-balancers-${DOMAIN_TOKEN}" --allow tcp:1024-65535 --description "Allow access to load balancers for TCP routing" --network "pcf-${DOMAIN_TOKEN}" --source-ranges "${ALL_INTERNET}" --target-tags "pcf-tcp-lb"

  # create additional firewall rules that are not in the documentation but seem to be necessary based on my experiments
  gcloud compute --project ${PROJECT} firewall-rules create "pcf-access-bosh-${DOMAIN_TOKEN}" --allow tcp:22,tcp:80,tcp:443 --description "Allow web and SSH access from internal sources to the BOSH director" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${CIDR} --target-tags "bosh"
  gcloud compute --project ${PROJECT} firewall-rules create "pcf-access-cloud-controller-${DOMAIN_TOKEN}" --allow tcp:80,tcp:443 --description "Allow web access from internal sources to the cloud controller" --network "pcf-${DOMAIN_TOKEN}" --source-ranges ${CIDR} --target-tags "cloud-controller"
}

security () {
  # create a service account and give it a key (parameterize later), not sure why it doesn't have a project specified but that seems right
  gcloud iam service-accounts create bosh-opsman-${DOMAIN_TOKEN} --display-name bosh
  gcloud iam service-accounts keys create ${PROJECT}-bosh-opsman-${DOMAIN_TOKEN}.json --iam-account bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/editor"
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/compute.instanceAdmin"
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/compute.networkAdmin"
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/compute.storageAdmin"

  # setup VCAP SSH for all boxen, this will erase existing SSH keys (FIX!)
  ssh-keygen -P "" -t rsa -f vcap-key -b 4096 -C vcap@local
  sed -i.gcp '1s/^/vcap: /' vcap-key.pub
  gcloud compute --project=${PROJECT} project-info add-metadata --metadata-from-file sshKeys=vcap-key.pub
  mv vcap-key.pub.gcp vcap-key.pub
}

ssl_certs () {
  COMMON_NAME="*.${SUBDOMAIN},*.system.${SUBDOMAIN},*.apps.${SUBDOMAIN}"
  COUNTRY=US
  STATE=MA
  CITY=Cambridge
  ORGANIZATION=crdant.io
  ORG_UNIT=Cloud
  EMAIL=cdantonio@pivotal.io
  SUBJECT="/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORG_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

  openssl req -new -newkey rsa:2048 -days 365 -nodes -sha256 -x509 -keyout "${TMPDIR}/${DOMAIN_TOKEN}.key" -out "${TMPDIR}/${DOMAIN_TOKEN}.crt" -subj "${SUBJECT}"
}

load_balancers () {
  # setup the load balancers
  gcloud compute --project ${PROJECT} instance-groups unmanaged create "pcf-instances-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE} --description "Includes all VM instances that are managed as part of the PCF install."

  # SSH
  gcloud compute --project ${PROJECT} addresses create "pcf-ssh-${DOMAIN_TOKEN}" --region "${REGION}"
  gcloud compute --project ${PROJECT} target-pools create "pcf-ssh-${DOMAIN_TOKEN}" --description "Target pool for load balancing SSH access to PCF instances" --region "${REGION}" --session-affinity "NONE"
  gcloud compute --project ${PROJECT} forwarding-rules create "pcf-ssh-${DOMAIN_TOKEN}" --description "Forwarding rule for load balancing SSH access to PCF instances\"" --region "${REGION}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/us-east1/addresses/pcf-ssh-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "2222" --target-pool "pcf-ssh-${DOMAIN_TOKEN}"

  # HTTP(S)
  gcloud compute --project ${PROJECT} addresses create "pcf-http-router-${DOMAIN_TOKEN}" --global
  gcloud compute --project ${PROJECT} http-health-checks create "pcf-http-router-health-check-${DOMAIN_TOKEN}" --description "Health check for load balancing web access to PCF instances" --request-path "/health" --port="8080" --timeout "5s" --healthy-threshold "2" --unhealthy-threshold "2"
  gcloud compute --project ${PROJECT} backend-services create "pcf-http-router-${DOMAIN_TOKEN}" --description "Backend services for load balancing web access to PCF instances" --session-affinity "NONE"  --http-health-checks "pcf-http-router-health-check-${DOMAIN_TOKEN}"
  gcloud compute --project ${PROJECT} backend-services add-backend "pcf-http-router-${DOMAIN_TOKEN}" --instance-group "pcf-instances-${DOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE}" --description "Backend to map HTTP load balancing to the appropriate instances"
  gcloud compute --project ${PROJECT} url-maps create "pcf-http-router-${DOMAIN_TOKEN}" --default-service "pcf-http-router-${DOMAIN_TOKEN}" --description "URL Map for HTTP load balancer for access to PCF instances"
  gcloud compute --project ${PROJECT} ssl-certificates create "pcf-router-ssl-cert-${DOMAIN_TOKEN}" --certificate "${TMPDIR}/${DOMAIN_TOKEN}.crt"  --private-key "${TMPDIR}/${DOMAIN_TOKEN}.key"
  gcloud compute --project ${PROJECT} target-http-proxies create "pcf-router-http-proxy-${DOMAIN_TOKEN}" --url-map  "pcf-http-router-${DOMAIN_TOKEN}" --description "Backend services for load balancing HTTP access to PCF instances"
  gcloud compute --project ${PROJECT} target-https-proxies create "pcf-router-https-proxy-${DOMAIN_TOKEN}" --url-map "pcf-http-router-${DOMAIN_TOKEN}" --ssl-certificate "pcf-router-ssl-cert-${DOMAIN_TOKEN}" --description "Backend services for load balancing HTTPS access to PCF instances"
  gcloud compute --project ${PROJECT} forwarding-rules create --global "pcf-http-router-${DOMAIN_TOKEN}-forwarding-rule" --description "Forwarding rule for load balancing web (plain-text) access to PCF instances." --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/global/addresses/pcf-http-router-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "80" --target-http-proxy "pcf-router-http-proxy-${DOMAIN_TOKEN}"
  gcloud compute --project ${PROJECT} forwarding-rules create --global "pcf-http-router-${DOMAIN_TOKEN}-forwarding-rule2" --description "Forwarding rule for load balancing web (SSL) access to PCF instances." --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/global/addresses/pcf-http-router-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "443" --target-https-proxy "pcf-router-https-proxy-${DOMAIN_TOKEN}"

  # Websockets (documentation says it reuses a bunch of stuff from the HTTP LB)
  gcloud compute --project ${PROJECT} addresses create "pcf-websockets-${DOMAIN_TOKEN}" --region "${REGION}"
  gcloud compute --project ${PROJECT} target-pools create "pcf-websockets-${DOMAIN_TOKEN}" --description "Target pool for load balancing web access to PCF instances" --region "${REGION}" --session-affinity "NONE"  --http-health-check "pcf-router-health-check-${DOMAIN_TOKEN}"
  gcloud compute --project ${PROJECT} forwarding-rules create "pcf-websockets-${DOMAIN_TOKEN}" --description "Forwarding rule for load balancing web access to PCF instances." --region "${REGION}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/us-east1/addresses/pcf-websockets-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "443" --target-pool "pcf-websockets-${DOMAIN_TOKEN}"

  # TCP Routing
  gcloud compute --project ${PROJECT} addresses create "pcf-tcp-router-${DOMAIN_TOKEN}" --region "${REGION}"
  gcloud compute --project ${PROJECT} target-pools create "pcf-tcp-router-${DOMAIN_TOKEN}" --description "Target pool for load balancing web access to PCF instances" --region "${REGION}" --session-affinity "NONE"
  gcloud compute --project ${PROJECT} forwarding-rules create "pcf-tcp-router-${DOMAIN_TOKEN}" --description "Forwarding rule for load balancing web access to PCF instances." --region "${REGION}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/us-east1/addresses/pcf-tcp-router-${DOMAIN_TOKEN}" --ip-protocol "TCP" --ports "1024-65535" --target-pool "pcf-tcp-router-${DOMAIN_TOKEN}"
  echo "Load balancers for Router: tcp:pcf-websockets-${DOMAIN_TOKEN},http:pcf-http-router-${DOMAIN_TOKEN}"
  echo "Load balancer for Deigo Brain: tcp:pcf-ssh-${DOMAIN_TOKEN}"
  echo "Load balancer for TCP Router: tcp:pcf-tcp-router-${DOMAIN_TOKEN}"
}

dns () {
  gcloud dns managed-zones create ${DNS_ZONE} --dns-name "${SUBDOMAIN}." --description "Zone for ${SUBDOMAIN}"

  # NB: My domain is managed by Route 53 and google seems to change the name servers every time I make a call to managed
  #     the subdomain with them. Since I want these scripts to complete create and teardown everything they need, I need
  #     to coordinate between the two.
  update_root_dns
  sleep $TTL

  gcloud dns record-sets transaction start -z ${DNS_ZONE}

  # HTTP/S router
  HTTP_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-http-router-${DOMAIN_TOKEN}" --global  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z ${DNS_ZONE} --name "*.apps.${SUBDOMAIN}" --ttl ${DNS_TTL} --type A ${HTTP_ADDRESS}
  gcloud dns record-sets transaction add -z ${DNS_ZONE} --name "*.pcf.${SUBDOMAIN}" --ttl ${DNS_TTL} --type A ${HTTP_ADDRESS}

  # ssh router
  SSH_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-ssh-${DOMAIN_TOKEN}" --region "${REGION}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z ${DNS_ZONE} --name "ssh.pcf.${SUBDOMAIN}" --ttl ${DNS_TTL} --type A ${SSH_ADDRESS}

  # websockets router
  WS_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-websockets-${DOMAIN_TOKEN}" --region "${REGION}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z ${DNS_ZONE} --name "doppler.pcf.${SUBDOMAIN}" --ttl ${DNS_TTL} --type A ${WS_ADDRESS}
  gcloud dns record-sets transaction add -z ${DNS_ZONE} --name "loggregator.pcf.${SUBDOMAIN}" --ttl ${DNS_TTL} --type A ${WS_ADDRESS}

  # tcp router
  TCP_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-tcp-router-${DOMAIN_TOKEN}" --region "${REGION}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction add -z ${DNS_ZONE} --name "tcp.${SUBDOMAIN}" --ttl ${DNS_TTL} --type A ${TCP_ADDRESS}

  gcloud dns record-sets transaction execute -z ${DNS_ZONE}
}

update_root_dns () {
  local ZONE_ID="Z1TS8OPDHRZ56V"
  local DNS_COMMENT="Modifying delegation for new Google nameservers used for subdomain $SUBDOMAIN"
  local CHANGE_BATCH=`mktemp -t prepare.dns.zonefile`
  local NAME_SERVERS=( `gcloud dns managed-zones describe $DNS_ZONE --format json | jq -r  '.nameServers | join(" ")'` )

  cat > ${CHANGE_BATCH} <<CHANGES
    {
      "Comment":"$DNS_COMMENT",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value": "$NAME_SERVERS[1]"
              },
              {
                "Value": "$NAME_SERVERS[2]"
              },
              {
                "Value": "$NAME_SERVERS[3]"
              },
              {
                "Value": "$NAME_SERVERS[4]"
              }
            ],
            "Name":"$SUBDOMAIN",
            "Type": "NS",
            "TTL":$DNS_TTL
          }
        }
      ]
    }
CHANGES

  aws --profile personal route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file://"${CHANGE_BATCH}"
}

blobstore () {
  # create storage bucket for BOSH blobstore -- uncertain permissions are needed
  gsutil mb -l us-east1 gs://bosh-blobstore-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://bosh-blobstore-pcf-${DOMAIN_TOKEN}

  # create storage buckets for ERT file storage -- uncertain permissions are needed
  gsutil mb -l us-east1 gs://blobstore-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://blobstore-pcf-${DOMAIN_TOKEN}
  gsutil mb -l us-east1 gs://buildpacks-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://buildpacks-pcf-${DOMAIN_TOKEN}
  gsutil mb -l us-east1 gs://droplets-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://droplets-pcf-${DOMAIN_TOKEN}
  gsutil mb -l us-east1 gs://packages-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://packages-pcf-${DOMAIN_TOKEN}
  gsutil mb -l us-east1 gs://resources-pcf-${DOMAIN_TOKEN}
  gsutil acl ch -u bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com:O gs://resources-pcf-${DOMAIN_TOKEN}
}

ops_manager () {
  # Ops Manager (specific to 1.8.7 now)
  gcloud compute --project ${PROJECT} images create "pcf-ops-manager-187" --description "Primary disk for Pivotal Cloud Foundry Operations Manager" --source-uri "https://storage.googleapis.com/ops-manager-releases-us/pcf-gcp-1.8.7.tar.gz"

  # make sure we can get to it
  gcloud compute --project ${PROJECT} addresses create "pcf-ops-manager" --region "${REGION}"
  OPS_MANAGER_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-ops-manager" --region "${REGION}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction start -z ${DNS_ZONE}
  gcloud dns record-sets transaction add -z ${DNS_ZONE} --name "manager.${SUBDOMAIN}" --ttl ${DNS_TTL} --type A ${OPS_MANAGER_ADDRESS}
  gcloud dns record-sets transaction execute -z ${DNS_ZONE}

  gcloud compute --project ${PROJECT} instances create "pcf-ops-manager-187" --zone ${AVAILABILITY_ZONE} --machine-type "n1-standard-1" --subnet "pcf-us-east1-${DOMAIN_TOKEN}" --private-network-ip "10.0.0.4" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/us-east1/addresses/pcf-ops-manager" --maintenance-policy "MIGRATE" --scopes bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com="https://www.googleapis.com/auth/cloud-platform" --tags "http-server","https-server","pcf-opsmanager" --image "/${PROJECT}/pcf-ops-manager-187" --boot-disk-size "200" --boot-disk-type "pd-standard" --boot-disk-device-name "pcf-operations-manager-187"
  ssh-keygen -P "" -t rsa -f ubuntu-key -b 4096 -C ubuntu@local
  sed -i.gcp '1s/^/ubuntu: /' ubuntu-key.pub
  gcloud compute instances add-metadata "pcf-ops-manager-187" --zone ${AVAILABILITY_ZONE} --metadata-from-file "ssh-keys=ubuntu-key.pub"
  mv ubuntu-key.pub.gcp ubuntu-key.pub

  # now let's get ops manager going
  curl --insecure "https://manager.$SUBDOMAIN/api/v0/setup" -X POST \
      -H "Content-Type: application/json" -d @api-calls/setup.json

  # prepare for downloading products from the Pivotal Network
  uaac target "https://manager.$SUBDOMAIN/uaa" --skip-ssl-validation
  uaac token owner get opsman admin --secret='' --password="abscound-novena-shut-pierre"
  UAA_ACCESS_TOKEN=`uaac context | grep "access_token" | sed '1s/^[ \t]*access_token: //'`
  curl --insecure "https://manager.$SUBDOMAIN/api/v0/settings/pivotal_network_settings" -X PUT \
      -H "Authorization: Bearer $UAA_ACCESS_TOKEN" \
      -H "Content-Type: application/json" <<PIVNET_SETTINGS
  {
    "pivotal_network_settings":
      { "api_token": "$PIVNET_TOKEN" }
  }
PIVNET_SETTINGS
}

service_broker () {
  # prepare for the google service broker
  gcloud iam service-accounts create service-broker-${DOMAIN_TOKEN} --display-name bosh
  gcloud iam service-accounts keys create ${PROJECT}-service-broker-${DOMAIN_TOKEN}.json --iam-account service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com
  gcloud projects add-iam-policy-binding ${PROJECT} --member "serviceAccount:service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com" --role "roles/owner"
  gcloud sql --project=${PROJECT} instances create gcp-service-broker-db-${DOMAIN_TOKEN} --assign-ip --require-ssl --authorized-networks="${ALL_INTERNET}" --region=${REGION}  --gce-zone=${AVAILABILITY_ZONE}
  gcloud sql --project=${PROJECT} instances set-root-password gcp-service-broker-db-${DOMAIN_TOKEN} --password="crest-tory-hump-anode"
  # server connection requirements
  gcloud --format json sql instances describe gcp-service-broker-db-${DOMAIN_TOKEN} | jq --raw-output '.serverCaCert .cert ' > gcp-service-broker-db-server.crt
  gcloud --format json sql instances describe gcp-service-broker-db-${DOMAIN_TOKEN} | jq --raw-output ' .ipAddresses [0] .ipAddress ' > gcp-service-broker-db.ip
  # client connection requirements
  gcloud sql --project=${PROJECT} ssl-certs create pcf.$SUBDOMAIN gcp-service-broker-db-client.key --instance "gcp-service-broker-db-${DOMAIN_TOKEN}"
  gcloud sql --format=json ssl-certs describe pcf.$SUBDOMAIN --instance "gcp-service-broker-db-${DOMAIN_TOKEN}" | jq --raw-output ' .cert ' > gcp-service-broker-db-client.crt
  # setup a user
  mysql -uroot -pcrest-tory-hump-anode -h 173.194.243.151 --ssl-ca=gcp-service-broker-db-server.crt \
    --ssl-cert=gcp-service-broker-db-client.crt --ssl-key=gcp-service-broker-db-client.key <<SQL
  CREATE DATABASE servicebroker;
  CREATE USER 'pcf'@'%' IDENTIFIED BY 'arachnid-souvenir-brunch';
  GRANT ALL PRIVILEGES ON servicebroker.* TO 'pcf'@'%' WITH GRANT OPTION;
SQL
}

products () {
  echo "We'll install products here later..."
}

env
setup
network
security
ssl_certs
load_balancers
dns
blobstore
ops_manager
products
