set_pcf_domains () {
  login_ops_manager > /dev/null
  domains_json=`export PCF_SYSTEM_DOMAIN PCF_APPS_DOMAIN; envsubst < api-calls/elastic-runtime/domains.json ; unset PCF_SYSTEM_DOMAIN PCF_APPS_DOMAIN`
  set_properties "${PCF_OPSMAN_SLUG}" "${domains_json}"
}

set_pcf_networking () {
  login_ops_manager
  ROUTER_PRIVATE_KEY=`cat ${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.key | perl -pe 's#\n#\x5c\x5c\x6e#g'`
  ROUTER_CERTIFICATE=`cat ${KEYDIR}/pcf-router-${SUBDOMAIN_TOKEN}.crt | perl -pe 's#\n#\x5c\x5c\x6e#g'`

  networking_json=`export ROUTER_PRIVATE_KEY ROUTER_CERTIFICATE TCP_ROUTER_PORTS; envsubst < api-calls/elastic-runtime/networking.json ; unset ROUTER_PRIVATE_KEY ROUTER_CERTIFICATE TCP_ROUTER_PORTS`
  set_properties "${PCF_OPSMAN_SLUG}" "${networking_json}"
}

set_pcf_containers () {
  login_ops_manager > /dev/null
  containers_json=`export ALLOW_SSH ALLOW_BUILDPACKS; envsubst < api-calls/elastic-runtime/containers.json ; unset ALLOW_SSH ALLOW_BUILDPACKS`
  set_properties "${PCF_OPSMAN_SLUG}" "${containers_json}"
}

set_pcf_security_acknowledgement () {
  login_ops_manager > /dev/null
  acknowledgement_json=`cat api-calls/elastic-runtime/security-acknowledgement.json`
  set_properties "${PCF_OPSMAN_SLUG}" "${acknowledgement_json}"
}

set_pcf_rds_database () {
  login_ops_manager > /dev/null
  databse_json=`export EMAIL PCF_RDS_HOST PCF_RDS_PORT PCF_RDS_USER BOSH_RDS_PASSWORD; envsubst <  api-calls/elastic-runtime/database.json ; unset EMAIL PCF_RDS_HOST PCF_RDS_PORT PCF_RDS_USER BOSH_RDS_PASSWORD`
  set_properties "${PCF_OPSMAN_SLUG}" "${databse_json}"
}

set_pcf_advanced_features () {
  login_ops_manager > /dev/null
  advanced_json=`export CNI_CIDR; envsubst <  api-calls/elastic-runtime/advanced-features.json ; unset CNI_CIDR`
  set_properties "${PCF_OPSMAN_SLUG}" "${advanced_json}"
}
