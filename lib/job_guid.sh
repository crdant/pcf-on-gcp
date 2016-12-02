# get the  guid for a staged product in ops manager
#    outputs the guid

job_guid () {
  product=$1
  job=$2
  login_ops_manager > /dev/null
  product_guid=`product_guid $product`
  curl -qs --insecure "https://manager.${SUBDOMAIN}/api/v0/staged/products/$product_guid/jobs" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" | jq --raw-output ".[] | select( .name == \"$job\" ) .guid"
}
