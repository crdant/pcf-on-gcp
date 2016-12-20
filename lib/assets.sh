# get/set resoures for a job on a staged product in ops manager
#    outputs the guid

download_installation_assets () {
  ops_manager_fqdn=$1
  archive_file=$2
  login_ops_manager ${ops_manager_fqdn} > /dev/null
  curl -qLf --insecure "${ops_manager_fqdn}/api/v0/installation_asset_collection" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -o "${archive_file}"
}

upload_installation_assets () {
  ops_manager_fqdn=$1
  archive_file=$2
  login_ops_manager ${ops_manager_fqdn} > /dev/null
  curl -qfL --insecure -X PUT "${ops_manager_fqdn}/api/v0/installation_asset_collection" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" -d "@{archive_file}"
}
