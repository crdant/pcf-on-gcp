# log into the operations manager API using UAA
#    reference $UAA_ACCESS_TOKEN as the bearer token for API calls

valid_login () {
  ops_manager_fqdn=$1
  if [ -z "${ops_manager_fqdn}" ] ; then
    ops_manager_fqdn=${OPS_MANAGER_FQDN}
  fi

  status_code=`curl -qsLf -I --insecure "${OPS_MANAGER_FQDN}/api/v0/uaa/tokens_expiration"  -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"  -w "%{http_code}\n" -o /dev/null`
  if [ "$status_code" = "200" ] ; then
    return 0
  else
    return 1
  fi
}

do_login () {
  ops_manager_fqdn=$1
  if [ -z "${ops_manager_fqdn}" ] ; then
    ops_manager_fqdn=${OPS_MANAGER_FQDN}
  fi

  uaac target "${ops_manager_fqdn}/uaa" --skip-ssl-validation
  uaac token owner get opsman admin --secret='' --password="${ADMIN_PASSWORD}"
  UAA_ACCESS_TOKEN=`uaac context | grep "access_token" | sed '1s/^[ \t]*access_token: //'`
}

login_ops_manager () {
  ops_manager_fqdn=$1
  if [ -z "$ops_manager_fqdn" ] ; then
    ops_manager_fqdn=${OPS_MANAGER_FQDN}
  fi

  UAA_ACCESS_TOKEN=`uaac context | grep "access_token" | sed '1s/^[ \t]*access_token: //'`
  if [ -z "$UAA_ACCESS_TOKEN" ] ; then
    do_login $ops_manager_fqdn
  fi

  if ! valid_login $ops_manager_fqdn ; then
    do_login $ops_manager_fqdn
  fi
}
