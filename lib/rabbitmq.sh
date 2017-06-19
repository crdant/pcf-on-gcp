set_rabbit_config () {
  login_ops_manager
  RABBIT_PRIVATE_KEY=`cat ${KEYDIR}/rabbit-mq-${SUBDOMAIN_TOKEN}.key | perl -pe 's#\n#\x5c\x5c\x6e#g'`
  RABBIT_CERTIFICATE=`cat ${KEYDIR}/rabbit-mq-${SUBDOMAIN_TOKEN}.crt | perl -pe 's#\n#\x5c\x5c\x6e#g'`

  rabbit_json=`export RABBIT_PRIVATE_KEY RABBIT_CERTIFICATE ; envsubst < api-calls/rabbitmq/networking.json ; unset RABBIT_PRIVATE_KEY RABBIT_CERTIFICATE TCP_ROUTER_PORTS`
  set_properties "${PCF_OPSMAN_SLUG}" "${rabbit_json}"
}
