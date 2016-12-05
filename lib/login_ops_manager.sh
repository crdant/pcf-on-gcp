# log into the operations manager API using UAA
#    reference $UAA_ACCESS_TOKEN as the bearer token for API calls

validate_login () {
  status_code=`curl -qs -I --insecure "https://manager.${SUBDOMAIN}/api/v0/uaa/tokens_expiration"  -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"  -w "%{http_code}\n"`
  if [ "$status_code" = "401" ] ; then
    return 0
  else
    return 1
  fi
}

do_login () {
  uaac target "https://manager.$SUBDOMAIN/uaa" --skip-ssl-validation
  uaac token owner get opsman admin --secret='' --password="${ADMIN_PASSWORD}"
  UAA_ACCESS_TOKEN=`uaac context | grep "access_token" | sed '1s/^[ \t]*access_token: //'`
}

login_ops_manager () {
  UAA_ACCESS_TOKEN=`uaac context | grep "access_token" | sed '1s/^[ \t]*access_token: //'`
  if [ -z "$UAA_ACCESS_TOKEN" ] ; then
    do_login
  fi

  validate_login
  if [ $? -eq 0 ] ; then
    do_login
  fi
}
