#!/bin/bash

set -x

# Install the required packages
yum -y install podman httpd httpd-tools

# Create folders for the registry
rm -rf /opt/registry
mkdir -p /opt/registry/{auth,certs,data}

# Provide a certificate for the registry
openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/domain.key -x509 -days 365 -out /opt/registry/certs/domain.crt

# Generate a user name and a password for your registry that uses the bcrpt format
htpasswd -bBc /opt/registry/auth/htpasswd root passw0rd

# Open the required ports (5000) for your registry
firewall-cmd --add-port=5000/tcp --zone=internal --permanent 
firewall-cmd --add-port=5000/tcp --zone=public --permanent 
firewall-cmd --reload

# Create the mirror-registry container to host your registry
podman stop mirror-registry
podman rm mirror-registry
podman run --name mirror-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key -d docker.io/ibmcom/registry-s390x:2.6.2.5

# Add the self-signed certificate to your list of trusted certificates
rm -f /etc/pki/ca-trust/source/anchors/domain.crt
cp -f /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust

# Confirm that the registry is available - If the command output displays an empty repository, your registry is available.
read -p "Enter bastion hostname: " hostname
curl -u root:passw0rd -k https://$hostname:5000/v2/_catalog

# Generate the base64-encoded user name and password or token for your mirror registry
token=$(echo -n 'root:passw0rd' | base64 -w0)
echo 'The generated base64-encoded user name and password or token for your mirror registry is: '
echo "${token}"

# Download pull secret text file into /root directory, and convert it into JSON format
rm -f /root/pull-secret.json
cat /root/pull-secret.txt | jq .  > /root/pull-secret.json
read -p "Enter email address used to generate the certification: " email
sed -i '/\"registry.redhat.io\"/i \    \"'$hostname':5000\": {\n\      \"auth\": \"'$token'\",\n\      \"email\": \"'$email'\"\n\    },' /root/pull-secret.json

# Set the required environment variables
export OCP_RELEASE=4.6.8-s390x
export LOCAL_REGISTRY="$hostname:5000"
export LOCAL_REPOSITORY='ocp4/openshift4'
export PRODUCT_REPO='openshift-release-dev'
export LOCAL_SECRET_JSON='/root/pull-secret.json'
export RELEASE_NAME="ocp-release"

# Mirror the repository, and Record the entire imageContentSources section from the output of the previous command.
# The information about your mirrors is unique to your mirrored repository, and you must add the imageContentSources section to the install-config.yaml file during installation.
GODEBUG=x509ignoreCN=0 oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}

# create the installation program that is based on the content that you mirrored, extract it and pin it to the release
GODEBUG=x509ignoreCN=0 oc adm -a ${LOCAL_SECRET_JSON} release extract --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}"
