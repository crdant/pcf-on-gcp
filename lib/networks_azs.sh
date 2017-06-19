# set network and availability zone configuration

get_networks_azs () {
  product=$1

  GUID=`product_guid $1`
  login_ops_manager > /dev/null
  curl -qsLf --insecure -X GET "${OPS_MANAGER_API_ENDPOINT}/staged/products/${GUID}/networks_and_azs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json"
}

set_networks_azs () {
  product=$1

  guid=`product_guid $1`
  login_ops_manager > /dev/null

  pick_singleton_availability_zone
  networks_json=`export TILES_NETWORK_NAME SERVICE_NETWORK_NAME SINGLETON_AVAILABILITY_ZONE AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3; envsubst < api-calls/products/networks-and-azs.json ; unset TILES_NETWORK_NAME SERVICE_NETWORK_NAME SINGLETON_AVAILABILITY_ZONE AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3`
  curl -q --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/products/${guid}/networks_and_azs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" -H "Content-Type: application/json" -d "${networks_json}"
}

pick_singleton_availability_zone () {
  ROLL=$(($(($RANDOM%10))%3))
  if [ $ROLL -eq 1 ] ; then
    SINGLETON_AVAILABILITY_ZONE="${AVAILABILITY_ZONE_1}"
  elif [ $ROLL -eq 2 ] ; then
    SINGLETON_AVAILABILITY_ZONE="${AVAILABILITY_ZONE_2}"
  else
    SINGLETON_AVAILABILITY_ZONE="${AVAILABILITY_ZONE_3}"
  fi
}
