# upload a product to ops manager

upload_product () {
  product_file=$1

  login_ops_manager > /dev/null
  curl -q --insecure -X POST "${OPS_MANAGER_API_ENDPOINT}/available_products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
    -H "Accept: application/json" -F "product[file]=@${product_file}"

}
