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
apt-get install -y software-properties-common curl unzip nfs-common apache2 mariadb-server certbot python3-certbot-apache redis-server

# Add PHP 8.2 and install extensions
add-apt-repository ppa:ondrej/php -y
apt-get update
apt-get install -y php8.2 php8.2-{cli,common,imap,redis,snmp,xml,zip,mbstring,curl,gd,mysql,apcu,opcache}

# Enable Redis
systemctl enable redis-server
systemctl start redis-server

# Secure MariaDB
mysql_secure_installation <<EOF

y
n
y
y
y
EOF

# Generate DB password
DBPASSWORD=$(openssl rand -base64 14)

# Mount NFS storage
mkdir -p /mnt/files
if ! grep -q "/mnt/files" /etc/fstab; then
  echo "$STORAGEACCOUNT.blob.core.windows.net:/$STORAGEACCOUNT/$CONTAINER /mnt/files nfs defaults,sec=sys,vers=3,nolock,proto=tcp,nofail 0 0" >> /etc/fstab
fi
mount -a

# Download latest Nextcloud
cd /var/www/html
LATEST_VERSION=$(curl -s https://download.nextcloud.com/server/releases/ | grep -oP 'nextcloud-\K[0-9]+\.[0-9]+\.[0-9]+(?=\.zip)' | sort -V | tail -1)
curl -O "https://download.nextcloud.com/server/releases/nextcloud-${LATEST_VERSION}.zip"

# Clean up and extract
rm -rf /var/www/html/nextcloud
unzip "nextcloud-${LATEST_VERSION}.zip" -d /var/www/html/
rm -f "nextcloud-${LATEST_VERSION}.zip"
chown -R www-data:www-data /var/www/html/nextcloud

# Drop and recreate DB/user to avoid install issues
mysql -e "DROP DATABASE IF EXISTS nextcloud;"
mysql -e "DROP USER IF EXISTS 'nextcloud'@'localhost';"
mysql -e "CREATE DATABASE nextcloud;"
mysql -e "CREATE USER 'nextcloud'@'localhost' IDENTIFIED BY '$DBPASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Install Nextcloud
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:install \
  --database "mysql" \
  --database-name "nextcloud" \
  --database-user "nextcloud" \
  --database-pass "$DBPASSWORD" \
  --admin-user "$USERNAME" \
  --admin-pass "$PASSWORD" \
  --data-dir /mnt/files

# Configure config.php
CONFIG_FILE="/var/www/html/nextcloud/config/config.php"
sed -i "s/'localhost'/'$HOSTNAME'/g" "$CONFIG_FILE"
sed -i "s|'overwrite.cli.url' => '.*'|'overwrite.cli.url' => 'https://$HOSTNAME'|g" "$CONFIG_FILE"

# Add caching to config.php
grep -q "memcache.local" "$CONFIG_FILE" || cat <<EOF >> "$CONFIG_FILE"
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' => [
    'host' => '127.0.0.1',
    'port' => 6379,
  ],
EOF

# Apache site config
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

# Enable and configure OPcache
cat <<EOF > /etc/php/8.2/apache2/conf.d/10-opcache.ini
[opcache]
opcache.enable=1
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.memory_consumption=128
opcache.save_comments=1
opcache.revalidate_freq=1
EOF

# Enable APCu for CLI
echo "apc.enable_cli=1" > /etc/php/8.2/mods-available/apcu.ini

# PHP tuning
sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.2/apache2/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 512M/' /etc/php/8.2/apache2/php.ini
sed -i 's/post_max_size = .*/post_max_size = 512M/' /etc/php/8.2/apache2/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php/8.2/apache2/php.ini

# Obtain HTTPS certificate
certbot --apache --non-interactive --agree-tos --redirect -d "$HOSTNAME" -m "$EMAIL"

# Restart services
systemctl reload apache2
systemctl restart redis-server
