# get/set resoures for a job on a staged product in ops manager
#    outputs the guid

download_installation_assets () {
  ops_manager_fqdn=$1
  archive_file=$2
  login_ops_manager ${ops_manager_fqdn} > /dev/null
  curl -qLf --insecure "https://${ops_manager_fqdn}/api/v0/installation_asset_collection" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -o "${archive_file}"
}

upload_installation_assets () {
  ops_manager_fqdn=$1
  archive_file=$2

  login_ops_manager ${ops_manager_fqdn} > /dev/null
  curl -qvf --insecure "https://${ops_manager_fqdn}/api/v0/installation_asset_collection" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
    -F "installation[file]=@${archive_file}" -F "passphrase=$DECRYPTION_PASSPHRASE"
}
