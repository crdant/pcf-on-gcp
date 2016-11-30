
stage_product () {
  product=$1

  login_ops_manager > /dev/null

  available_product=`curl -qsf --insecure "https://manager.${SUBDOMAIN}/api/v0/available_products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" | jq --raw-output ".[] | select ( .name == \"$product\" )"`
  product_name=`echo $available_product | jq --raw-output ".name"`
  available_version=`echo $available_product | jq --raw-output ".product_version"`
  curl -qsf --insecure -X POST "https://manager.${SUBDOMAIN}/api/v0/staged/products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
    -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"name\": \"$product_name\", \"product_version\": \"${available_version}\"}"
}
