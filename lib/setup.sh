# setup the GCP CLI environment  for these scripts

setup () {
  # make sure our API components up-to-date
  gcloud components update

  # log in (parameterize later)
  gcloud auth login ${ACCOUNT}
  gcloud config set project ${PROJECT}
  gcloud config set compute/zone ${AVAILABILITY_ZONE_1}
  gcloud config set compute/region ${REGION_1}
}
