set_rabbit_config () {
  login_ops_manager
  RABBIT_PRIVATE_KEY=`cat ${KEYDIR}/rabbit-mq-${SUBDOMAIN_TOKEN}.key | perl -pe 's#\n#\x5c\x5c\x6e#g'`
  RABBIT_CERTIFICATE=`cat ${KEYDIR}/rabbit-mq-${SUBDOMAIN_TOKEN}.crt | perl -pe 's#\n#\x5c\x5c\x6e#g'`

  rabbit_json=`export RABBIT_PRIVATE_KEY RABBIT_CERTIFICATE ; envsubst < api-calls/rabbitmq/config.json ; unset RABBIT_PRIVATE_KEY RABBIT_CERTIFICATE`
  set_properties "${RABBIT_SLUG}" "${rabbit_json}"
}

set_rabbit_single_node_plan () {
  login_ops_manager

  plan_json=`export AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3 ; envsubst < api-calls/rabbitmq/single-node.json ; unset AVAILABILITY_ZONE_1 AVAILABILITY_ZONE_2 AVAILABILITY_ZONE_3`
  set_properties "${RABBIT_SLUG}" "${plan_json}"

}
