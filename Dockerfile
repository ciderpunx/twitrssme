FROM ubuntu:xenial

# Copy all the files into /var/www/twitrssme
# The .gitignore file filters out the ones we don't want
COPY cpanfile /tmp/

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
 && cpanm --installdeps -q /tmp \
 && DEBIAN_FRONTEND=noninteractive apt-get remove --auto-remove -y \
        build-essential \
 && DEBIAN_FRONTEND=noninteractive apt-get clean -y \
 && rm -rf /root/.cpanm

WORKDIR /var/www/twitrssme
COPY . /var/www/twitrssme/

CMD [ "/var/www/twitrssme/docker/docker-startup.sh" ]

EXPOSE 80
