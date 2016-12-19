# accept a Pivotal EULA
accept_eula () {
  product=$1
  version=$2
  accepted=$3

  releases_url="https://network.pivotal.io/api/v2/products/${product}/releases"

  if [ "${accepted}" = "yes" ]; then
    eula_url=`curl -qsLf -H "Authorization: Token $PIVNET_TOKEN" $releases_url | jq --raw-output ".releases[] | select( .version == \"$version\" ) ._links .eula_acceptance .href"`
    accepted_at=`curl -qsLf -X POST -d "" -H "Authorization: Token $PIVNET_TOKEN" $eula_url | jq --raw-output '.accepted_at'`
    echo "Accepted EULA for $product at $accepted_at"
  else
    echo "Did not accept EULA for $product"
  fi
}
