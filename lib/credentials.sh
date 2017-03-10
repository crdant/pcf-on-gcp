get_director_credential () {
  credential=$1

  login_ops_manager > /dev/null
  curl -qsLf --insecure -X GET "${OPS_MANAGER_API_ENDPOINT}/deployed/director/credentials/${credential}" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" | jq --raw-output ".credential.value.password"
}

get_credential () {
  product=$1
  credential=$2

  # https://manager.gcp.crdant.io/api/v0/deployed/products/cf-1805afcd19b6447f8552/credentials/.uaa.admin_client_credentials
  login_ops_manager > /dev/null
  local installation_name=`deployed_products | jq --raw-output '. [] | select ( .type == "cf") .installation_name'`
  curl -qsLf --insecure -X GET "${OPS_MANAGER_API_ENDPOINT}/deployed/products/${installation_name}/credentials/${credential}" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" \
    -H "Content-Type: application/json" | jq --raw-output ".credential.value.password"
}
