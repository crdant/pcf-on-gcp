#!/usr/bin/env bash
# upgrade an existing Ops Manager and PCF to the version(s) specified in $OPS_MANAGER_VERSION and $PCF_VERSION

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/personal.sh"
. "${BASEDIR}/lib/setup.sh"
. "${BASEDIR}/lib/login_ops_manager.sh"
. "${BASEDIR}/lib/credentials.sh"
. "${BASEDIR}/lib/assets.sh"
. "${BASEDIR}/lib/products.sh"
. "${BASEDIR}/lib/resources.sh"
. "${BASEDIR}/lib/properties.sh"
. "${BASEDIR}/lib/random_phrase.sh"
. "${BASEDIR}/lib/generate_passphrase.sh"
. "${BASEDIR}/lib/eula.sh"
. "${BASEDIR}/lib/guid.sh"
. "${BASEDIR}/lib/networks_azs.sh"

update_env () {
  login_ops_manager
  CURRENT_PCF_VERSION=`available_products | jq --raw-output '. [] | select ( .name == "cf") .product_version'`
  CURRENT_OPS_MANAGER_VERSION=`curl -qs --insecure -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" ${OPS_MANAGER_API_ENDPOINT}/diagnostic_report | jq --raw-output ".versions .release_version" | cut -d. -f1-3`
  CURRENT_OPS_MANAGER_VERSION_TOKEN=`echo ${CURRENT_OPS_MANAGER_VERSION} | tr . -`
  INSTALLATION_ASSETS_ARCHIVE="${WORKDIR}/${PROJECT}-assets-${CURRENT_PCF_VERSION}.zip"
  OLD_OPS_MANAGER_FQDN="old-${OPS_MANAGER_FQDN}"
}

download_assets () {
  echo "Downloading installation assets to ${INSTALLATION_ASSETS_ARCHIVE}..."
  download_installation_assets "${OPS_MANAGER_FQDN}" "${INSTALLATION_ASSETS_ARCHIVE}"
  echo "Installation assets downloaded"
}

prepare_dns () {
  echo "Configuring DNS for Operations Manager..."
  gcloud compute --project "${PROJECT}" addresses create "pcf-ops-manager-${DOMAIN_TOKEN}-new" --region "${REGION_1}" --no-user-output-enabled
  CURRENT_OPS_MANAGER_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "pcf-ops-manager-${DOMAIN_TOKEN}" --region "${REGION_1}"  | jq --raw-output ".address"`
  NEW_OPS_MANAGER_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "pcf-ops-manager-${DOMAIN_TOKEN}-new" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "${OLD_OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A ${CURRENT_OPS_MANAGER_ADDRESS} --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction remove -z "${DNS_ZONE}" --name "${OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A ${CURRENT_OPS_MANAGER_ADDRESS} --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "${OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A ${NEW_OPS_MANAGER_ADDRESS} --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  echo "Updated Operations Manager DNS for ${OPS_MANAGER_FQDN} to ${NEW_OPS_MANAGER_ADDRESS}."

}

new_ops_manager () {
  echo "Installing the new version of Operations Manager alongside the existing one..."
  OPS_MANAGER_RELEASES_URL="https://network.pivotal.io/api/v2/products/ops-manager/releases"
  OPS_MANAGER_YML="${WORKDIR}/ops-manager-on-gcp.yml"

  # download the Ops Manager YAML file to find the image we're using
  accept_eula "ops-manager" "${OPS_MANAGER_VERSION}" "yes"
  echo "Finding the image location for the Pivotal release image for operations manager..."
  FILES_URL=`curl -qsLf -H "Authorization: Token $PIVNET_TOKEN" $OPS_MANAGER_RELEASES_URL | jq --raw-output ".releases[] | select( .version == \"$OPS_MANAGER_VERSION\" ) ._links .product_files .href"`
  DOWNLOAD_POST_URL=`curl -qsLf -H "Authorization: Token $PIVNET_TOKEN" $FILES_URL | jq --raw-output '.product_files[] | select( .aws_object_key | test (".*GCP.*yml") ) ._links .download .href'`
  DOWNLOAD_URL=`curl -qsLf -X POST -d "" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token $PIVNET_TOKEN" $DOWNLOAD_POST_URL -w "%{url_effective}\n"`
  IMAGE_URI=`curl -qsLf "${DOWNLOAD_URL}" | grep ".us" | sed 's/us: //'`
  IMAGE_SOURCE_URI="https://storage.googleapis.com/${IMAGE_URI}"
  echo "Located image at ${IMAGE_URI}"

  # Ops Manager instance
  echo "Creating disk image for Operations Manager from the Pivotal provided image..."
  gcloud compute --project "${PROJECT}" images create "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}" --family "pcf-ops-manager" --description "Primary disk for Pivotal Cloud Foundry Operations Manager (v. ${OPS_MANAGER_VERSION})" --source-uri "${IMAGE_SOURCE_URI}" --no-user-output-enabled
  echo "Operations Manager image created."

  prepare_dns

  echo "Shutting down existing operations manager instance..."
  gcloud compute --project ${PROJECT} instances stop "pcf-ops-manager-${CURRENT_OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}"  --quiet

  echo "Creating Operations Manager instance..."
  gcloud compute --project "${PROJECT}" instances create "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --machine-type "n1-standard-1" --subnet "pcf-${REGION_1}-${DOMAIN_TOKEN}" --private-network-ip "10.0.0.5" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-ops-manager-${DOMAIN_TOKEN}-new" --maintenance-policy "MIGRATE" --scopes "https://www.googleapis.com/auth/cloud-platform" --service-account "${SERVICE_ACCOUNT}" --tags "http-server","https-server","pcf-opsmanager" --image-family "pcf-ops-manager" --boot-disk-size "200" --boot-disk-type "pd-standard" --boot-disk-device-name "pcf-operations-manager" --no-user-output-enabled
  gcloud compute instances add-metadata "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone "${AVAILABILITY_ZONE_1}" --metadata-from-file "ssh-keys=${KEYDIR}/ubuntu-key.pub" --no-user-output-enabled
  echo "Completed installing the new version of Operations Manager alongside the existing one at ${OPS_MANAGER_FQDN}..."

  # noticed I was getting 502 and 503 errors on the setup calls below, so sleeping to see if that helps
  echo "Waiting for ${DNS_TTL} seconds for Operations Manager instance to be available and DNS to be updated..."
  sleep ${DNS_TTL}

}

migrate_ops_manager () {
  # now let's get ops manager going
  echo "Uploading installation assets from ${INSTALLATION_ASSETS_ARCHIVE}..."
  upload_installation_assets ${OPS_MANAGER_FQDN} ${INSTALLATION_ASSETS_ARCHIVE}
}

stemcell () {
  echo "Downloading latest product stemcell ${STEMCELL_VERSION}..."
  accept_eula "stemcells" "${STEMCELL_VERSION}" "yes"
  stemcell_file=`download_stemcell ${STEMCELL_VERSION}`
  echo "Uploading stemcell to Operations Manager..."
  upload_stemcell $stemcell_file
}

cloud_foundry () {
  if product_not_available "cf" "${PCF_VERSION}" ; then
    accept_eula "elastic-runtime" "${PCF_VERSION}" "yes"
    echo "Downloading Cloud Foundry Elastic Runtime..."
    tile_file=`download_tile "elastic-runtime" "${PCF_VERSION}"`
    echo "Uploading Cloud Foundry Elastic Runtime..."
    upload_tile $tile_file
  else
    echo "Cloud Foundry version ${PCF_VERSION} is already available in Operations Manager at ${OPS_MANAGER_FQDN}"
  fi
  echo "Staging Cloud Foundry Elastic Runtime..."
  stage_product "cf" "${PCF_VERSION}"

  # configure BLOB storage locations, system domain, etc. doesn't set everything yet (SSL certificate info doesn't
  # come back with a GET so it's hard to figure out how to set it)
  PRIVATE_KEY=`cat ${KEYDIR}/pcf-router-${DOMAIN_TOKEN}.key`
  SSL_CERT=`cat ${KEYDIR}/pcf-router-${DOMAIN_TOKEN}.crt`

  # looks funny, but it keeps us from polluting the environment
  CF_NETWORK_SETTINGS=`export DIRECTOR_NETWORK_NAME AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3; envsubst < api-calls/tile-networks-and-azs.json ; unset  DIRECTOR_NETWORK_NAME AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3`
  set_networks_azs "cf" "${CF_NETWORK_SETTINGS}"

  # looks funny, but it keeps us from polluting the environment
  PROPERTIES_JSON=`export ACCOUNT PRIVATE_KEY SSL_CERT BUILDPACKS_STORAGE_BUCKET DROPLETS_STORAGE_BUCKET RESOURCES_STORAGE_BUCKET PACKAGES_STORAGE_BUCKET GCP_ACCESS_KEY_ID GCP_SECRET_ACCESS_KEY PCF_APPS_DOMAIN PCF_SYSTEM_DOMAIN; envsubst < api-calls/elastic-runtime-properties.json ; unset ACCOUNT PRIVATE_KEY SSL_CERT BUILDPACKS_STORAGE_BUCKET DROPLETS_STORAGE_BUCKET RESOURCES_STORAGE_BUCKET PACKAGES_STORAGE_BUCKET GCP_ACCESS_KEY_ID GCP_SECRET_ACCESS_KEY PCF_APPS_DOMAIN PCF_SYSTEM_DOMAINt`
  set_properties "cf" "${PROPERTIES_JSON}"

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

  # update the number of
}

cleanup_dns () {
  echo "Removing DNS entries for ${OLD_OPS_MANAGER_FQDN}..."
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction remove -z "${DNS_ZONE}" --name "${OLD_OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A "${CURRENT_OPS_MANAGER_ADDRESS}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  echo "Removed DNS entries for ${OLD_OPS_MANAGER_FQDN}..."
}

cleanup () {
  cleanup_dns

  echo "Deleting old Ops Manager instance..."
  gcloud compute --project "${PROJECT}" instances delete "pcf-ops-manager-${CURRENT_OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --quiet
  echo "Deleted old Ops Manager instance."

  echo "Removing IP Address assigned to old Ops Manager instance..."
  gcloud compute --project "${PROJECT}" --format json addresses describe "pcf-ops-manager-${DOMAIN_TOKEN}" --region "${REGION_1}"  | jq --raw-output ".address"
  echo "Removed IP address assigned to old Ops Manager instance."

}

START_TIMESTAMP=`date`
START_SECONDS=`date +%s`
prepare_env
update_env
overrides
setup
echo "Started updating Cloud Foundry in ${PROJECT} from ${CURRENT_PCF_VERSION} to ${PCF_VERSION} at ${START_TIMESTAMP}..."
download_assets
new_ops_manager
migrate_ops_manager
login_ops_manager
stemcell
cloud_foundry
# cleanup
END_TIMESTAMP=`date`
END_SECONDS=`date +%s`
ELAPSED_TIME=`echo $((END_SECONDS-START_SECONDS)) | awk '{print int($1/60)":"int($1%60)}'`
echo "Completed updating Cloud Foundry in ${PROJECT} from ${CURRENT_PCF_VERSION} to ${PCF_VERSION} at ${END_TIMESTAMP} (elapsed time ${ELAPSED_TIME})."
