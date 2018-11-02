#!/bin/bash -e

# Set the fetch-from-twitter timeout.
# For docker we'll set a longer default than the usual 2
: "${TWITRSSME_TIMEOUT_SEC:=10}"

# Compute the apache timeouts based on this
DEFAULT_APACHE_TIMEOUT="$(( TWITRSSME_TIMEOUT_SEC + 2 ))"
: "${APACHE_IDLE_TIMEOUT:=$DEFAULT_APACHE_TIMEOUT}"
: "${APACHE_APP_CONN_TIMEOUT:=$DEFAULT_APACHE_TIMEOUT}"

# Export this so the fcgi scripts can see it.
export TWITRSSME_TIMEOUT_SEC

# Create an apache config using the variables defined above.
cat <<END_APACHE_CONF > /etc/apache2/sites-enabled/000-default.conf
<VirtualHost *:80>
  DocumentRoot /var/www/twitrssme/

  <Directory /var/www/twitrssme/>
     Options +ExecCGI +SymLinksIfOwnerMatch -MultiViews +Includes -Indexes
     AllowOverride None
     Order allow,deny
     allow from all
  </Directory>

  FastCgiServer /var/www/twitrssme/fcgi/twitter_user_to_rss.pl -processes 5 -idle-timeout ${APACHE_IDLE_TIMEOUT} -appConnTimeout ${APACHE_APP_CONN_TIMEOUT} -priority 18 -listen-queue-depth 20
  ScriptAlias /twitter_user_to_rss/ /var/www/twitrssme/fcgi/twitter_user_to_rss.pl

  FastCgiServer /var/www/twitrssme/fcgi/twitter_search_to_rss.pl -processes 5 -idle-timeout ${APACHE_IDLE_TIMEOUT} -appConnTimeout ${APACHE_APP_CONN_TIMEOUT} -priority 18 -listen-queue-depth 20
  ScriptAlias /twitter_search_to_rss/ /var/www/twitrssme/fcgi/twitter_search_to_rss.pl

  <Directory /var/www/twitrssme/fcgi>
        SetHandler fastcgi-script
        ExpiresActive Off
  </Directory>

  ErrorLog /dev/stderr
  LogLevel warn
  LogFormat "%h %l %u %t \"%r\" %>s %b" common
  CustomLog /dev/stdout common
</VirtualHost>
END_APACHE_CONF

# Now start apache in foreground mode
exec apachectl -D FOREGROUND
