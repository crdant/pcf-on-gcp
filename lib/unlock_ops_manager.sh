# log unlock the operations manager after restart

unlock_ops_manager () {
    login_ops_manager > /dev/null
    curl -q --insecure "${OPS_MANAGER_API_ENDPOINT}/unlock" -X PUT -H "Content-Type: application/json" -d '{"passphrase": "$DECRYPTION_PASSPHRASE"}'
}
