# upload a product to ops manager or the BOSH director

upload_tile () {
  product_file=$1

  login_ops_manager > /dev/null
  curl -q --insecure -X POST "${OPS_MANAGER_API_ENDPOINT}/available_products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
    -H "Accept: application/json" -F "product[file]=@${product_file}"

}

upload_addon () {
  product_file=$1

  echo "Upload not yet implememented. You need to run the following: "
  echo "   scp -i ${KEYDIR}/vcap-key $product_file vcap@BOSH_DIRECTOR_HOST:$product_file"
}
