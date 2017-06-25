set_director_config () {
  login_ops_manager
  CONFIG_JSON=`export PROJECT SERVICE_ACCOUNT; envsubst < api-calls/director/config.json ; unset PROJECT SERVICE_ACCOUNT`
  curl -qsLf --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/director/properties" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Content-Type: application/json" -d "${CONFIG_JSON}"
}

get_director_config () {
  login_ops_manager
  curl -qsLf --insecure "${OPS_MANAGER_API_ENDPOINT}/staged/director/properties" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accepts: application/json"
}

set_availability_zones () {
  login_ops_manager
  AZS_JSON=`export AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3; envsubst < api-calls/director/availability-zones.json; unset AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3`
  curl -qsLf --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/director/availability_zones" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Content-Type: application/json" -d "${AZS_JSON}"
}

create_director_networks () {
  login_ops_manager
  NETWORKS_JSON=`export SUBDOMAIN_TOKEN REGION_1 INFRASTRUCTURE_NETWORK_NAME DEPLOYMENT_NETWORK_NAME TILES_NETWORK_NAME SERVICES_NETWORK_NAME DNS_SERVERS INFRASTRUCTURE_CIDR INFRASTRUCTURE_RESERVED INFRASTRUCTURE_GATEWAY DEPLOYMENT_CIDR DEPLOYMENT_RESERVED DEPLOYMENT_GATEWAY TILES_CIDR TILES_RESERVED TILES_GATEWAY SERVICES_CIDR SERVICES_RESERVED SERVICES_GATEWAY AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3; envsubst < api-calls/director/create-networks.json; unset SUBDOMAIN_TOKENT REGION_1 INFRASTRUCTURE_NETWORK_NAME DEPLOYMENT_NETWORK_NAME TILES_NETWORK_NAME SERVICES_NETWORK_NAME  DNS_SERVERS INFRASTRUCTURE_CIDR INFRASTRUCTURE_RESERVED INFRASTRUCTURE_GATEWAY DEPLOYMENT_CIDR DEPLOYMENT_RESERVED DEPLOYMENT_GATEWAY TILES_CIDR TILES_RESERVED TILES_GATEWAY SERVICES_CIDR SERVICES_RESERVED SERVICES_GATEWAY AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3`
  curl --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/director/networks" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Content-Type: application/json" -d "${NETWORKS_JSON}"
}

assign_director_networks () {
  login_ops_manager
  NETWORKS_JSON=`export INFRASTRUCTURE_NETWORK_NAME AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3 ; envsubst < api-calls/director/assign-networks.json; unset INFRASTRUCTURE_NETWORK_NAME AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3`
  curl --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/director/network_and_az" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Content-Type: application/json" -d "${NETWORKS_JSON}"
}
