name_service_account () {
  stub="${1}"

  if [ ${#stub} -gt 30 ] ; then
    echo "Can't name a service account with a stub longer than the maximum length"
    exit 255 ;
  fi

  name="${stub}-${SUBDOMAIN_TOKEN}"

  if [ ${#name} -lt 6 ] ; then
    name="${name}-account"
  fi

  if [ ${#name} -gt 30 ] ; then
    discrim="${SUBDOMAIN_TOKEN}"
    local IFS='-' ; read -r -a parts <<< "${discrim}"
    for position in "${!parts[@]}"
    do
      index=$((-1 - position))
      echo "index: $index"
      echo "part at position: ${parts[$position]}"
      echo "part at index: ${parts[$index]}"
      parts[$index]=${parts[$index]:0:1}
      local IFS='-' ; name="${stub}-${parts[*]}"
      if [ ${#name} -lt 30 ] ; then
        break
      fi
      index=$((index - 1))
    done
  fi

  echo "$name"
}
