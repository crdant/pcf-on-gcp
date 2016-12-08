# get/set product properties on operations manager

get_jobs () {
  product=$1

  GUID=`product_guid $1`
  login_ops_manager > /dev/null
  curl -qsf --insecure "${OPS_MANAGER_API_ENDPOINT}/staged/products/${GUID}/jobs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json"
}
