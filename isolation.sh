#!/usr/bin/env bash
# prepare to install PCF on GCP

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/personal.sh"
. "${BASEDIR}/lib/setup.sh"
. "${BASEDIR}/lib/login_ops_manager.sh"
. "${BASEDIR}/lib/random_phrase.sh"
. "${BASEDIR}/lib/generate_passphrase.sh"
. "${BASEDIR}/lib/ssl_certificates.sh"
. "${BASEDIR}/lib/eula.sh"
. "${BASEDIR}/lib/guid.sh"
. "${BASEDIR}/lib/networks_azs.sh"

ISOLATION_CIDR=10.2.0.0/24
ISOLATION_HTTP_LOAD_BALANCER_NAME="pcf-http-router-isolation-${SUBDOMAIN_TOKEN}"
ISOLATION_WS_LOAD_BALANCER_NAME="pcf-websockets-isolation-${SUBDOMAIN_TOKEN}"

gcloud compute --project "${PROJECT}" networks subnets create "pcf-isolation-${REGION_1}-${SUBDOMAIN_TOKEN}" --network "pcf-${SUBDOMAIN_TOKEN}" --region "${REGION_1}" --range 10.2.0.0/20 --no-user-output-enabled

# instance groups
echo "Creating instance groups for each availability zone (${AVAILABILITY_ZONE_1}, ${AVAILABILITY_ZONE_2}, ${AVAILABILITY_ZONE_3})..."
gcloud compute --project "${PROJECT}" instance-groups unmanaged create "pcf-instances-isolation-${AVAILABILITY_ZONE_1}-${SUBDOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --description "Includes VM instances that are managed as part of the PCF install in ${AVAILABILITY_ZONE_1}." --no-user-output-enabled
gcloud compute --project "${PROJECT}" instance-groups unmanaged create "pcf-instances-isolation-${AVAILABILITY_ZONE_2}-${SUBDOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_2} --description "Includes VM instances that are managed as part of the PCF install in ${AVAILABILITY_ZONE_2}." --no-user-output-enabled
gcloud compute --project "${PROJECT}" instance-groups unmanaged create "pcf-instances-isolation-${AVAILABILITY_ZONE_3}-${SUBDOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_3} --description "Includes VM instances that are managed as part of the PCF install in ${AVAILABILITY_ZONE_3}." --no-user-output-enabled
echo "Instance groups pcf-instances-isolation-${AVAILABILITY_ZONE_1}-${SUBDOMAIN_TOKEN}, pcf-instances-isolation-${AVAILABILITY_ZONE_2}-${SUBDOMAIN_TOKEN}, and pcf-instances-isolation-${AVAILABILITY_ZONE_3}-${SUBDOMAIN_TOKEN} created."

# HTTP(S)
echo "Creating HTTP(S) load balancer..."
gcloud compute --project "${PROJECT}" addresses create "${ISOLATION_HTTP_LOAD_BALANCER_NAME}" --global --no-user-output-enabled
gcloud compute --project "${PROJECT}" http-health-checks create "pcf-http-router-isolation-health-check-${SUBDOMAIN_TOKEN}" --description "Health check for load balancing web access to PCF instances" --request-path "/health" --port="8080" --timeout "5s" --healthy-threshold "2" --unhealthy-threshold "2" --no-user-output-enabled
gcloud compute --project "${PROJECT}" backend-services create "${ISOLATION_HTTP_LOAD_BALANCER_NAME}" --description "Backend services for load balancing web access to PCF instances" --global --session-affinity "NONE"  --http-health-checks "pcf-http-router-health-check-${SUBDOMAIN_TOKEN}" --no-user-output-enabled
gcloud compute --project "${PROJECT}" backend-services add-backend "pcf-http-router-isolation-${SUBDOMAIN_TOKEN}" --global --instance-group "pcf-instances-isolation-${AVAILABILITY_ZONE_1}-${SUBDOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_1}" --description "Backend to map HTTP load balancing to the appropriate instances in ${AVAILABILITY_ZONE_1}." --no-user-output-enabled
gcloud compute --project "${PROJECT}" backend-services add-backend "pcf-http-router-isolation-${SUBDOMAIN_TOKEN}" --global --instance-group "pcf-instances-isolation-${AVAILABILITY_ZONE_2}-${SUBDOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_2}" --description "Backend to map HTTP load balancing to the appropriate instances in ${AVAILABILITY_ZONE_2}." --no-user-output-enabled
gcloud compute --project "${PROJECT}" backend-services add-backend "pcf-http-router-isolation-${SUBDOMAIN_TOKEN}" --global --instance-group "pcf-instances-isolation-${AVAILABILITY_ZONE_3}-${SUBDOMAIN_TOKEN}" --instance-group-zone "${AVAILABILITY_ZONE_3}" --description "Backend to map HTTP load balancing to the appropriate instances in ${AVAILABILITY_ZONE_3}." --no-user-output-enabled
gcloud compute --project "${PROJECT}" url-maps create "${ISOLATION_HTTP_LOAD_BALANCER_NAME}" --default-service "${ISOLATION_HTTP_LOAD_BALANCER_NAME}" --description "URL Map for HTTP load balancer for access to PCF instances" --no-user-output-enabled
gcloud compute --project "${PROJECT}" ssl-certificates create "pcf-router-isolation-ssl-cert-${SUBDOMAIN_TOKEN}" --certificate "${KEYDIR}/${SUBDOMAIN_TOKEN}.crt"  --private-key "${KEYDIR}/${SUBDOMAIN_TOKEN}.key" --no-user-output-enabled
gcloud compute --project "${PROJECT}" target-http-proxies create "pcf-router-isolation-http-proxy-${SUBDOMAIN_TOKEN}" --url-map  "${ISOLATION_HTTP_LOAD_BALANCER_NAME}" --description "Backend services for load balancing HTTP access to PCF instances"  --no-user-output-enabled
gcloud compute --project "${PROJECT}" target-https-proxies create "pcf-router-isolation-https-proxy-${SUBDOMAIN_TOKEN}" --url-map "${ISOLATION_HTTP_LOAD_BALANCER_NAME}" --ssl-certificate "pcf-router-ssl-cert-${SUBDOMAIN_TOKEN}" --description "Backend services for load balancing HTTPS access to PCF instances" --no-user-output-enabled
gcloud compute --project "${PROJECT}" forwarding-rules create --global "pcf-http-router-isolation-${SUBDOMAIN_TOKEN}-forwarding-rule" --description "Forwarding rule for load balancing web (plain-text) access to PCF instances." --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/global/addresses/pcf-http-router-isolation-${SUBDOMAIN_TOKEN}" --ip-protocol "TCP" --ports "80" --target-http-proxy "pcf-router-isolation-http-proxy-${SUBDOMAIN_TOKEN}" --no-user-output-enabled
gcloud compute --project "${PROJECT}" forwarding-rules create --global "pcf-http-router-isolation-${SUBDOMAIN_TOKEN}-forwarding-rule2" --description "Forwarding rule for load balancing web (SSL) access to PCF instances." --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/global/addresses/pcf-http-router-isolation-${SUBDOMAIN_TOKEN}" --ip-protocol "TCP" --ports "443" --target-https-proxy "pcf-router-isolation-https-proxy-${SUBDOMAIN_TOKEN}" --no-user-output-enabled
echo "HTTP(S) load balancer ${ISOLATION_HTTP_LOAD_BALANCER_NAME} created."

# Websockets (documentation says it reuses a bunch of stuff from the HTTP LB)
echo "Created Websockets load balancer..."
gcloud compute --project "${PROJECT}" addresses create "${ISOLATION_WS_LOAD_BALANCER_NAME}" --region "${REGION_1}" --no-user-output-enabled
gcloud compute --project "${PROJECT}" target-pools create "${ISOLATION_WS_LOAD_BALANCER_NAME}" --description "Target pool for load balancing web access to PCF instances" --region "${REGION_1}" --session-affinity "NONE"  --http-health-check "pcf-http-router-health-check-${SUBDOMAIN_TOKEN}" --no-user-output-enabled
gcloud compute --project "${PROJECT}" forwarding-rules create "${ISOLATION_WS_LOAD_BALANCER_NAME}" --description "Forwarding rule for load balancing web access to PCF instances." --region "${REGION_1}" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-websockets-isolation-${SUBDOMAIN_TOKEN}" --ip-protocol "TCP" --ports "443" --target-pool "${ISOLATION_WS_LOAD_BALANCER_NAME}" --no-user-output-enabled
echo "Websockets load balancer ${ISOLATION_WS_LOAD_BALANCER_NAME} created."

echo "You will need the following values to configure the PCF tile in Operations Managers if you do not use install.sh (it will set them for you)"
echo "  Load balancers for Router: tcp:${ISOLATION_WS_LOAD_BALANCER_NAME},http:${ISOLATION_HTTP_LOAD_BALANCER_NAME}"

gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled

# HTTP/S router
HTTP_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${ISOLATION_HTTP_LOAD_BALANCER_NAME}" --global  | jq --raw-output ".address"`
gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "*.isolation.gcp.crdant.io" --ttl "${DNS_TTL}" --type A "${HTTP_ADDRESS}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled

# websockets router
WS_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "${ISOLATION_WS_LOAD_BALANCER_NAME}" --region "${REGION_1}"  | jq --raw-output ".address"`
gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "doppler.isolation.gcp.crdant.io" --ttl "${DNS_TTL}" --type A "${WS_ADDRESS}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "loggregator.isolation.gcp.crdant.io" --ttl "${DNS_TTL}" --type A "${WS_ADDRESS}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled

gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
