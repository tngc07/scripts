#!/bin/bash -e

#In order to run this script, remember to chmod +x script.sh
clear
echo "============================================"
echo "WordPress Install Script by Nicolai"
echo "============================================"
echo " "
echo "Name a new folder to start instalation of WP"
read -e newfolder
mkdir $newfolder
cd $newfolder
echo "Do you need to setup new MySQL database? (y/n)"
read -e setupmysql
if [ "$setupmysql" == y ] ; then
	echo "MySQL Admin User: "
	read -e mysqluser
	echo "MySQL Admin Password: "
	read -s mysqlpass
	echo "MySQL Host (Enter for default 'localhost'): "
	read -e mysqlhost
		mysqlhost=${mysqlhost:-localhost}
fi
echo "WP Database Name: "
read -e dbname
echo "WP Database User: "
read -e dbuser
echo "WP Database Password: "
read -s dbpass
echo "WP Database Table Prefix [numbers, letters, and underscores only] (Enter for default 'wp_'): "
read -e dbtable
	dbtable=${dbtable:-wp_}

echo "Last chance - sure you want to run the install? (y/n)"
read -e run
if [ "$run" == y ] ; then
	if [ "$setupmysql" == y ] ; then
		echo "============================================"
		echo "Setting up the database."
		echo "============================================"
		#login to MySQL, add database, add user and grant permissions
		dbsetup="create database $dbname default character set utf8 collate utf8_unicode_ci;GRANT ALL PRIVILEGES ON $dbname.* TO $dbuser@$mysqlhost IDENTIFIED BY '$dbpass';FLUSH PRIVILEGES;"
		mysql -u $mysqluser -p$mysqlpass -e "$dbsetup"
		if [ $? != "0" ]; then
			echo "============================================"
			echo "[Error]: Database creation failed. Aborting."
			echo "============================================"
			exit 1
		fi
    echo "Database created successfully."
	fi

  echo "============================================"
  echo "Wordpress will now begin installing"
  echo "============================================"
  #download wordpress
  echo 'Downloading...'
  curl -O https://wordpress.org/latest.tar.gz
  #unzip wordpress
  echo "Unpacking... and Moving"
  tar -zxvf latest.tar.gz
  #change dir to wordpress
  cd wordpress
  #copy file to parent dir
  cp -rf . ..
  #move back to parent dir
  cd ..
  #remove files from wordpress folder
  rm -R wordpress
  #create wp config
  echo "Configuring..."
  cp wp-config-sample.php wp-config.php
  #set database details with perl find and replace
  perl -pi -e "s'database_name_here'"$dbname"'g" wp-config.php
  perl -pi -e "s'username_here'"$dbuser"'g" wp-config.php
  perl -pi -e "s'password_here'"$dbpass"'g" wp-config.php
  perl -pi -e "s/\'wp_\'/\'$dbtable\'/g" wp-config.php

  #set WP salts
  perl -i -pe'
    BEGIN {
      @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
      push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
      sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
    }
    s/put your unique phrase here/salt()/ge
  ' wp-config.php

  #create uploads folder and set permissions
  mkdir wp-content/uploads
  chmod 775 wp-content/uploads
  #change owner of all files in current folder to www-data
  chown -R www-data:www-data *

  echo "Cleaning..."
  #remove readme.html
  rm readme.html
  #remove zip file
  rm latest.tar.gz
  #remove bash script if it exists in this dir
  [[ -f "wplemp.sh" ]] && rm "wplemp.sh"
  echo "========================="
  echo "[Success]: Wordpress Installation is complete."
  echo "========================="

  echo "========================="
  echo " CONFIGURE NGINX"
  echo "========================="
  echo "Do you want to configure NGINX? (y/n)"
  read -e setupnginx
  if [ "$setupnginx" == y ] ; then
  	echo "Server name (Same as folder where WP was installed add .com or .mx)"
  	read -e servername
  	cd /etc/nginx/sites-available/
    cat > $servername.conf <<'EOL'
server
EOL
  echo "{
    listen 80;
    server_name $servername ;

    return 301 https://$servername$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $servername www.$servername;

    root /var/www/html/$servername/;
    index index.php;

    # SSL parameters
    #ssl_certificate /etc/letsencrypt/live/$servername/fullchain.pem;
    #ssl_certificate_key /etc/letsencrypt/live/$servername/privkey.pem;
    #ssl_trusted_certificate /etc/letsencrypt/live/$servername/chain.pem;
    #include snippets/ssl.conf;
    #include snippets/letsencrypt.conf;

    # log files
    access_log /var/log/nginx/$servername.access.log;
    error_log /var/log/nginx/$servername.error.log;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.2-fpm.sock;
    }

}" >> $servername.conf
ln -s /etc/nginx/sites-available/$servername.conf /etc/nginx/sites-enabled/
systemctl restart nginx
fi

else
  exit
fi
