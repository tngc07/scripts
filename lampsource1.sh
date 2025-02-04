#!/bin/bash

# Check if script is being run by root
if [[ $EUID -ne 0 ]]; then
   printf "This script must be run as root!\n"
   exit 1
fi

DIVIDER="\n***************************************\n\n"

# Welcome and instructions
printf $DIVIDER
printf "Lyquix LAMP server setup on Ubuntu 16.04\n"
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

# Set the hostname
printf $DIVIDER
printf "HOSTNAME\n"
printf "Pick a hostname that identify this server.\nRecommended: use the main domain, e.g. example.com\n"
while true; do
	read -p "Hostname: " host
	case $host in
		"" ) printf "Hostname may not be left blank\n";;
		* ) break;;
	esac
done
echo "$host" > /etc/hostname
hostname -F /etc/hostname
printf "127.4.0.1       $host\n::1             $host\n" >> /etc/hosts;

# Set the time zone
printf $DIVIDER
printf "TIME ZONE\n"
printf "Please select the correct time zone. e.g. US > Eastern Time\n"
read -p "Please ENTER to continue "
dpkg-reconfigure tzdata

# Install and update software
printf $DIVIDER
printf "INSTALL AND UPDATE SOFTWARE\n"
printf "Now the script will update Ubuntu and install all the necessary software.\n"
printf " * You will be prompted to enter the password for the MySQL root user\n"
read -p "Please ENTER to continue "
apt-get -y update
apt-get -y upgrade
apt-get -y install curl vim openssl git htop nload nethogs zip unzip sendmail sendmail-bin libcurl3-openssl-dev psmisc build-essential zlib1g-dev libpcre3 libpcre3-dev memcached fail2ban
apt-get -y install apache2 apache2-doc apachetop libapache2-mod-php libapache2-mod-fcgid apache2-suexec-pristine libapache2-modsecurity
apt-get -y install mcrypt imagemagick php7.4 php7.4-common php7.4-gd php7.4-imap php7.4-mysql php7.4-cli php7.4-cgi php7.4-zip php-pear php-auth php7.4-mcrypt php-imagick php7.4-curl php7.4-mbstring php7.4-bcmath php7.4-xml php7.4-soap php7.4-opcache php7.4-intl php-apcu php-mail php-mail-mime php-memcached php-all-dev php7.4-dev
apt-get -y install mariadb-server mariadb-client

# Set up unattended upgrades
printf $DIVIDER
printf "UNATTENDED UPGRADES\n"
printf "When prompted please select YES to enable security updates and patches to be automatically installed.\n"
read -p "Please ENTER to continue "
apt-get -y install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# Set password for www-data user and allow shell access
printf $DIVIDER
printf "WWW-DATA USER\n"
printf "Set password for www-data user, set home directory permissions, and allow shell access.\n"
passwd -u www-data
passwd www-data
mkdir /var/www
chown -R www-data:www-data /var/www
chsh -s /bin/bash www-data

# APACHE configuration
printf $DIVIDER
printf "APACHE CONFIGURATION\n"
read -p "Please ENTER to continue "

printf "Enabling Apache modules...\n"
a2enmod expires headers rewrite ssl suphp mpm_prefork security2

if [ ! -f /etc/apache2/apache2.conf.orig ]; then
	printf "Backing up original configuration file to /etc/apache2/apache2.conf.orig\n"
	cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.orig
fi

printf "Changing MaxKeepAliveRequests to 0...\n"
FIND="^\s*MaxKeepAliveRequests \s*[0-9]*"
REPLACE="MaxKeepAliveRequests 0"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/apache2.conf

printf "Adding browser caching configuration...\n"
FIND="#<\/Directory>"
REPLACE="#<\/Directory>\n\n# Disable server signature\nServerSignature Off\nServerTokens Prod\n\n# Browser Caching #\nExpiresActive On\nExpiresDefault \"access plus 30 days\"\nExpiresByType text\/html \"access plus 15 minutes\"\nHeader unset Last-Modified\nHeader unset ETag\nFileETag None\n\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/apache2.conf

printf "Adding <Directory /srv/www/> configuration for /srv/www...\n"
FIND="#<\/Directory>"
REPLACE="#<\/Directory>\n\n<Directory \/srv\/www\/>\n\tOptions FollowSymLinks\n\tAllowOverride all\n\tRequire all granted\n\tHeader set Access-Control-Allow-Origin \"\*\"\n\tHeader set Timing-Allow-Origin \"\*\"\n\tHeader set X-Content-Type-Options \"nosniff\"\n\tHeader set X-Frame-Options sameorigin\n\tHeader unset X-Powered-By\n\tHeader set X-UA-Compatible \"IE=edge\"\n<\/Directory>\n\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/apache2.conf

if [ ! -f /etc/apache2/mods-available/deflate.conf.orig ]; then
	printf "Backing up original compression configuration file to /etc/apache2/mods-available/deflate.conf.orig\n"
	cp /etc/apache2/mods-available/deflate.conf /etc/apache2/mods-available/deflate.conf.orig
fi

printf "Adding compression for SVG and fonts...\n"
FIND="<\/IfModule>"
REPLACE="\t# Add SVG images\n\t\tAddOutputFilterByType DEFLATE image\/svg+xml\n\t\t# Add font files\n\t\tAddOutputFilterByType DEFLATE application\/x-font-woff\n\t\tAddOutputFilterByType DEFLATE application\/x-font-woff2\n\t\tAddOutputFilterByType DEFLATE application\/vnd.ms-fontobject\n\t\tAddOutputFilterByType DEFLATE application\/x-font-ttf\n\t\tAddOutputFilterByType DEFLATE application\/x-font-otf\n\t<\/IfModule>"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/deflate.conf

if [ ! -f /etc/apache2/mods-available/mime.conf.orig ]; then
	printf "Backing up original MIME configuration file to /etc/apache2/mods-available/mime.conf.orig\n"
	cp /etc/apache2/mods-available/mime.conf /etc/apache2/mods-available/mime.conf.orig
fi

printf "Adding MIME types for font files...\n"
FIND="<IfModule mod_mime\.c>"
REPLACE="<IfModule mod_mime\.c>\n\n\t# Add font files\n\tAddType application\/x-font-woff2 \.woff2\n\tAddType application\/x-font-otf \.otf\n\tAddType application\/x-font-ttf \.ttf\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/mime.conf

if [ ! -f /etc/apache2/mods-available/dir.conf.orig ]; then
	printf "Backing up original directory listing configuration file to /etc/apache2/mods-available/dir.conf.orig\n"
	cp /etc/apache2/mods-available/dir.conf /etc/apache2/mods-available/dir.conf.orig
fi

printf "Making index.php the default file for directory listing...\n"
FIND="index\.php "
REPLACE=""
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/dir.conf

FIND="DirectoryIndex"
REPLACE="DirectoryIndex index\.php"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/dir.conf

if [ ! -f /etc/apache2/mods-available/mpm_prefork.conf.orig ]; then
	printf "Backing up original mpm_prefork configuration file to /etc/apache2/mods-available/mpm_prefork.conf.orig\n"
	cp /etc/apache2/mods-available/mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf.orig
fi

# APACHE memory settings
PROCMEM=32 # Average amount of memory used by each request
SYSMEM=$(grep MemTotal /proc/meminfo | awk '{ print int($2/1024) }') # System memory
SYSMEN=${SYSMEM/.*}
AVAILMEM=$(((SYSMEM-256)*75/100)) # Memory available to Apache: (Total - 256MB) x 80%
MAXWORKERS=$((AVAILMEM/PROCMEM)) # Max number of request workers: available memory / average request memory
STARTSERVERS=$((MAXWORKERS/10)) # Min number of servers started
SPARESERVERS=$((STARTSERVERS*4)) # Max number of spare servers started

printf "Updating memory settings...\n"
FIND="^\s*StartServers\s*[0-9]*"
REPLACE="\tStartServers\t\t\t$STARTSERVERS"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/mpm_prefork.conf
FIND="^\s*MinSpareServers\s*[0-9]*"
REPLACE="\tMinSpareServers\t\t $STARTSERVERS"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/mpm_prefork.conf
FIND="^\s*MaxSpareServers\s*[0-9]*"
REPLACE="\tMaxSpareServers\t\t $SPARESERVERS"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/mpm_prefork.conf
FIND="^\s*MaxRequestWorkers\s*[0-9]*"
REPLACE="\tMaxRequestWorkers\t\t$MAXWORKERS"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/mpm_prefork.conf
FIND="^\s*MaxConnectionsPerChild\s*[0-9]*"
REPLACE="\tMaxConnectionsPerChild  0"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/mpm_prefork.conf

# Apache logs rotation and compression
if ! grep -q /srv/www/*/logs/ "/etc/logrotate.d/apache2"; then
	LOGROTATE="/srv/www/*/logs/access.log {\n\tmonthly\n\tmissingok\n\trotate 12\n\tcompress\n\tnotifempty\n\tcreate 644 www-data www-data\n}\n/srv/www/*/logs/error.log {\n\tsize 100M\n\tmissingok\n\trotate 4\n\tcompress\n\tnotifempty\n\tcreate 644 www-data www-data\n}\n"
	printf "$LOGROTATE" >> /etc/logrotate.d/apache2
fi

#ModPageSpeed
printf $DIVIDER
printf "MODPAGESPEED\n"
printf "Please answer Yes when prompted\n"
read -p "Press ENTER to continue"
wget https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-stable_current_amd64.deb
dpkg -i mod-pagespeed*.deb
rm mod-pagespeed*.deb
apt-get -f install

if [ ! -f /etc/apache2/mods-available/pagespeed.conf.orig ]; then
	printf "Backing up original ModPagespeed configuration file to /etc/apache2/mods-available/pagespeed.conf.orig\n"
	cp /etc/apache2/mods-available/pagespeed.conf /etc/apache2/mods-available/pagespeed.conf.orig
fi
printf "Adding non-core filters...\n"
FIND="^\s*ModPagespeed on"
REPLACE="\tModPagespeed on\n\nModPagespeedEnableFilters collapse_whitespace,remove_comments\nModPagespeedEnableFilters insert_dns_prefetch\n# ModPagespeedEnableFilters responsive_images\n#ModPagespeedEnableFilters rewrite_images\nModPagespeedEnableFilters outline_css,combine_css,rewrite_css\n# ModPagespeedEnableFilters rewrite_javascript,include_js_source_maps\nModPagespeedEnableFilters add_instrumentation\n# ModPagespeedEnableFilters lazyload_images\n# ModPagespeedEnableFilters defer_javascript\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/pagespeed.conf

# Virtual Hosts
printf $DIVIDER
printf "VIRTUAL HOSTS\n"
printf "The script will setup the base virtual hosts configuration. Using the main domain name it will:\n"
printf " * Setup configuration files for example.com (with alias www.example.com), and dev.example.com\n"
printf " * Setup the necessary directories\n"
while true; do
	read -p "Please enter the main domain (e.g. example.com): " domain
	case $domain in
		"" ) printf "Domain may not be left blank\n";;
		* ) break;;
	esac
done

# Get IPv4
IPV4=$(ip -4 addr | grep inet | awk -F '[ \t]+|/' '{print $3}' | grep -v ^127.4.0.1)

# Backup previous virtual host files
if [ -f /etc/apache2/sites-available/$domain.conf ]; then
	printf "Backing up existing virtual host configuration file to /etc/apache2/sites-available/$domain.conf.bak\n"
	cp /etc/apache2/sites-available/$domain.conf /etc/apache2/sites-available/$domain.conf.bak
fi

# Production
VIRTUALHOST="<VirtualHost $IPV4:80>\n\tServerName $domain\n\tServerAlias www.$domain\n\tDocumentRoot /srv/www/$domain/public_html/\n\tErrorLog /srv/www/$domain/logs/error.log\n\tCustomLog /srv/www/$domain/logs/access.log combined\n</VirtualHost>\n";
printf "$VIRTUALHOST" > /etc/apache2/sites-available/$domain.conf

# Development
VIRTUALHOST="<VirtualHost $IPV4:80>\n\tServerName dev.$domain\n\tDocumentRoot /srv/www/dev.$domain/public_html/\n\tErrorLog /srv/www/dev.$domain/logs/error.log\n\tCustomLog /srv/www/dev.$domain/logs/access.log combined\n</VirtualHost>\n";
printf "$VIRTUALHOST" > /etc/apache2/sites-available/dev.$domain.conf

# Create directories
mkdir -p /srv/www/$domain/public_html
mkdir -p /srv/www/$domain/logs
mkdir -p /srv/www/dev.$domain/public_html
mkdir -p /srv/www/dev.$domain/logs
chown -R www-data:www-data /srv/www

# Enable sites
a2ensite $domain
a2ensite dev.$domain
service apache2 reload

# PHP
printf $DIVIDER
printf "PHP\n"
printf "The script will update PHP configuration\n"
read -p "Press ENTER to continue"

if [ ! -f /etc/php/7.4/apache2/php.ini.orig ]; then
	printf "Backing up PHP.ini configuration file to /etc/php/7.4/apache2/php.ini.orig\n"
	cp /etc/php/7.4/apache2/php.ini /etc/php/7.4/apache2/php.ini.orig
fi

FIND="^\s*output_buffering\s*=\s*.*"
REPLACE="output_buffering = Off"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*max_execution_time\s*=\s*.*"
REPLACE="max_execution_time = 60"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*error_reporting\s*=\s*.*"
REPLACE="error_reporting = E_ALL \& ~E_NOTICE \& ~E_STRICT \& ~E_DEPRECATED"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*log_errors_max_len\s*=\s*.*"
REPLACE="log_errors_max_len = 0"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*post_max_size\s*=\s*.*"
REPLACE="post_max_size = 200M"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*upload_max_filesize\s*=\s*.*"
REPLACE="upload_max_filesize = 500M"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*short_open_tag\s*=\s*.*"
REPLACE="short_open_tag = On"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*;\s*max_input_vars\s*=\s*.*" # this is commented in the original file
REPLACE="max_input_vars = 5000"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*;\s*opcache\.enable\s*=\s*.*" # this is commented in the original file
REPLACE="opcache.enable = 0"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*;\s*opcache\.memory_consumption\s*=\s*.*" # this is commented in the original file
REPLACE="opcache.memory_consumption = 256"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*;\s*opcache\.max_accelerated_files\s*=\s*.*" # this is commented in the original file
REPLACE="opcache.max_accelerated_files = 5000"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

FIND="^\s*;\s*opcache\.revalidate_freq\s*=\s*.*" # this is commented in the original file
REPLACE="opcache.revalidate_freq = 30"
printf "php.ini: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/php/7.4/apache2/php.ini

# php7.4.conf correct settings
if [ ! -f /etc/apache2/mods-available/php7.4.conf.orig ]; then
	printf "Backing up php7.4.conf configuration file to /etc/apache2/mods-available/php7.4.conf.orig\n"
	cp /etc/apache2/mods-available/php7.4.conf /etc/apache2/mods-available/php7.4.conf.orig
fi

printf "Correct settings in php7.4.conf\n"
FIND="Order Deny,Allow"
REPLACE="# Order Deny,Allow"
sed -i "s/$FIND/$REPLACE/g" /etc/apache2/mods-available/php7.4.conf

FIND="Deny from all"
REPLACE="# Deny from all\n\tRequire all granted"
sed -i "s/$FIND/$REPLACE/g" /etc/apache2/mods-available/php7.4.conf

# Restart Apache
printf "Restarting Apache...\n"
service apache2 restart


# MySQL
printf $DIVIDER
printf "MYSQL\n"
printf "The script will update MySQL and setup intial databases\n"
read -p "Press ENTER to continue"

if [ ! -f /etc/mysql/my.cnf.orig ]; then
	printf "Backing up my.cnf configuration file to /etc/mysql/my.cnf.orig\n"
	cp /etc/mysql/my.cnf /etc/mysql/my.cnf.orig
fi

printf "Updating configuration\n"

FIND="^\s*key_buffer\s*=\s*.*"
REPLACE="key_buffer=16M"
printf "my.cnf: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/mysql/my.cnf

FIND="^\s*max_allowed_packet\s*=\s*.*"
REPLACE="max_allowed_packet=16M"
printf "my.cnf: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/mysql/my.cnf

FIND="^\s*thread_stack\s*=\s*.*"
REPLACE="thread_stack=192K"
printf "my.cnf: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/mysql/my.cnf

FIND="^\s*thread_cache_size\s*=\s*.*"
REPLACE="thread_cache_size=8"
printf "my.cnf: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/mysql/my.cnf

FIND="^\s*#\s*table_cache\s*=\s*.*" # commented by default
REPLACE="table_cache=64"
printf "my.cnf: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/mysql/my.cnf

FIND="^\s*#\s*log_slow_queries\s*=\s*.*" # commented by default
REPLACE="log_slow_queries = /var/log/mysql/mysql-slow.log"
printf "my.cnf: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/mysql/my.cnf

FIND="^\s*#\s*long_query_time\s*=\s*.*" # commented by default
REPLACE="long_query_time=1"
printf "my.cnf: $REPLACE\n"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/mysql/my.cnf

printf "Secure MySQL installation\n"
printf "Make sure you enter a new root password, and answer all questions with Y\n"
read -p "Please ENTER to continue "
mysql_secure_installation

printf "Setup databases and users\n"

while true; do
	read -sp "Enter password for MySQL root: " mysqlrootpsw
	case $mysqlrootpsw in
		"" ) printf "Password may not be left blank\n";;
		* ) break;;
	esac
done

printf "\nPlease set name for databases, users and passwords\n"
while true; do
	read -p "Production database name (recommended: use domain without TLD, for mydomain.com use mydomain): " dbname
	case $dbname in
		"" ) printf "Database name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Production database user (recommended: use same as database name, max 16 characters): " dbuser
	case $dbuser in
		"" ) printf "User name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -sp "Production database password: " dbpass
	case $dbpass in
		"" ) printf "\nPassword may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	printf "\n"
	read -p "Development database name (recommended: use domain without TLD followed by _dev, for mydomain.com use mydomain_dev): " devdbname
	case $devdbname in
		"" ) printf "Database name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -p "Development database user (recommended: use same as database name, max 16 characters): " devdbuser
	case $devdbuser in
		"" ) printf "User name may not be left blank\n";;
		* ) break;;
	esac
done
while true; do
	read -sp "Development database password: " devdbpass
	case $devdbpass in
		"" ) printf "\nPassword may not be left blank\n";;
		* ) break;;
	esac
done

printf "Create database $dbname...\n"
mysql -u root -p$mysqlrootpsw -e "CREATE DATABASE $dbname;"
printf "Create user $dbuser...\n"
mysql -u root -p$mysqlrootpsw -e "CREATE USER '$dbuser'@localhost IDENTIFIED BY '$dbpass';"
printf "Grant $dbuser all privileges on $dbname...\n"
mysql -u root -p$mysqlrootpsw -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@localhost;"
printf "Create database $devdbname...\n"
mysql -u root -p$mysqlrootpsw -e "CREATE DATABASE $devdbname;"
printf "Create user $devdbuser...\n"
mysql -u root -p$mysqlrootpsw -e "CREATE USER '$devdbuser'@localhost IDENTIFIED BY '$devdbpass';"
printf "Grant $devdbuser all privileges on $devdbname...\n"
mysql -u root -p$mysqlrootpsw -e "GRANT ALL PRIVILEGES ON $devdbname.* TO '$devdbuser'@localhost;"

printf "Restart MySQL...\n"
service mysql restart

printf "Add automatic database dump and rotation...\n"
#write out current crontab
crontab -l > mycron.txt
#echo new cron into cron file
printf "# Daily 00:00 - database check and optimization\n0 0 * * * mysqlcheck -Aos -u root -p'$mysqlrootpsw' > /dev/null 2>&1\n\n# Daily 01:00 - database dump\n0 1 * * * mysqldump -u root -p'$mysqlrootpsw' --all-databases --single-transaction --quick > /var/lib/mysql/daily.sql\n\n# Mondays 02:00 - copy daily database dump to weekly\n0 2 * * 0 cp /var/lib/mysql/daily.sql /var/lib/mysql/weekly.sql\n\n# First Day of the Month 02:00 - copy daily database dump to monthly\n0 2 1 * * cp /var/lib/mysql/daily.sql /var/lib/mysql/monthly.sql\n\n# Daily 05:00 update apache bad bot blocker definitions\n0 5 * * * /usr/sbin/apache-bad-bot-blocker.sh\n" >> mycron.txt
#install new cron file
crontab mycron.txt
rm mycron.txt

if [ ! -f /etc/logrotate.d/mysql-backup ]; then
	printf "Creating database backup rotation and compression file\n"
	printf "# Daily\n/var/lib/mysql/daily.sql {\n\t daily\n\t missingok\n\t rotate 7\n\t compress\n\t copy\n}\n\n# Weekly\n/var/lib/mysql/weekly.sql {\n\t weekly\n\t missingok\n\t rotate 4\n\t compress\n\t copy\n}\n\n# Monthly\n/var/lib/mysql/monthly.sql {\n\t monthly\n\t missingok\n\t rotate 12\n\t compress\n\t copy\n}\n" > /etc/logrotate.d/mysql-backup
fi

# Set firewall rules
printf $DIVIDER
printf "Setting up firewall rules...\n"
iptables -F
iptables -P INPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -j DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP
ip6tables -F
ip6tables -P INPUT ACCEPT
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -A INPUT -p tcp --dport 22 -j ACCEPT
ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT
ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT
ip6tables -A INPUT -j DROP
ip6tables -P OUTPUT ACCEPT
ip6tables -P FORWARD DROP

# Set fail2ban jails
printf $DIVIDER
printf "Setting up fail2ban jails rules...\n"
FAIL2BANJAILS="[sshd]\nenabled = true\n\n[sshd-ddos]\nenabled = true\n\n[apache-auth]\nenabled = true\n\n[apache-badbots]\nenabled = true\n\n[apache-noscript]\nenabled = true\n\n[apache-overflows]\nenabled = true\n\n[apache-nohome]\nenabled = true\n\n[apache-botsearch]\nenabled = true\n\n[apache-fakegooglebot]\nenabled = true\n\n[apache-modsecurity]\nenabled = true\n\n[apache-shellshock]\nenabled = true\n\n[php-url-fopen]\nenabled = true\n\n";
printf "$FAIL2BANJAILS" > /etc/fail2ban/jail.local
service fail2ban restart

# Get OWASP rules for ModSecurity
printf $DIVIDER
printf "Downloading OWASP rules for ModSecurity...\n"
wget https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v3.0/master.zip -O /tmp/owasp-modsecurity-crs.zip
unzip /tmp/owasp-modsecurity-crs.zip -d /tmp
rm /tmp/owasp-modsecurity-crs.zip
mv /tmp/owasp-modsecurity-crs-3.0-master/crs-setup.conf.example /etc/modsecurity/crs-setup.conf
mv /tmp/owasp-modsecurity-crs-3.0-master/rules /etc/modsecurity/
rm -r /tmp/owasp-modsecurity-crs-3.0-master

if [ ! -f /etc/apache2/mods-available/security2.conf.orig ]; then
	printf "Backing up original ModSecurity configuration file to /etc/apache2/mods-available/security2.conf.orig\n"
	cp /etc/apache2/mods-available/security2.conf /etc/apache2/mods-available/security2.conf.orig
fi

printf "Adding OWASP rules in ModSecurity configuration...\n"
FIND="<\/IfModule>"
REPLACE="\tIncludeOptional \/etc\/modsecurity\/rules\/\*.conf\n<\/IfModule>"
sed -i "0,/$FIND/s/$FIND/$REPLACE/m" /etc/apache2/mods-available/security2.conf

printf "Installing NodeJS...\n"
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
apt-get install -y nodejs

exit
