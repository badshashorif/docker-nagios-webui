# Nagios server with web config UI

FROM jasonrivers/nagios:latest
MAINTAINER Mads badshashorif "badshashorif@gmail.com"

## Install packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update -qq
RUN apt-get install -y php5-mysqlnd

# Download NagiosQL
ADD https://netix.dl.sourceforge.net/project/nagiosql/nagiosql/NagiosQL%203.5.0/nagiosql-3.5.0-git2023-06-18.tar.gz /download/nagiosql-3.5.0.tar.gz
WORKDIR /download
RUN tar xvzf nagiosql-3.5.0.tar.gz
WORKDIR /

# Install
RUN mv /download/nagiosql35 /usr/local/nagiosql
ADD nagiosql.conf /etc/apache2/conf-available/nagiosql.conf
RUN a2enconf nagiosql

# Configure
RUN ln -s /usr/local/nagios/etc /etc/nagios
RUN ln -s /usr/local/nagios/var /var/nagios
RUN ln -s /usr/local/nagios /opt/nagios
ADD settings.php /usr/local/nagiosql/config/settings.php
ADD etc /etc/nagiosql
ADD nagioscfg.append /nagioscfg.append
ADD confignagiosql.sh /confignagiosql.sh
RUN /confignagiosql.sh
RUN /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

# Patch PHP's config
RUN sed -e 's/;date.timezone =/date.timezone = Asia/Dhaka' /etc/php5/apache2/php.ini > /tmp.ini
RUN mv /tmp.ini /etc/php5/apache2/php.ini

# Cleanup
RUN rm -rf /download
RUN rm -f /nagioscfg.append
RUN rm -f /confignagiosql.sh
