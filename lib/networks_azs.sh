# set network and availability zone configuration

get_networks_azs () {
  product=$1

  GUID=`product_guid $1`
  login_ops_manager > /dev/null
  curl -qsf --insecure -X GET "${OPS_MANAGER_API_ENDPOINT}/staged/products/${GUID}/networks_and_azs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json"
}

set_networks_azs () {
  product=$1
  settings=`echo "${2}" | jq -c '.'`

  GUID=`product_guid $1`
  login_ops_manager > /dev/null
  curl -q --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/products/${GUID}/networks_and_azs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" -d "${settings}"
}
