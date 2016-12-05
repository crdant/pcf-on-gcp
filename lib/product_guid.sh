# get the  guid for a staged product in ops manager
#    outputs the guid

product_guid () {
  product=$1
  login_ops_manager > /dev/null
  curl -qs --insecure "${OPS_MANAGER_API_ENDPOINT}/staged/products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" | jq --raw-output ".[] | select( .type == \"$product\" ) .guid"
}
