#!/bin/bash

set -e

wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar -xvzf openshift-client-linux.tar.gz

sudo mv oc /usr/local/bin/
sudo chmod +x /usr/local/bin/oc

rm -f openshift-client-linux.tar.gz kubectl README.md
