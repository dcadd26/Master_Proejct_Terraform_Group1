#!/bin/bash
dnf update -y
dnf install -y httpd git
systemctl enable httpd
systemctl start httpd

rm -rf /var/www/html/*
git clone https://github.com/erzaduraku/group1-master-webapp.git /tmp/webapp
cp /tmp/webapp/index.html /var/www/html/
cp /tmp/webapp/style.css /var/www/html/
systemctl restart httpd

