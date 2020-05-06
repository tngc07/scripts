#!/bin/bash

# Check if script is being run by root
if [[ $EUID -ne 0 ]]; then
   printf "This script must be run as root!\n"
   exit 1
fi

DIVIDER="\n**********************************************\n\n"

# Update Package Index
sudo apt update
sudo apt upgrade -y

# Welcome and instructions
printf $DIVIDER
printf "Svii LAMP server setup on Ubuntu 20.04\n"
printf "Apache, MariaDB, Php, Adminer, Tiny File Manager\n"
printf $DIVIDER

# Prompt to continue
while true; do
	read -p "Continue [Y/N]? " cnt1
	case $cnt1 in
		[Yy]* ) break;;
		[Nn]* ) exit;;
		* ) printf "Please answer Y or N\n";;
	esac
done

# Install Apache2, MySQL, PHP
#sudo apt install apache2 mysql-server php php-mysql libapache2-mod-php php-cli

# Install Apache2, MariaDB, PHP
sudo apt install apache2 apache2-utils software-properties-common mariadb-server mariadb-client php php-common php-mysql libapache2-mod-php php-cli php-zip php-cgi php-imap php-auth php-mcrypt php-curl php-gd php-mbstring php-xml php-soap php-opcache php-intl php-apcu php-mail php-mail-mime php-memcached php-gettext

#Let’s ensure we harden our MariaDB server and set the root password.
sudo mysql_secure_installation

# Allow to run Apache on boot up
sudo systemctl enable apache2

# Restart Apache Web Server
sudo systemctl start apache2

# Adjust Firewall
sudo ufw allow in "Apache Full"

# Allow Read/Write for Owner
sudo chmod -R 0755 /var/www/html/

# Create info.php for testing php processing
sudo echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# Open localhost in the default browser
xdg-open "http://localhost"
xdg-open "http://localhost/info.php"
