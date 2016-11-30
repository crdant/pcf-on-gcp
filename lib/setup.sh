# setup the GCP CLI environment  for these scripts

setup () {
  # make sure our API components up-to-date
  gcloud components update --quiet --verbosity="critical" --no-user-output-enabled

  # log in (parameterize later)
  gcloud auth login ${ACCOUNT} --quiet --verbosity="critical" --no-user-output-enabled
  gcloud config set project ${PROJECT} --quiet --verbosity="critical" --no-user-output-enabled
  gcloud config set compute/zone ${AVAILABILITY_ZONE_1} --quiet --verbosity="critical" --no-user-output-enabled
  gcloud config set compute/region ${REGION_1} --quiet --verbosity="critical" --no-user-output-enabled
}
