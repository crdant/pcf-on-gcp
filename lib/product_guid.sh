# get the  guid for a staged product in ops manager
#    outputs the guid

product_guid () {
  product=$1
  login_ops_manager > /dev/null
  curl -qs --insecure "https://manager.${SUBDOMAIN}/api/v0/staged/products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" | jq --raw-output ".[] | select( .type == \"$product\" ) .guid"
}
