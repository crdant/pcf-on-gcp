# teardown PCF on GCP
# currently handles only the resources that prepare.sh creates, and will fail due to dependencies if resources
# created by OpsManager (or otherwise) that depend on these prerequisites still exist

env () {
  ACCOUNT="cdantonio@pivotal.io"
  PROJECT="fe-cdantonio"
  REGION="us-east1"
  AVAILABILITY_ZONE="us-east1-b"
  DOMAIN="crdant.io"
  DOMAIN_TOKEN=`echo ${DOMAIN} | tr . -`
  SUBDOMAIN="gcp.${DOMAIN}"
  DNS_ZONE=`echo ${SUBDOMAIN} | tr . -`
  CIDR="10.0.0.0/20"
}

setup () {
  # make sure our API components are up-to-date
  gcloud components update

  # log in (parameterize later)
  gcloud auth login cdantonio@pivotal.io
  gcloud config set project ${PROJECT}
  gcloud config set compute/zone ${AVAILABILITY_ZONE}
  gcloud config set compute/region ${REGION}
}

vms () {
  # delete all bosh managed VMs
  for instance in `gcloud compute --project ${PROJECT} instances list --filter='tags.items:pcf-vms' --uri`; do
      gcloud compute --project ${PROJECT} instances delete $instance --quiet &
  done
}

service_broker () {
  # drop service broker database and supporting account
  gcloud sql --project=${PROJECT} instances delete gcp-service-broker-db-${DOMAIN_TOKEN} --quiet
  gcloud iam service-accounts delete service-broker-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com --quiet
}

blobstore () {
  # drop cloud storage buckets
  gsutil rm -r gs://blobstore-pcf-${DOMAIN_TOKEN}
  gsutil rm -r gs://buildpacks-pcf-${DOMAIN_TOKEN}
  gsutil rm -r gs://droplets-pcf-${DOMAIN_TOKEN}
  gsutil rm -r gs://packages-pcf-${DOMAIN_TOKEN}
  gsutil rm -r gs://resources-pcf-${DOMAIN_TOKEN}
}

ops_manager () {
  # remove from DNS
  OPS_MANAGER_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-ops-manager" --region "${REGION}" | jq --raw-output ".address"`
  gcloud dns record-sets transaction start -z ${DNS_ZONE}
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "manager.${SUBDOMAIN}" --ttl ${DNS_TTL} --type A ${OPS_MANAGER_ADDRESS}
  gcloud dns record-sets transaction execute -z ${DNS_ZONE}

  # release public IP
  gcloud compute --project ${PROJECT} addresses delete "pcf-ops-manager" --region "${REGION}" --quiet

  # drop Ops Manager
  gcloud compute --project ${PROJECT} instances delete "pcf-ops-manager-187" --zone ${AVAILABILITY_ZONE} --quiet
  gcloud compute --project ${PROJECT} addresses delete "pcf-ops-manager" --region ${REGION} --quiet
  gcloud compute --project ${PROJECT} images delete "pcf-ops-manager-187" --quiet
  rm ubuntu-key ubuntu-key.pub
}

load_balancers () {
  # tear down load balancers
  # TCP Routing
  gcloud compute --project ${PROJECT} forwarding-rules delete "pcf-tcp-router-${DOMAIN_TOKEN}" --region ${REGION} --quiet
  gcloud compute --project ${PROJECT} target-pools delete "pcf-tcp-router-${DOMAIN_TOKEN}" --region ${REGION} --quiet
  gcloud compute --project ${PROJECT} addresses delete "pcf-tcp-router-${DOMAIN_TOKEN}" --region ${REGION} --quiet

  # Websockets
  gcloud compute --project ${PROJECT} forwarding-rules delete "pcf-websockets-${DOMAIN_TOKEN}" --region ${REGION} --quiet
  gcloud compute --project ${PROJECT} target-pools delete "pcf-websockets-${DOMAIN_TOKEN}" --region ${REGION} --quiet
  gcloud compute --project ${PROJECT} addresses delete "pcf-websockets-${DOMAIN_TOKEN}" --region ${REGION} --quiet

  # HTTP(S)
  gcloud compute --project ${PROJECT} forwarding-rules delete --global "pcf-http-router-${DOMAIN_TOKEN}-forwarding-rule" "pcf-http-router-${DOMAIN_TOKEN}-forwarding-rule2" --quiet
  gcloud compute --project ${PROJECT} target-https-proxies delete "pcf-router-https-proxy-${DOMAIN_TOKEN}" --quiet
  gcloud compute --project ${PROJECT} target-http-proxies delete "pcf-router-http-proxy-${DOMAIN_TOKEN}" --quiet
  gcloud compute --project ${PROJECT} ssl-certificates delete "pcf-router-ssl-cert-${DOMAIN_TOKEN}" --quiet
  gcloud compute --project ${PROJECT} url-maps delete "pcf-http-router-${DOMAIN_TOKEN}" --quiet
  gcloud compute --project ${PROJECT} backend-services remove-backend "pcf-http-router-${DOMAIN_TOKEN}" --instance-group "pcf-instances-${DOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE}" --quiet
  gcloud compute --project ${PROJECT} backend-services delete "pcf-http-router-${DOMAIN_TOKEN}" --quiet
  gcloud compute --project ${PROJECT} http-health-checks delete "pcf-http-router-health-check-${DOMAIN_TOKEN}" --quiet
  gcloud compute --project ${PROJECT} addresses delete "pcf-router-${DOMAIN_TOKEN}" --global --quiet

  # SSH
  gcloud compute --project ${PROJECT} forwarding-rules delete "pcf-ssh-${DOMAIN_TOKEN}" --region ${REGION} --quiet
  gcloud compute --project ${PROJECT} target-pools delete "pcf-ssh-${DOMAIN_TOKEN}" --region ${REGION} --quiet
  gcloud compute --project ${PROJECT} addresses delete "pcf-ssh-${DOMAIN_TOKEN}" --region ${REGION} --quiet

  # remove the instance group that they load balancers depend on
  gcloud compute --project ${PROJECT} instance-groups unmanaged delete "pcf-instances" --zone=${AVAILABILITY_ZONE} --quiet

}

dns () {
  # clear out the records first so we can remove the zone (apparenlty it won't let me do it)
  gcloud dns record-sets transaction start -z ${DNS_ZONE} --quiet

  # HTTP/S router
  HTTP_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-router-${DOMAIN_TOKEN}" --region ${REGION}  | jq --raw-output ".address"`
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "manager.${SUBDOMAIN}" --ttl 300 --type A ${HTTP_ADDRESS} --quiet
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "*.apps.${SUBDOMAIN}" --ttl 300 --type A ${HTTP_ADDRESS} --quiet
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "*.pcf.${SUBDOMAIN}" --ttl 300 --type A ${HTTP_ADDRESS} --quiet

  # ssh router
  SSH_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-ssh-${DOMAIN_TOKEN}" --region ${REGION}  | jq --raw-output ".address"`
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "ssh.pcf.${SUBDOMAIN}" --ttl 300 --type A ${SSH_ADDRESS} --quiet

  # websockets router
  WS_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-websockets-${DOMAIN_TOKEN}" --region ${REGION}  | jq --raw-output ".address"`
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "doppler.pcf.${SUBDOMAIN}" --ttl 300 --type A ${WS_ADDRESS} --quiet
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "loggregator.pcf.${SUBDOMAIN}" --ttl 300 --type A ${WS_ADDRESS} --quiet

  # tcp router
  TCP_ADDRESS=`gcloud compute --project ${PROJECT} --format json addresses describe "pcf-tcp-router-${DOMAIN_TOKEN}" --region ${REGION}  | jq --raw-output ".address"`
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "tcp.${SUBDOMAIN}" --ttl 300 --type A ${TCP_ADDRESS} --quiet

  gcloud dns record-sets transaction execute -z ${DNS_ZONE} --quiet

  gcloud dns managed-zones delete ${DNS_ZONE} --quiet
}

security () {
  # remove VCAP SSH from metadata provided to all boxen, this will not preserve keys that were added in different ways (FIX!)
  gcloud compute --project=${PROJECT} project-info remove-metadata --keys sshKeys --quiet
  rm vcap-key vcap-key.pub

  # delete the service account
  gcloud iam service-accounts delete bosh-opsman-${DOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com --quiet
}

network () {
  # remove the firewall rules I added based on my earlier experimentation
  gcloud compute --project ${PROJECT} firewall-rules delete "pcf-access-bosh" --quiet
  gcloud compute --project ${PROJECT} firewall-rules delete "pcf-access-cloud-controller" --quiet

  # remove necessary firewall rules
  gcloud compute --project ${PROJECT} firewall-rules delete "pcf-allow-internal-traffic" --quiet
  gcloud compute --project ${PROJECT} firewall-rules delete "pcf-access-opsmanager" --quiet
  gcloud compute --project ${PROJECT} firewall-rules delete "pcf-access-load-balancers" --quiet
  gcloud compute --project ${PROJECT} firewall-rules delete "pcf-access-tcp-load-balancers" --quiet

  # remove the a network
  gcloud compute --project ${PROJECT} networks subnets delete "pcf-us-east1-${DOMAIN_TOKEN}" --region ${REGION} --quiet
  gcloud compute --project ${PROJECT} networks delete "pcf-${DOMAIN_TOKEN}" --quiet
}

env
setup
vms
blobstore
ops_manager
dns
load_balancers
security
network
