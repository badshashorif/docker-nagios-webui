#!/bin/bash
set -e

# Default values
DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-nagiosql}
DB_USER=${DB_USER:-nagiosql}
DB_PASS=${DB_PASS:-nagiosqlpass}
ADMIN_DB_USER=${ADMIN_DB_USER:-root}
ADMIN_DB_PASS=${ADMIN_DB_PASS:-rootpass}
NAGIOS_ADMIN_USER=${NAGIOS_ADMIN_USER:-nagiosadmin}
NAGIOS_ADMIN_PASS=${NAGIOS_ADMIN_PASS:-NagiosAdmin}

# Wait for MariaDB
echo "⏳ Waiting for MariaDB ($DB_HOST:$DB_PORT)..."
until mysqladmin ping -h "$DB_HOST" -P "$DB_PORT" --silent; do
  sleep 2
done
echo "✅ DB connected!"

# Create DB and user
mysql -h "$DB_HOST" -P "$DB_PORT" -u"$ADMIN_DB_USER" -p"$ADMIN_DB_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET utf8;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# Nagios runtime directories
echo "🗂 Preparing Nagios runtime directories..."
mkdir -p /usr/local/nagios/var/rw
mkdir -p /usr/local/nagios/var/spool/checkresults
touch /usr/local/nagios/var/nagios.log
chown -R nagios:nagcmd /usr/local/nagios/var
chmod -R 770 /usr/local/nagios/var
chmod 664 /usr/local/nagios/var/nagios.log

# File and directory permissions
echo "🔐 Fixing permissions for web and NagiosQL files..."
chown -R www-data:www-data /var/www/html/nagiosql
chmod -R 755 /var/www/html/nagiosql
chmod -R 755 /usr/local/nagios/share || true
chown -R www-data:nagcmd /usr/local/nagios || true

echo "🔧 Fixing NagiosQL config write permissions..."
mkdir -p /var/www/html/nagiosql/config
touch /var/www/html/nagiosql/config/settings.php
chown -R www-data:www-data /var/www/html/nagiosql/config
chmod -R 755 /var/www/html/nagiosql/config
chmod 644 /var/www/html/nagiosql/config/settings.php

# Apache fix
grep -q "ServerName localhost" /etc/apache2/apache2.conf || echo "ServerName localhost" >> /etc/apache2/apache2.conf

# htpasswd user for Nagios Core
echo "🔑 Creating Nagios admin htpasswd..."
htpasswd -b -c /usr/local/nagios/etc/htpasswd.users "$NAGIOS_ADMIN_USER" "$NAGIOS_ADMIN_PASS"

# Start Nagios daemon
echo "🚀 Starting Nagios..."
su -s /bin/bash nagios -c "/usr/local/nagios/bin/nagios /usr/local/nagios/etc/nagios.cfg" &

# Start Apache in foreground
echo "🖥 Starting Apache..."
exec apache2ctl -D FOREGROUND
