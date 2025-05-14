#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

# Default variables
HOSTNAME="localhost"
USERNAME="admin"
PASSWORD="password123"
EMAIL="test@example.com"
STORAGEACCOUNT=""
CONTAINER=""

# Parse arguments
for i in "$@"; do
  case $i in
    --hostname=*) HOSTNAME="${i#*=}" ;;
    --username=*) USERNAME="${i#*=}" ;;
    --password=*) PASSWORD="${i#*=}" ;;
    --email=*) EMAIL="${i#*=}" ;;
    --storageaccount=*) STORAGEACCOUNT="${i#*=}" ;;
    --container=*) CONTAINER="${i#*=}" ;;
    *) ;;
  esac
done

# Install dependencies
apt-get update && apt-get upgrade -y
apt-get install -y software-properties-common curl unzip nfs-common apache2 mariadb-server certbot python3-certbot-apache

# Add PHP 8.2 repo if not already present
add-apt-repository ppa:ondrej/php -y
apt-get update
apt-get install -y php8.2 php8.2-{cli,common,imap,redis,snmp,xml,zip,mbstring,curl,gd,mysql}

# Secure MariaDB
mysql_secure_installation <<EOF

y
n
y
y
y
EOF

# Create Nextcloud database and user
DBPASSWORD=$(openssl rand -base64 14)
mysql -e "CREATE DATABASE nextcloud;"
mysql -e "CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '$DBPASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Mount Azure NFS storage
mkdir -p /mnt/files
echo "$STORAGEACCOUNT.blob.core.windows.net:/$STORAGEACCOUNT/$CONTAINER /mnt/files nfs defaults,sec=sys,vers=3,nolock,proto=tcp,nofail 0 0" >> /etc/fstab
mount -a

# Download latest Nextcloud
cd /var/www/html
LATEST_VERSION=$(curl -s https://download.nextcloud.com/server/releases/ | grep -oP 'nextcloud-\K[0-9]+\.[0-9]+\.[0-9]+(?=\.zip)' | sort -V | tail -1)
curl -O "https://download.nextcloud.com/server/releases/nextcloud-${LATEST_VERSION}.zip"
unzip "nextcloud-${LATEST_VERSION}.zip"
rm "nextcloud-${LATEST_VERSION}.zip"
chown -R www-data:www-data nextcloud
cd nextcloud

# Install Nextcloud
sudo -u www-data php occ maintenance:install \
  --database "mysql" \
  --database-name "nextcloud" \
  --database-user "nextcloud" \
  --database-pass "$DBPASSWORD" \
  --admin-user "$USERNAME" \
  --admin-pass "$PASSWORD" \
  --data-dir /mnt/files

# Configure trusted domain and URL
CONFIG_FILE=/var/www/html/nextcloud/config/config.php
sed -i "s/'localhost'/'$HOSTNAME'/g" "$CONFIG_FILE"
sed -i "s|'overwrite.cli.url' => '.*'|'overwrite.cli.url' => 'https://$HOSTNAME'|g" "$CONFIG_FILE"

# Configure Apache
cat <<EOF > /etc/apache2/sites-available/nextcloud.conf
<VirtualHost *:80>
    ServerName $HOSTNAME
    DocumentRoot /var/www/html/nextcloud

    <Directory /var/www/html/nextcloud/>
        Require all granted
        Options FollowSymlinks MultiViews
        AllowOverride All
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$HOSTNAME.error.log
    CustomLog \${APACHE_LOG_DIR}/$HOSTNAME.access.log combined
</VirtualHost>
EOF

a2ensite nextcloud.conf
a2enmod rewrite headers env dir mime ssl

# Obtain Let's Encrypt certificate
certbot --apache --non-interactive --agree-tos --redirect -d "$HOSTNAME" -m "$EMAIL"

# Restart Apache
systemctl reload apache2
