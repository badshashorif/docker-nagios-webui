# Nagios Core 4.5.9 + NagiosQL 3.5.0 Dockerfile

FROM debian:bullseye

LABEL maintainer="Shoriful Islam <shoriful@dotinternet.net>"

ENV NAGIOS_VERSION=4.5.9 \
    NAGIOS_PLUGINS_VERSION=2.3.3 \
    NAGIOSQL_VERSION=3.5.0-git2023-06-18 \
    NAGIOS_ADMIN_USER=nagiosadmin \
    NAGIOS_ADMIN_PASS=NagiosAdmin

# Install dependencies + PEAR + SSH2 + timezone fix tools
RUN apt-get update && \
    apt-get install -y apache2 wget php php-gd php-mysql libapache2-mod-php \
                       build-essential libgd-dev unzip curl mariadb-client php-xml php-ldap php-mbstring \
                       vim libmariadb-dev libssl-dev php-pear libssh2-1-dev php-ssh2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set PHP timezone in php.ini
RUN echo 'date.timezone = "Asia/Dhaka"' >> /etc/php/7.4/apache2/php.ini
RUN echo 'date.timezone = "Asia/Dhaka"' >> /etc/php/7.4/cli/php.ini

# Create nagios user and group
RUN useradd nagios && \
    groupadd nagcmd && \
    usermod -a -G nagcmd nagios && \
    usermod -a -G nagcmd www-data

# Download and install Nagios Core
WORKDIR /tmp
RUN wget https://github.com/NagiosEnterprises/nagioscore/releases/download/nagios-${NAGIOS_VERSION}/nagios-${NAGIOS_VERSION}.tar.gz && \
    tar xzf nagios-${NAGIOS_VERSION}.tar.gz && \
    cd nagios-${NAGIOS_VERSION} && \
    ./configure --with-httpd-conf=/etc/apache2/sites-enabled --with-command-group=nagcmd && \
    make all && \
    make install && \
    make install-init && \
    make install-commandmode && \
    make install-config && \
    make install-webconf && \
    cd / && rm -rf /tmp/nagios*

# Install Nagios Plugins
RUN wget https://nagios-plugins.org/download/nagios-plugins-${NAGIOS_PLUGINS_VERSION}.tar.gz && \
    tar zxvf nagios-plugins-${NAGIOS_PLUGINS_VERSION}.tar.gz && \
    cd nagios-plugins-${NAGIOS_PLUGINS_VERSION} && \
    ./configure --with-nagios-user=nagios --with-nagios-group=nagios && \
    make && make install && \
    cd / && rm -rf nagios-plugins*

# Download and install NagiosQL
WORKDIR /var/www/html
RUN wget "https://netix.dl.sourceforge.net/project/nagiosql/nagiosql/NagiosQL%203.5.0/nagiosql-3.5.0-git2023-06-18.tar.gz" && \
    tar xzf "nagiosql-3.5.0-git2023-06-18.tar.gz" && \
    rm -f "nagiosql-3.5.0-git2023-06-18.tar.gz" && \
    rm -rf nagiosql && \
    mv nagiosql-3.5.0 nagiosql && \
    chown -R www-data:www-data /var/www/html/nagiosql && \
    chmod -R 755 /var/www/html/nagiosql

# Apache config tweak
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Set permissions for Nagios
RUN chown -R nagios:nagcmd /usr/local/nagios && \
    chmod -R 755 /usr/local/nagios

# Enable Apache modules
RUN a2enmod cgi rewrite

# Expose port
EXPOSE 80

# Copy entrypoint script and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
