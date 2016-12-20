# log into the operations manager API using UAA
#    reference $UAA_ACCESS_TOKEN as the bearer token for API calls

invalid_login () {
  status_code=`curl -qsLf -I --insecure "${OPS_MANAGER_FQDN}/uaa/tokens_expiration"  -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"  -w "%{http_code}\n" -o /dev/null`
  if [ "$status_code" != "200" ] ; then
    return 0
  else
    return 1
  fi
}

do_login () {
  uaac target "${OPS_MANAGER_FQDN}/uaa" --skip-ssl-validation
  uaac token owner get opsman admin --secret='' --password="${ADMIN_PASSWORD}"
  UAA_ACCESS_TOKEN=`uaac context | grep "access_token" | sed '1s/^[ \t]*access_token: //'`
}

login_ops_manager () {
  UAA_ACCESS_TOKEN=`uaac context | grep "access_token" | sed '1s/^[ \t]*access_token: //'`
  if [ -z "$UAA_ACCESS_TOKEN" ] ; then
    do_login
  fi

  if invalid_login ; then
    do_login
  fi
}
