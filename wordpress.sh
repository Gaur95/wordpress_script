#!/bin/bash

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run with root privileges. Please use 'sudo' or run as the root user."
    exit 1
fi
# user for input
read -p "Enter the WordPress database name: " DB_NAME
read -p "Enter the WordPress database user: " DB_USER
read -p "Enter the WordPress database password: " DB_PASSWORD
read -p "Enter the WordPress installation directory:(e.g., /var/www/html/akash) " WP_DIR
read -p "Enter the WordPress URL (e.g., http://yourwebsite.com): " WP_URL


# Set a default value for WP_DIR if not provided
if [ -z "$WP_DIR" ]; then
    WP_DIR="/var/www/html/akash"
fi
# Set a default value for WP_URL if not provided
if [-z "$WP_URL"]; then
    WP_URL="http://localhost"
fi

# Update system packages
apt-get update

# Install required packages
apt-get install -y apache2 mysql-server php php-mysql libapache2-mod-php

# Secure MySQL installation
mysql_secure_installation

# Create a MySQL database and user for WordPress
mysql -u root -p <<MYSQL_SCRIPT
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Download and extract WordPress
curl -O https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz -C /var/www/html

# Configure WordPress
cp $WP_DIR/wp-config-sample.php $WP_DIR/wp-config.php
sed -i "s/database_name_here/$DB_NAME/g" $WP_DIR/wp-config.php
sed -i "s/username_here/$DB_USER/g" $WP_DIR/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/g" $WP_DIR/wp-config.php

# Set the correct permissions
chown -R www-data:www-data $WP_DIR
find $WP_DIR -type d -exec chmod 755 {} \;
find $WP_DIR -type f -exec chmod 644 {} \;

# Create an Apache virtual host configuration
cat <<EOF > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $WP_DIR
    ServerName $WP_URL
    <Directory $WP_DIR>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Enable the virtual host and mod_rewrite
a2ensite wordpress
a2enmod rewrite

# Restart Apache
systemctl restart apache2

# Clean up
rm latest.tar.gz

# Done!
echo "WordPress has been successfully installed. You can access it at: $WP_URL"
