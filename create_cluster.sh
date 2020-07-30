#!/bin/bash

set -x

# Generating an SSH private key and adding it to the agent 
rm -rf /root/.ssh
ssh-keygen -t rsa -b 4096 -N '' -f /root/.ssh/id_rsa
eval "$(ssh-agent -s)"
ssh-add /root/.ssh/id_rsa

# Create an openshift work directory for the installation configuration file
rm -rf /root/ocp_cluster
mkdir -p /root/ocp_cluster
cp ./template/install-config.yaml.template /root/ocp_cluster/install-config.yaml
cp ./template/install-config.yaml.template /root/ocp_cluster/install-config.yaml.saved

# Create the Kubernetes manifest and Ignition config files
./openshift-install create manifests --dir=/root/ocp_cluster/

# Prevent Pods from being scheduled on the control plane machines
sed -i 's/^  mastersSchedulable: .*$/  mastersSchedulable: False/' /root/ocp_cluster/manifests/cluster-scheduler-02-config.yml

# Obtain the Ignition config files
./openshift-install create ignition-configs --dir=/root/ocp_cluster/

# Copy the Ignition config files to 
cp /root/ocp_cluster/*.ign /home/linuxone/OCP/.

# The kubeconfig has to be copied in the correct PATH
rm -rf ~/.kube
mkdir -p ~/.kube
cp /root/ocp_cluster/auth/kubeconfig /root/.kube/config

./openshift-install --dir /root/ocp_cluster wait-for bootstrap-complete --log-level=debug

oc get nodes
oc get csr
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve

./openshift-install --dir /root/ocp_cluster wait-for install-complete