
setup_ops_manager_auth () {
  # this line looks a little funny, but it's to make sure we keep the passwords out of the environment
  SETUP_JSON=`export ADMIN_PASSWORD DECRYPTION_PASSPHRASE ; envsubst < api-calls/ops-manager/setup.json ; unset ADMIN_PASSWORD ; unset DECRYPTION_PASSPHRASE`
  curl -qsLf --insecure -X POST "${OPS_MANAGER_API_ENDPOINT}/setup" -H "Content-Type: application/json" -d "${SETUP_JSON}"
}

apply_changes () {
  ERRANDS=$1
  CHANGES_JSON=`export ERRANDS ; envsubst < api-calls/ops-manager/apply-changes.json ; unset ERRANDS`
  curl -qsLf --insecure -X POST "${OPS_MANAGER_API_ENDPOINT}/installations" -H "Content-Type: application/json" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -d "${CHANGES_JSON}"
}

install_logs () {
  INSTALL_ID=$1
  curl -qsLf --insecure "${OPS_MANAGER_API_ENDPOINT}/installations/${INSTALL_ID}/logs" -H "Content-Type: application/json" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}"
}

unlock_ops_manager () {
  curl -qsLf --insecure "${OPS_MANAGER_API_ENDPOINT}/unlock" -X PUT -H "Content-Type: application/json" -d "{\"passphrase\": \"$DECRYPTION_PASSPHRASE\"}"
}
