# functions for working with products in the Ops Manager API

product_available () {
  product=$1
  version=$2

  login_ops_manager > /dev/null
  available=`curl -qsf --insecure "https://manager.${SUBDOMAIN}/api/v0/available_products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json"`
  test -z `echo ${available} | jq ". [] | select ( .name = \"$product\" ) .product_version | select ( startswith(\"$version\") )"`
}

download_tile () {
  product=$1
  version=$2
  version_token=`echo ${version} | tr . - | tr ' ' - | tr -d ')' | tr -d '('`
  numeric_version=`echo ${version} | sed 's/[^0-9.]*//g'`
  releases_url="https://network.pivotal.io/api/v2/products/${product}/releases"
  tile_file="$TMPDIR/${product}-${version_token}.pivotal"

  if [ ! -f $tile_file ] ; then
    files_url=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" "$releases_url" | jq --raw-output ".releases[] | select( .version == \"$version\" ) ._links .product_files .href"`
    download_post_url=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" $files_url | jq --raw-output ".product_files[] | select( .aws_object_key | endswith(\"pivotal\") ) ._links .download .href"`
    download_url=`curl -qsf -X POST -d "" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token $PIVNET_TOKEN" $download_post_url -w "%{url_effective}\n"`
    curl -qsf -o $tile_file $download_url
  fi

  echo $tile_file
}

download_addon () {
  product=$1
  version=$2
  version_token=`echo ${version} | tr . - | tr ' ' - | tr -d ')' | tr -d '('`
  numeric_version=`echo ${version} | sed 's/[^0-9.]*//g'`
  releases_url="https://network.pivotal.io/api/v2/products/${product}/releases"
  addon_file="$TMPDIR/${product}-${version_token}.tgz"

  if [ ! -f $addon_file ] ; then
    files_url=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" "$releases_url" | jq --raw-output ".releases[] | select( .version == \"$version\" ) ._links .product_files .href"`
    download_post_url=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" $files_url | jq --raw-output ".product_files[] | select( .aws_object_key | endswith(\"tgz\") ) ._links .download .href"`
    download_url=`curl -qsf -X POST -d "" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token $PIVNET_TOKEN" $download_post_url -w "%{url_effective}\n"`
    curl -qsf -o $tile_file $download_url
  fi

  echo $addon_file
}

upload_tile () {
  product_file=$1

  login_ops_manager > /dev/null
  curl -q --insecure -X POST "${OPS_MANAGER_API_ENDPOINT}/available_products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
    -H "Accept: application/json" -F "product[file]=@${product_file}"

}

upload_addon () {
  product_file=$1

  director_public_ip=`gcloud --format=json compute --project ${PROJECT} instances list --filter='tags.items:director' | jq --raw-output '. [] .networkInterfaces [] .accessConfigs [] | select ( .name="External NAT" ) .natIP'`
  echo "Upload not yet implememented. You need to run (something like) the following: "
  echo "   scp -i ${KEYDIR}/vcap-key $product_file vcap@$director_public_ip:$product_file"
}

stage_product () {
  product=$1

  login_ops_manager > /dev/null

  available_product=`curl -qsf --insecure "${OPS_MANAGER_API_ENDPOINT}/available_products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" -H "Accept: application/json" | jq --raw-output ".[] | select ( .name == \"$product\" )"`
  product_name=`echo $available_product | jq --raw-output ".name"`
  available_version=`echo $available_product | jq --raw-output ".product_version"`
  curl -qsf --insecure -X POST "${OPS_MANAGER_API_ENDPOINT}/staged/products" -H "Authorization: Bearer ${UAA_ACCESS_TOKEN}" \
    -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"name\": \"$product_name\", \"product_version\": \"${available_version}\"}"
}
