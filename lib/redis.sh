set_redis_plans () {
  login_ops_manager

  pick_plan_availability_zone
  SMALL_PLAN_AVAILABILITY_ZONE="${PLAN_AVAILABILITY_ZONE}"
  pick_plan_availability_zone
  MEDIUM_PLAN_AVAILABILITY_ZONE="${PLAN_AVAILABILITY_ZONE}"
  pick_plan_availability_zone
  LARGE_PLAN_AVAILABILITY_ZONE="${PLAN_AVAILABILITY_ZONE}"

  plan_json=`export SMALL_PLAN_AVAILABILITY_ZONE MEDIUM_PLAN_AVAILABILITY_ZONE LARGE_PLAN_AVAILABILITY_ZONE ; envsubst < api-calls/redis/plans.json ; unset SMALL_PLAN_AVAILABILITY_ZONE MEDIUM_PLAN_AVAILABILITY_ZONE LARGE_PLAN_AVAILABILITY_ZONE`
  set_properties "${REDIS_SLUG}" "${plan_json}"

}

pick_plan_availability_zone () {
  ROLL=$(($(($RANDOM%10))%3))
  if [ $ROLL -eq 1 ] ; then
    PLAN_AVAILABILITY_ZONE="${AVAILABILITY_ZONE_1}"
  elif [ $ROLL -eq 2 ] ; then
    PLAN_AVAILABILITY_ZONE="${AVAILABILITY_ZONE_2}"
  else
    PLAN_AVAILABILITY_ZONE="${AVAILABILITY_ZONE_3}"
  fi
}
