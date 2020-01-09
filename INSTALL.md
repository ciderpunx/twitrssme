Installing TwitRSS.me
=====================

TwitRSS.me is a [FastCGI application](https://en.wikipedia.org/wiki/FastCGI) written in [Perl 5](https://www.perl.org). In order to install it you will need a web server that supports FastCGI, a working installation of Perl and various modules from [the CPAN](http://cpan.org).

Step 0: Set up the server
-------------------------

Hopefully you have  a VPS or something. If not, acquire one. The steps in this tutorial are Debian-specific so it would be easiest to use a Debian server. If you fancy documenting for other platforms then pull requests are very welcome.

Step 1: Install a web server
----------------------------

The main TwitRSS runs on Apache with mod_fcgid. You could use nginx if you wanted. But in this guide we will use Apache.

    sudo aptitude install apache2

Then install the fcgid module.

    sudo aptitude install libapache2-mod-fcgid

Step 2: Get the TwitRSS code
----------------------------

You may need to install git first

    sudo aptitude install git

Then clone the repository into /var/www (or wherever you keep your web documents).

    sudo bash
    cd /var/www
    git clone https://github.com/ciderpunx/twitrssme.git

Step 3: Get CPAN modules
------------------------

Perl is probably installed already, but install it if not.

I use cpanminus to manage Perl dependencies but you may want to use apt, though LWP::Protocol::Net::Curl is not in the Debian repositories. You will also need libcurl3-dev. The required Perl dependencies are listed in cpanfile.

     sudo aptitude install cpanminus libcurl3-dev
     sudo cpanm --installdeps .

Once all is installed you should be able to go in to /var/www/twitrssme/fcgi and run the Perl script thus.

    cd /var/www/twitrssme/fcgi
    perl twitter_user_to_rss.pl

You should then see an RSS of the twitter feed of ciderpunx spew out on to your terminal.

Step 4: Configure the web server
--------------------------------

Now we need to set up Apache to serve TwitRSS. In this tutorial we set up the default host, but proceed similarly for a virtual host.

    vi /etc/apache2/sites-enabled/000-default

Here is a basic config.

    <VirtualHost *:80>
      DocumentRoot /var/www/twitrssme/

      <Directory /var/www/twitrssme/>
         Options +ExecCGI +SymLinksIfOwnerMatch -MultiViews +Includes
         AllowOverride None
         Order allow,deny
         allow from all
      </Directory>

      ScriptAlias /twitter_user_to_rss/ /var/www/twitrssme/fcgi/twitter_user_to_rss.pl.fcgi

      ScriptAlias /twitter_search_to_rss/ /var/www/twitrssme/fcgi/twitter_search_to_rss.pl.fcgi

      <Directory /var/www/twitrssme/fcgi>
            ExpiresActive Off
      </Directory>

      ErrorLog ${APACHE_LOG_DIR}/twitrssme.error.log
      LogLevel warn
      CustomLog ${APACHE_LOG_DIR}/twitrssme.access.log varnish_vhost_combined
    </VirtualHost>

I had to enable the expires module. You may need to enable fastcgi in a similar fashion.

     sudo a2enmod expires

Step 5: Restart the web server
------------------------------

The final step is to restart apache.

    sudo apachectl graceful

You should now be able to see your instance of TwitRSS.me.

Other information
-----------------

On the [TwitRSS.me website](http://twitrss.me) I use Varnish to cache results, and haproxy to deal with https connections. I used to use Pound for the https bit but it struggled with more than 500 connections a second from lots of clients. It is all hosted on Bytemark&#8217;s BigV infrastructure.
