#!/bin/bash

set -x

yum -y install haproxy python3-libsemanage

systemctl restart haproxy
systemctl enable haproxy

systemctl restart firewalld
systemctl enable firewalld

mv -f /etc/haproxy/haproxy.cfg  /etc/haproxy/haproxy.cfg.orig
cp ./haproxy.template /etc/haproxy/haproxy.cfg

firewall-cmd --add-service=http --zone=public --permanent
firewall-cmd --add-service=http --zone=internal --permanent
firewall-cmd --add-service=https --zone=public --permanent
firewall-cmd --add-service=https --zone=internal --permanent
firewall-cmd --reload

firewall-cmd --add-port=443/tcp --zone=internal --permanent
firewall-cmd --add-port=443/tcp --zone=public --permanent
firewall-cmd --add-port=6443/tcp --zone=internal --permanent
firewall-cmd --add-port=6443/tcp --zone=public --permanent
firewall-cmd --add-port=22623/tcp --zone=internal --permanent
firewall-cmd --add-port=22623/tcp --zone=public --permanent
firewall-cmd --reload

setsebool -P haproxy_connect_any 1
systemctl restart haproxy
systemctl restart firewalld