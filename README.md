### PCF - GCP Automation Scripts

## Inputs

Add a file named `personal.sh` to include your Google account, Google project, and domain:

```
ACCOUNT="your-account@your-domain-or-gmail.com"
PROJECT="your-project"
DOMAIN="domain-for-your-pcf-install"
```

You can add other variables there to override the variables in lib/env.sh. Some of those will move into commandline arguments soon,
but you can customize them otherwise using personal.sh today.

There is also an assumption that the environment variable PIVNET_TOKEN is set in your environment (I do that in my .zshenv). If you
don't already have it set to your Pivotal Network API token, you can set that in `personal.sh` as well.

## Steps to Install

The installation is split into two steps, one to prepare the Google cloud infrastructure for your installation, another to install products.
Currently the product installation can install Cloud Foundry, MySQL, Rabbit MQ, Redis, the GCP Service Broker, Gemfire, and Concourse. More products
will be added later.

```
$ prepare.sh
```

In between the two steps, there you need to go into the Ops Manager UI and configure the Google Cloud Platform tile. This will start the BOSH
director in your environment.  There are some steps there that are not easily done via the Ops Manager APIs, though I have some ideas and may
be able to do some additional automation there.

```
$ install.sh
```

This will install the defaults, which are Cloud Foundry, MySQL, Rabbit MQ, Redis, and the GCP Service Broker. You can also specify individual
products. See the usage for the command.

```
$ install.sh --help
install.sh [ pcf ] [ mysql ] [ rabbit ] [ redis ] [ scs ] [ gcp ] [ gemfire ] [ concourse ]
```

## Steps to Uninstall

Use the `teardown.sh` script to teardown your installation. There will be no trace of it left on GCP.

```
teardown.sh
```

## Help

Some scripts to facilitate working with PCF on Google Cloud Platform.
Currently a private repository while I make sure there isn't anything sensitive in it.
