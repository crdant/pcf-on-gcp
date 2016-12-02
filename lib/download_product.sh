# download a product from pivnet (assumes EULA has been accepted)
#    outputs the pathname of the downloaded file

download_product () {
  set -o xtrace
  product=$1
  version=$2
  version_token=`echo ${version} | tr . - | tr ' ' - | tr -d ')' | tr -d '('`
  numeric_version=`echo ${version} | sed 's/[^0-9.]*//g'`
  releases_url="https://network.pivotal.io/api/v2/products/${product}/releases"
  tile_file="$TMPDIR/${product}-${version_token}.pivotal"

  files_url=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" "$releases_url" | jq --raw-output ".releases[] | select( .version == \"$version\" ) ._links .product_files .href"`
  download_post_url=`curl -qsf -H "Authorization: Token $PIVNET_TOKEN" $files_url | jq --raw-output ".product_files[] | select( .aws_object_key | endswith(\"pivotal\") ) ._links .download .href"`
  download_url=`curl -qsf -X POST -d "" -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Token $PIVNET_TOKEN" $download_post_url -w "%{url_effective}\n"`

  curl -qsf -o $tile_file $download_url
  echo $tile_file
}
