#!/bin/bash

set -x

yum -y install bind-chroot

read -p "Enter cluster domain name: " domain
read -p "Enter subnet in address: " address
read -p "Enter bastion private ip address: " bastion_address

cp ./forward.zone.template /var/named/$domain.zone
cp ./reverse.zone.template /var/named/$address.in-addr.arpa.zone
cp ./named.conf.template /etc/named.conf

mv /etc/NetworkManager/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf.save
sed '/\[main\]/ a dns=none' /etc/NetworkManager/NetworkManager.conf.save > ./NetworkManager.conf

echo 'search '$domain'' >> /etc/resolv.conf
echo 'nameserver '$bastion_address'' >> /etc/resolv.conf

firewall-cmd --add-service=dns --zone=internal --permanent 
firewall-cmd --add-service=dns --zone=public --permanent 
firewall-cmd --reload

systemctl restart named
systemctl restart firewalld