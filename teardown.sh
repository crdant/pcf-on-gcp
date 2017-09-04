#!/usr/bin/env bash

# teardown PCF on GCP
# currently handles only the resources that prepare.sh creates, and will fail due to dependencies if resources
# created by OpsManager (or otherwise) that depend on these prerequisites still exist

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/util.sh"
. "${BASEDIR}/lib/env.sh"
prepare_env

. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/personal.sh"
. "${BASEDIR}/lib/setup.sh"

vms () {
  # delete all bosh managed VMs
  for instance in `gcloud compute --project "${PROJECT}" instances list --filter='tags.items:pcf-vms' --uri`; do
      gcloud compute --project "${PROJECT}" instances delete $instance --quiet &
  done
}

stackdriver () {
  echo "Preparing for GCP Stackdriver Nozzle installation..."

  # prepare for the stackdriver nozzle
  echo "Setting up service account stackdriver-nozzle-${SUBDOMAIN_TOKEN}"
  gcloud iam --project "${PROJECT}" service-accounts delete "stackdriver-nozzle-${SUBDOMAIN_TOKEN}" --quiet
  rm "${KEYDIR}/${PROJECT}-stackdriver-nozzle-${SUBDOMAIN_TOKEN}.json"
}

service_broker () {
  gcloud sql --project="${PROJECT}" instances delete `cat "${WORKDIR}/gcp-service-broker-db.name"` --quiet
  rm "${KEYDIR}/gcp-service-broker-db-server.crt" "${KEYDIR}/gcp-service-broker-db-client.key" "${KEYDIR}/gcp-service-broker-db-client.crt"
  gcloud iam service-accounts delete service-broker-${SUBDOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com --quiet
}

cloud_foundry () {
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --quiet
  gcloud dns record-sets transaction remove -z "${DNS_ZONE}" --name "mysql.${SUBDOMAIN}" --ttl "${DNS_TTL}" --type A "10.0.15.98" "10.0.15.99" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"
}

products () {
  service_broker
  cloud_foundry
}

blobstore () {
  # drop cloud storage buckets
  gsutil rm -r gs://buildpacks-pcf-${SUBDOMAIN_TOKEN}
  gsutil rm -r gs://droplets-pcf-${SUBDOMAIN_TOKEN}
  gsutil rm -r gs://packages-pcf-${SUBDOMAIN_TOKEN}
  gsutil rm -r gs://resources-pcf-${SUBDOMAIN_TOKEN}
}

ops_manager () {
  # remove from DNS
  OPS_MANAGER_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "pcf-ops-manager-${SUBDOMAIN_TOKEN}" --region "${REGION_1}" | jq --raw-output ".address"`
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --quiet
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "${OPS_MANAGER_FQDN}" --ttl ${DNS_TTL} --type A ${OPS_MANAGER_ADDRESS} --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction execute -z ${DNS_ZONE} --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"

  # release public IP
  gcloud compute --project "${PROJECT}" addresses delete "pcf-ops-manager-${SUBDOMAIN_TOKEN}" --region ${REGION_1} --quiet

  # drop Ops Manager
  gcloud compute --project "${PROJECT}" instances delete "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${SUBDOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --quiet
  gcloud compute --project "${PROJECT}" images delete "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}" --quiet
  rm ${KEYDIR}/ubuntu-key ${KEYDIR}/ubuntu-key.pub
}

load_balancers () {
  # tear down load balancers
  # TCP Routing
  gcloud compute --project "${PROJECT}" forwarding-rules delete "${TCP_LOAD_BALANCER_NAME}" --region ${REGION_1} --quiet
  gcloud compute --project "${PROJECT}" target-pools delete "${TCP_LOAD_BALANCER_NAME}" --region ${REGION_1} --quiet
  gcloud compute --project "${PROJECT}" addresses delete "${TCP_LOAD_BALANCER_NAME}" --region ${REGION_1} --quiet

  # Websockets
  gcloud compute --project "${PROJECT}" forwarding-rules delete "${WS_LOAD_BALANCER_NAME}" --region ${REGION_1} --quiet
  gcloud compute --project "${PROJECT}" target-pools delete "${WS_LOAD_BALANCER_NAME}" --region ${REGION_1} --quiet
  gcloud compute --project "${PROJECT}" addresses delete "${WS_LOAD_BALANCER_NAME}" --region ${REGION_1} --quiet

  # HTTP(S)
  gcloud compute --project "${PROJECT}" forwarding-rules delete --global "${HTTP_LOAD_BALANCER_NAME}-forwarding-rule" "${HTTP_LOAD_BALANCER_NAME}-forwarding-rule2" --quiet
  gcloud compute --project "${PROJECT}" target-https-proxies delete "pcf-router-https-proxy-${SUBDOMAIN_TOKEN}" --quiet
  gcloud compute --project "${PROJECT}" target-http-proxies delete "pcf-router-http-proxy-${SUBDOMAIN_TOKEN}" --quiet
  gcloud compute --project "${PROJECT}" ssl-certificates delete "pcf-router-ssl-cert-${SUBDOMAIN_TOKEN}" --quiet
  gcloud compute --project "${PROJECT}" url-maps delete "${HTTP_LOAD_BALANCER_NAME}" --quiet
  gcloud compute --project "${PROJECT}" backend-services remove-backend "${HTTP_LOAD_BALANCER_NAME}" --global --instance-group "pcf-instances-${AVAILABILITY_ZONE_1}-${SUBDOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_1}" --quiet
  gcloud compute --project "${PROJECT}" backend-services remove-backend "${HTTP_LOAD_BALANCER_NAME}" --global --instance-group "pcf-instances-${AVAILABILITY_ZONE_2}-${SUBDOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_2}" --quiet
  gcloud compute --project "${PROJECT}" backend-services remove-backend "${HTTP_LOAD_BALANCER_NAME}" --global --instance-group "pcf-instances-${AVAILABILITY_ZONE_3}-${SUBDOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_3}" --quiet
  gcloud compute --project "${PROJECT}" backend-services delete "${HTTP_LOAD_BALANCER_NAME}" --global --quiet
  gcloud compute --project "${PROJECT}" http-health-checks delete "pcf-http-router-health-check-${SUBDOMAIN_TOKEN}" --quiet
  gcloud compute --project "${PROJECT}" addresses delete "${HTTP_LOAD_BALANCER_NAME}" --global --quiet

  # SSH
  gcloud compute --project "${PROJECT}" forwarding-rules delete "${SSH_LOAD_BALANCER_NAME}" --region ${REGION_1} --quiet
  gcloud compute --project "${PROJECT}" target-pools delete "${SSH_LOAD_BALANCER_NAME}" --region ${REGION_1} --quiet
  gcloud compute --project "${PROJECT}" addresses delete "${SSH_LOAD_BALANCER_NAME}" --region ${REGION_1} --quiet

  # remove the instance group that they load balancers depend on
  gcloud compute --project "${PROJECT}" instance-groups unmanaged delete "pcf-instances-${AVAILABILITY_ZONE_1}-${SUBDOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --quiet
  gcloud compute --project "${PROJECT}" instance-groups unmanaged delete "pcf-instances-${AVAILABILITY_ZONE_2}-${SUBDOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_2} --quiet
  gcloud compute --project "${PROJECT}" instance-groups unmanaged delete "pcf-instances-${AVAILABILITY_ZONE_3}-${SUBDOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_3} --quiet
}

dns () {
  # clear out the records first so we can remove the zone (apparenlty it won't let me do it)
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --quiet

  # HTTP/S router
  HTTP_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${HTTP_LOAD_BALANCER_NAME}" --global  | jq --raw-output ".address"`
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "*.${PCF_APPS_DOMAIN}" --ttl 300 --type A ${HTTP_ADDRESS} --quiet --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "*.${PCF_SYSTEM_DOMAIN}" --ttl 300 --type A ${HTTP_ADDRESS} --quiet --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"

  # ssh router
  SSH_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${SSH_LOAD_BALANCER_NAME}" --region ${REGION_1}  | jq --raw-output ".address"`
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "ssh.${PCF_SYSTEM_DOMAIN}" --ttl 300 --type A ${SSH_ADDRESS} --quiet --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"

  # websockets router
  WS_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${WS_LOAD_BALANCER_NAME}" --region ${REGION_1}  | jq --raw-output ".address"`
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "doppler.${PCF_SYSTEM_DOMAIN}" --ttl 300 --type A ${WS_ADDRESS} --quiet --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "loggregator.${PCF_SYSTEM_DOMAIN}" --ttl 300 --type A ${WS_ADDRESS} --quiet --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"

  # tcp router
  TCP_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${TCP_LOAD_BALANCER_NAME}" --region ${REGION_1}  | jq --raw-output ".address"`
  gcloud dns record-sets transaction remove -z ${DNS_ZONE} --name "tcp.${SUBDOMAIN}" --ttl 300 --type A ${TCP_ADDRESS} --quiet --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"

  gcloud dns record-sets transaction execute -z ${DNS_ZONE} --quiet --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml"

  gcloud dns managed-zones delete ${DNS_ZONE} --quiet
}

security () {
  # remove VCAP SSH from metadata provided to all boxen, this will not preserve keys that were added in different ways (FIX!)
  gcloud compute --project=${PROJECT} project-info remove-metadata --keys sshKeys --quiet
  rm ${KEYDIR}/vcap-key ${KEYDIR}/vcap-key.pub

  # remove permissions os the key will delete
  gcloud projects remove-iam-policy-binding ${PROJECT} --member "serviceAccount:${SERVICE_ACCOUNT}" --role "roles/editor" --no-user-output-enabled
  gcloud projects remove-iam-policy-binding ${PROJECT} --member "serviceAccount:${SERVICE_ACCOUNT}" --role "roles/iam.serviceAccountActor" --no-user-output-enabled
  gcloud projects remove-iam-policy-binding ${PROJECT} --member "serviceAccount:${SERVICE_ACCOUNT}" --role "roles/compute.instanceAdmin" --no-user-output-enabled
  gcloud projects remove-iam-policy-binding ${PROJECT} --member "serviceAccount:${SERVICE_ACCOUNT}" --role "roles/compute.networkAdmin" --no-user-output-enabled
  gcloud projects remove-iam-policy-binding ${PROJECT} --member "serviceAccount:${SERVICE_ACCOUNT}" --role "roles/compute.storageAdmin" --no-user-output-enabled
  gcloud projects remove-iam-policy-binding ${PROJECT} --member "serviceAccount:${SERVICE_ACCOUNT}" --role "roles/storage.admin" --no-user-output-enabled

  # delete the key
  KEYID=`jq --raw-output '.private_key_id' "${key_file}" `
  gcloud iam service-accounts --project "${PROJECT}" keys delete "${KEYID}" --iam-account "${SERVICE_ACCOUNT}" --no-user-output-enabled

  # delete the service account
  gcloud iam service-accounts delete pcf-deployment-${SUBDOMAIN_TOKEN}@${PROJECT}.iam.gserviceaccount.com --quiet

  # get rid of the saved passwords
  passwords
}

passwords () {
    rm "${PASSWORD_LIST}"
}

network () {
  # remove the firewall rules I added based on my earlier experimentation
  gcloud compute --project "${PROJECT}" firewall-rules delete "pcf-access-bosh-${SUBDOMAIN_TOKEN}" --quiet
  gcloud compute --project "${PROJECT}" firewall-rules delete "pcf-access-cloud-controller-${SUBDOMAIN_TOKEN}" --quiet

  # remove firewall rule for the IPSec AddOn
  gcloud compute --project "${PROJECT}" firewall-rules delete "pcf-ipsec-${SUBDOMAIN_TOKEN}" --quiet

  # remove necessary firewall rules
  gcloud compute --project "${PROJECT}" firewall-rules delete "pcf-allow-internal-traffic-${SUBDOMAIN_TOKEN}" --quiet
  gcloud compute --project "${PROJECT}" firewall-rules delete "pcf-access-opsmanager-${SUBDOMAIN_TOKEN}" --quiet
  gcloud compute --project "${PROJECT}" firewall-rules delete "pcf-access-load-balancers-${SUBDOMAIN_TOKEN}" --quiet
  gcloud compute --project "${PROJECT}" firewall-rules delete "pcf-access-tcp-load-balancers-${SUBDOMAIN_TOKEN}" --quiet

  # remove the a network
  gcloud compute --project "${PROJECT}" networks subnets delete "pcf-services-${REGION_1}-${SUBDOMAIN_TOKEN}" --region ${REGION_1} --quiet
  gcloud compute --project "${PROJECT}" networks subnets delete "pcf-tiles-${REGION_1}-${SUBDOMAIN_TOKEN}" --region ${REGION_1} --quiet
  gcloud compute --project "${PROJECT}" networks subnets delete "pcf-deployment--${REGION_1}-${SUBDOMAIN_TOKEN}" --region ${REGION_1} --quiet
  gcloud compute --project "${PROJECT}" networks subnets delete "pcf-infra-${REGION_1}-${SUBDOMAIN_TOKEN}" --region ${REGION_1} --quiet

  gcloud compute --project "${PROJECT}" networks delete "pcf-${SUBDOMAIN_TOKEN}" --quiet
}

START_TIMESTAMP=`date`
START_SECONDS=`date +%s`
prepare_env
echo "Started tearing down Cloud Foundry installation in Google Cloud Platform project ${PROJECT} at ${START_TIMESTAMP}..."
setup

if [ $# -gt 0 ]; then
  while [ $# -gt 0 ]; do
    case $1 in
      network)
        network
        ;;
      security)
        security
        ;;
      vms)
        vms
        ;;
      load_balanacers | lbs | balancers)
        load_balancers
        ;;
      dns)
        dns
        ;;
      blobstore)
        blobstore
        ;;
      products)
        products
        ;;
      ops_manager | manager | om)
        ops_manager
        ;;
      * )
        echo "Unrecognized option: $1" 1>&2
        exit 1
        ;;
    esac
    shift
    exit
  done
fi

vms
products
blobstore
ops_manager
dns
load_balancers
security
network

END_TIMESTAMP=`date`
END_SECONDS=`date +%s`
ELAPSED_TIME=`echo $((END_SECONDS-START_SECONDS)) | awk '{print int($1/60)":"int($1%60)}'`
echo "Finished tearing down Cloud Foundry installation in Google Cloud Platform project ${PROJECT} at ${END_TIMESTAMP} (elapsed time ${ELAPSED_TIME})."
