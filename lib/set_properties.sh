# set product properties on operations manager

set_properties () {
  product=$1
  properties=$2

  GUID=`product_guid $1`
  login_ops_manager > /dev/null
  curl -q --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/products/${GUID}/properties" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" -d "${properties}"
}
