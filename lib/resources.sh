# get/set resoures for a job on a staged product in ops manager
#    outputs the guid

get_resources () {
  product=$1
  job=$2

  login_ops_manager > /dev/null
  product_guid=`product_guid $product`
  job_guid=`job_guid $product $job`
  curl -qsLf --insecure "${OPS_MANAGER_API_ENDPOINT}/staged/products/${product_guid}/jobs/${job_guid}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"
}

set_resources () {
  product=$1
  job=$2
  resources=`echo "${3}"`

  login_ops_manager > /dev/null
  product_guid=`product_guid $product`
  job_guid=`job_guid $product $job`
  curl -qsLf --insecure -X PUT "${OPS_MANAGER_API_ENDPOINT}/staged/products/${product_guid}/jobs/${job_guid}/resource_config" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" -d "${resources}"
}
