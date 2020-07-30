#!/bin/bash

set -x

read -p "Enter bastion hostname: " hostname
read -p "Enter the OCP version: " version

# Set the required environment variables
export OCP_RELEASE=$version-s390x
export LOCAL_REGISTRY="$hostname:5000"
export LOCAL_REPOSITORY='ocp4/openshift4'
export PRODUCT_REPO='openshift-release-dev'
export LOCAL_SECRET_JSON='/root/pull-secret.json'
export RELEASE_NAME="ocp-release"

# Mirror the repository, and Record the entire imageContentSources section from the output of the previous command.
# The information about your mirrors is unique to your mirrored repository, and you must add the imageContentSources section to the install-config.yaml file during installation.
oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}

# Set the digest for the version to update to
DIGEST="$(oc adm release info quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} | sed -n 's/Pull From: .*@//p')"

# Start the cluster update
oc adm upgrade --to-image ${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}@${DIGEST} --allow-explicit-upgrade --force

# Wait for the update to be completed
watch -n 5 oc get clusterversion
echo "The OCP Cluster has been updated to $(oc get clusterversion | sed -n 's/.*Cluster version is //p'). Restart all pods now ......\n"

# Restart all Pods after the upgrade is complete.
for I in $(oc get ns -o jsonpath='{range .items[*]} {.metadata.name}{"\n"} {end}');
do
	oc delete pods --all -n $I;
	sleep 1;
done
