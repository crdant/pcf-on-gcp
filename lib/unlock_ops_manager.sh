# log unlock the operations manager after restart

unlock_ops_manager () {
    login_ops_manager > /dev/null
    curl -q --insecure "https://manager.${SUBDOMAIN}/api/v0/unlock" -X PUT -H "Content-Type: application/json" -d '{"passphrase": "$DECRYPTION_PASSPHRASE"}'
}
