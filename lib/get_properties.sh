# get product properties on operations manager

get_properties () {
  product=$1

  GUID=`product_guid $1`
  login_ops_manager > /dev/null
  curl -qsf --insecure "${OPS_MANAGER_API_ENDPOINT}/staged/products/${GUID}/properties" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json"
}
