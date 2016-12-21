#!/usr/bin/env bash
# upgrade an existing Ops Manager and PCF to the version(s) specified in $OPS_MANAGER_VERSION and $PCF_VERSION

BASEDIR=`dirname $0`
. "${BASEDIR}/lib/env.sh"
. "${BASEDIR}/lib/customization_hooks.sh"
. "${BASEDIR}/personal.sh"
. "${BASEDIR}/lib/setup.sh"
. "${BASEDIR}/lib/login_ops_manager.sh"
. "${BASEDIR}/lib/assets.sh"
. "${BASEDIR}/lib/products.sh"
. "${BASEDIR}/lib/random_phrase.sh"
. "${BASEDIR}/lib/generate_passphrase.sh"
. "${BASEDIR}/lib/eula.sh"
. "${BASEDIR}/lib/guid.sh"
. "${BASEDIR}/lib/networks_azs.sh"

update_env () {
  CURRENT_PCF_VERSION=`available_products | jq --raw-output '. [] | select ( .name == "cf") .product_version'`
  CURRENT_OPS_MANAGER_VERSION=`curl -qs --insecure -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" ${OPS_MANAGER_API_ENDPOINT}/diagnostic_report | jq --raw-output ".versions .release_version" | cut -d. -f1-3`
  CURRENT_OPS_MANAGER_VERSION_TOKEN=`echo ${CURRENT_OPS_MANAGER_VERSION} | tr . -`
  INSTALLATION_ASSETS_ARCHIVE="${WORKDIR}/${PROJECT}-assets-${CURRENT_PCF_VERSION}.zip"
  CURRENT_OPS_MANAGER_FQDN="old-${OPS_MANAGER_FQDN}"
}

download_assets () {
  echo "Downloading installation assets to ${INSTALLATION_ASSETS_ARCHIVE}..."
  download_installation_assets "${OPS_MANAGER_FQDN}" "${INSTALLATION_ASSETS_ARCHIVE}"
  echo "Installation assets downloaded"
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

  # make sure we can get to it
  echo "Configuring DNS for Operations Manager..."
  gcloud compute --project "${PROJECT}" addresses create "pcf-ops-manager-${DOMAIN_TOKEN}-new" --region "${REGION_1}" --no-user-output-enabled
  CURRENT_OPS_MANAGER_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "pcf-ops-manager-${DOMAIN_TOKEN}" --region "${REGION_1}"  | jq --raw-output ".address"`
  NEW_OPS_MANAGER_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "pcf-ops-manager-${DOMAIN_TOKEN}-new" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "${CURRENT_OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A ${CURRENT_OPS_MANAGER_ADDRESS} --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction remove -z "${DNS_ZONE}" --name "${OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A ${CURRENT_OPS_MANAGER_ADDRESS} --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "${OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A ${NEW_OPS_MANAGER_ADDRESS} --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  echo "Updated Operations Manager DNS for ${OPS_MANAGER_FQDN} to ${OPS_MANAGER_ADDRESS}."

  echo "Creating Operations Manager instance..."
  gcloud compute --project "${PROJECT}" instances create "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --machine-type "n1-standard-1" --subnet "pcf-${REGION_1}-${DOMAIN_TOKEN}" --private-network-ip "10.0.0.5" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-ops-manager-${DOMAIN_TOKEN}-new" --maintenance-policy "MIGRATE" --scopes ${SERVICE_ACCOUNT}="https://www.googleapis.com/auth/cloud-platform" --tags "http-server","https-server","pcf-opsmanager" --image-family "pcf-ops-manager" --boot-disk-size "200" --boot-disk-type "pd-standard" --boot-disk-device-name "pcf-operations-manager" --no-user-output-enabled
  gcloud compute instances add-metadata "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone "${AVAILABILITY_ZONE_1}" --metadata-from-file "ssh-keys=${KEYDIR}/ubuntu-key.pub" --no-user-output-enabled
  echo "Completed installing the new version of Operations Manager alongside the existing one at ${OPS_MANAGER_FQDN}..."

  # noticed I was getting 502 and 503 errors on the setup calls below, so sleeping to see if that helps
  echo "Waiting for ${DNS_TTL} seconds for Operations Manager instance to be available and DNS to be updated..."
  sleep ${DNS_TTL}
}

migrate_ops_manager () {
  # now let's get ops manager going
  echo "Setting up Operations Manager authentication and adminsitrative user..."

  # this line looks a little funny, but it's to make sure we keep the passwords out of the environment
  echo "Configuring authentication in Operations Manager..."
  SETUP_JSON=`export ADMIN_PASSWORD DECRYPTION_PASSPHRASE ; envsubst < api-calls/setup.json ; unset ADMIN_PASSWORD ; unset DECRYPTION_PASSPHRASE`
  curl -qsLf --insecure "${OPS_MANAGER_API_ENDPOINT}/setup" -X POST -H "Content-Type: application/json" -d "${SETUP_JSON}"
  echo "Operations Manager authentication configured. Your username is admin and password is ${ADMIN_PASSWORD}."

  # log in to the ops_manager so the script can manipulate it
  login_ops_manager ${OPS_MANAGER_FQDN}

  echo "Uploading installation assets from ${INSTALLATION_ASSETS_ARCHIVE}..."
  upload_installation_assets ${OPS_MANAGER_FQDN} ${INSTALLATION_ASSETS_ARCHIVE}
}

cleanup () {
  echo "Removing DNS entries for ${CURRENT_OPS_MANAGER_FQDN}..."
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction remove -z "${DNS_ZONE}" --name "${CURRENT_OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A ${CURRENT_OPS_MANAGER_ADDRESS} --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${WORKDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  echo "Removed DNS entries for ${CURRENT_OPS_MANAGER_FQDN}..."

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
# download_assets
new_ops_manager
# migrate_ops_manager
# cloud_foundry
# cleanup
END_TIMESTAMP=`date`
END_SECONDS=`date +%s`
ELAPSED_TIME=`echo $((END_SECONDS-START_SECONDS)) | awk '{print int($1/60)":"int($1%60)}'`
echo "Completed updating Cloud Foundry in ${PROJECT} from ${CURRENT_PCF_VERSION} to ${PCF_VERSION} at ${END_TIMESTAMP} (elapsed time ${ELAPSED_TIME})."
