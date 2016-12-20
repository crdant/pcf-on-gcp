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

download_assets () {
  echo "Downloading installation assets to ${INSTALLATION_ASSETS_ARCHIVE}..."
  download_installation_assets "${OPS_MANAGER_FQDN}" "${INSTALLATION_ASSETS_ARCHIVE}"
  echo "Installation assets downloaded"
}

new_ops_manager () {
  echo "Installing Operations Manager..."
  OPS_MANAGER_RELEASES_URL="https://network.pivotal.io/api/v2/products/ops-manager/releases"
  OPS_MANAGER_YML="${TMPDIR}/ops-manager-on-gcp.yml"

  # download the Ops Manager YAML file to find the image we're using
  accept_eula "ops-manager" "${OPS_MANAGER_VERSION}" "yes"
  echo "Finding the image location for the Pivotal release image for operations manager."
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
  OPS_MANAGER_ADDRESS=`gcloud compute --project "${PROJECT}" --format json addresses describe "pcf-ops-manager-${DOMAIN_TOKEN}" --region "${REGION_1}"  | jq --raw-output ".address"`
  gcloud dns record-sets transaction start -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction add -z "${DNS_ZONE}" --name "${NEW_OPS_MANAGER_FQDN}" --ttl "${DNS_TTL}" --type A ${OPS_MANAGER_ADDRESS} --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  gcloud dns record-sets transaction execute -z "${DNS_ZONE}" --transaction-file="${TMPDIR}/dns-transaction-${DNS_ZONE}.xml" --no-user-output-enabled
  echo "Updated Operations Manager DNS for ${NEW_OPS_MANAGER_FQDN} to ${OPS_MANAGER_ADDRESS}."

  echo "Creating Operations Manager instance..."
  gcloud compute --project "${PROJECT}" instances create "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone ${AVAILABILITY_ZONE_1} --machine-type "n1-standard-1" --subnet "pcf-${REGION_1}-${DOMAIN_TOKEN}" --private-network-ip "10.0.0.4" --address "https://www.googleapis.com/compute/v1/projects/${PROJECT}/regions/${REGION_1}/addresses/pcf-ops-manager-${DOMAIN_TOKEN}" --maintenance-policy "MIGRATE" --scopes ${SERVICE_ACCOUNT}="https://www.googleapis.com/auth/cloud-platform" --tags "http-server","https-server","pcf-opsmanager" --image-family "pcf-ops-manager" --boot-disk-size "200" --boot-disk-type "pd-standard" --boot-disk-device-name "pcf-operations-manager" --no-user-output-enabled
  ssh-keygen -P "" -t rsa -f ${KEYDIR}/ubuntu-key -b 4096 -C ubuntu@local > /dev/null
  sed -i.gcp '1s/^/ubuntu: /' ${KEYDIR}/ubuntu-key.pub
  gcloud compute instances add-metadata "pcf-ops-manager-${OPS_MANAGER_VERSION_TOKEN}-${DOMAIN_TOKEN}" --zone "${AVAILABILITY_ZONE_1}" --metadata-from-file "ssh-keys=${KEYDIR}/ubuntu-key.pub" --no-user-output-enabled
  mv ${KEYDIR}/ubuntu-key.pub.gcp ${KEYDIR}/ubuntu-key.pub
  echo "Operations Manager instance created..."

  # noticed I was getting 502 and 503 errors on the setup calls below, so sleeping to see if that helps
  echo "Waiting for ${DNS_TTL} seconds for Operations Manager instance to be available and DNS to be updated..."
  sleep ${DNS_TTL}
}

migrate_ops_manager () {
  # now let's get ops manager going
  echo "Setting up Operations Manager authentication and adminsitrative user..."

  login_new_ops_manager
  # this line looks a little funny, but it's to make sure we keep the passwords out of the environment
  SETUP_JSON=`export ADMIN_PASSWORD DECRYPTION_PASSPHRASE ; envsubst < api-calls/setup.json ; unset ADMIN_PASSWORD ; unset DECRYPTION_PASSPHRASE`
  curl -qsLf --insecure "${NEW_OPS_MANAGER_API_ENDPOINT}/setup" -X POST -H "Content-Type: application/json" -d "${SETUP_JSON}"
  echo "Operation manager configured. Your username is admin and password is ${ADMIN_PASSWORD}."

  # log in to the ops_manager so the script can manipulate it later
  login_ops_manager ${NEW_OPS_MANAGER_FQDN}

  upload_installation_assets ${NEW_OPS_MANAGER_FQDN} ${INSTALLATION_ASSETS_ARCHIVE}
  # prepare for downloading products from the Pivotal Network
  echo "Providing Pivotal Network settings to Operations Manager..."
  curl -qsLf --insecure -X PUT "${NEW_OPS_MANAGER_API_ENDPOINT}/settings/pivotal_network_settings" \
      -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
      -H "Content-Type: application/json" -d "{ \"pivotal_network_settings\": { \"api_token\": \"$PIVNET_TOKEN\" } }"
  echo "Operations Manager installed and prepared for tile configruation. If you are using install.sh, be sure to create BOSH network ${DIRECTOR_NETWORK_NAME}"

  echo "Configuring the BOSH Director (some settings are not done via the API)..."
  DIRECTOR_SETTINGS=`export DIRECTOR_NETWORK_NAME PROJECT SERVICE_ACCOUNT; envsubst < api-calls/director.yml ; unset  DIRECTOR_NETWORK_NAME PROJECT SERVICE_ACCOUNT`
  curl -qsLf --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/director/properties" \
      -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" -d "${DIRECTOR_SETTINGS}"
  echo "BOSH Director created"
}

START_TIMESTAMP=`date`
START_SECONDS=`date +%s`

CURRENT_PCF_VERSION=`available_products | jq --raw-output '. [] | select ( .name == "cf") .product_version'`
INSTALLATION_ASSETS_ARCHIVE="${TMPDIR}/${project}-assets-${CURRENT_PCF_VERSION}.zip"
NEW_OPS_MANAGER_FQDN="new-${OPS_MANAGER_FQDN}"
NEW_OPS_MANAGER_API_ENDPOINT="new-${OPS_MANAGER_API_ENDPOINT}"

echo "Started updating Cloud Foundry in ${PROJECT} from ${CURRENT_PCF_VERSION} to ${PCF_VERSION} at ${START_TIMESTAMP}..."
prepare_env
overrides
setup
download_assets
# new_ops_manager
# migrate_ops_manager
# cloud_foundry
END_TIMESTAMP=`date`
END_SECONDS=`date +%s`
ELAPSED_TIME=`echo $((END_SECONDS-START_SECONDS)) | awk '{print int($1/60)":"int($1%60)}'`
echo "Completed updating Cloud Foundry in ${PROJECT} from ${CURRENT_PCF_VERSION} to ${PCF_VERSION} at ${END_TIMESTAMP} (elapsed time ${ELAPSED_TIME})."
