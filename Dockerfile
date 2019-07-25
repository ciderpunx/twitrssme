FROM ubuntu:xenial

# Copy all the files into /var/www/twitrssme
# The .gitignore file filters out the ones we don't want
WORKDIR /var/www/twitrssme
COPY . /var/www/twitrssme/

# 1. Install the ubuntu packages
# 2. Enable the apache modules
# 3. Install the required CPAN modules
# 4. Clean up the ubuntu packages we don't need
# 5. Set up the apache conf and logging
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apache2 \
        build-essential \
        cpanminus \
        libapache2-mod-fastcgi \
        libcurl3-dev \
        libxml2-dev \
        zlib1g-dev \
 && a2enmod expires \
 && a2enmod fastcgi \
 && cpanm --installdeps -q -f . \
 && DEBIAN_FRONTEND=noninteractive apt-get remove --auto-remove -y \
        build-essential \
 && DEBIAN_FRONTEND=noninteractive apt-get clean -y \
 && rm -rf /root/.cpanm \
 && mv /var/www/twitrssme/apache.conf \
       /etc/apache2/sites-enabled/000-default.conf \
 && ln -sf /dev/stdout /var/log/apache2/twitrssme.access.log \
 && ln -sf /dev/stdout /var/log/apache2/access.log \
 && ln -sf /dev/stderr /var/log/apache2/twitrssme.error.log \
 && ln -sf /dev/stderr /var/log/apache2/error.log

CMD [ "apachectl", "-D", "FOREGROUND" ]

EXPOSE 80
