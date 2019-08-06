Installing with NGINX and uWSGI is not quite as straightforward as might seem.  There are some basic things and some important things and they aren't the same.  Sometimes running Apache2 and mod_perl just isn't an option.  This is for Ubuntu 16.04, but other than "apt" and some file locations this will apply broadly.

Assuming that you already have Perl installed you need the following packages:

     apt-get install nginx-full uwsgi-plugin-psgi
     cpanm Plank::Util

To configure uWSGI following convention you will needs some directories:

     mkdir /etc/uwsgi/app-available /etc/uwsgi/app-enabled

(I like to keep my logs close together so):

```
mkdir /var/log/uwsgi/
chown -R www-data.adm /var/log/uwsgi/
```
 
You need to create a uWSGI .ini file in /etc/uwsgi/app-available.  There are several ways of doing this.  Feel free to follow your own methodology.

```
[uwsgi]
plugins = 0:cgi
master = True
logto2 = /var/log/uwsgi/trss.log
socket = /tmp/trss.sock
chown-socket = www-data:www-data
uid = www-data
gid = www-data
processes = 1
threads = 2
cgi = /=/var/www/html/trss
cgi = trss.pl
vacuum = true
```

There are quite a few things here that you don't need to do as I did.  I renamed the `twitter_user_to_rss.pl` script to `trss.pl` because I didn't want to type all of that.  So if you see trss - it is short for `twitter_user_to_rss`.  While testing, you will want to run this from the command line and see the output.  So comment out the `logto2` line until you are ready for it to daemonize (don't use the `"daemonize ="` later as uWSGI is systemd aware and this will cause problems).  The `sock` MUST be in a path that is writtable by `www-data`.  I tried `/var/run/`, but it wouldn't work without lots of permissions changes that I didn't want to make.  Likewise, the perl cgi script must be in a path that `www-data` can read and execute.  The plugins line maps the cgi to the `"0"` modifier rather than 9 and simplifies things for nginx.

Don't forget to link `/etc/uwsgi/app-available/trss.ini` (or whatever you call it) to `/etc/uwsgi/app-enabled/trss.ini`; e.g.

```
ln -s /etc/uwsgi/app-available/trss.ini /etc/uwsgi/app-enabled/trss.ini
```

The Nginx config is really pretty simple (I'm not indenting all of this):

```
server {
     listen 80;
     listen [::]:80;

     listen 443 ssl;
     ssl_certificate         /var/www/html/trss/key.pem;
     ssl_certificate_key     /var/www/html/trss/key.PRIVATE.pem;


     server_name goes.here;
     root /var/www/html/trss;

     error_log /var/log/nginx/trss.adst.org.error.log;
     access_log /var/log/nginx/trss.adst.org.access.log;


     location = /favicon.ico {
          alias  /var/www/html/path/to/favicon.ico;
     }

     location /  {
          include uwsgi_params;
          uwsgi_pass unix:/tmp/trss.sock;
          uwsgi_read_timeout 300;
     }
}
```

I inculded a uwsgi_read_timeout line while troubleshooting other problems.  I left it in because: 1) the pull from twitter can sometimes take a few seconds, 2) nginx is impatient, and 3) I would rather wait then have than have nothing returned.  I put in the favicon.ico link because I was tired of error messages there and it was a quick and easy fix.  Certainly not required.  Be sure to link your nginx vhost config from sites-available to sites-enabled; e.g.

```
ln -s /etc/nginx/sites-available/trss.site /etc/nginx/sites-enabled/trss.site
```

Modifications to twitter_user_to_rss.pl:
This is the MOST important part!!  The rest of the information you can get from pretty much anywhere else.

Change:
```
Readonly my $OWNBASEURL => 'http://twitrss.me/twitter_user_to_rss';
```

to

```
Readonly my $OWNBASEURL => 'https://yourbaseurl/';
```

For the next change, let me explain - uWSGI doens't believe that a CGI script returning Content-type `application/rss+xml` could possibly be valid.  uWSGI also doesn't provide instructive error messages here.  It took running strace on the process to puzzle out what was happening.  If you can run the script properly from the cli (`perl twitter_user_to_rss.pl`) and get the XML output and you can see a very basic perl cgi when accessing it through Nginx, then this is what is happening to you.

basic perl cgi:

```     
#!/usr/bin/perl
print "Content-type: text/html\n\n";
print "<h1>Hello World</h1>\n";
```

Search for "Content-type" and you should land where it looks like this:

```
# now print as an rss feed, with header
print<<ENDHEAD
Content-type: application/rss+xml
Cache-control: public, max-age=$max_age
Access-Control-Allow-Origin: *
<?xml version="1.0" encoding="UTF-8"?>
```

You need to change this to look something like:

```
# now print as an rss feed, with header
#Content-type: application/rss+xml
#Cache-control: public, max-age=$max_age
#Access-Control-Allow-Origin: *
print "Content-Type: text/xhtml\n\n"; # added to make uwsgi happy
print<<ENDHEAD
<?xml version="1.0" encoding="UTF-8"?>
```

You could delete the lines I moved and commented out.  I like to keep informative things around.  Make sure that you add the new `Content-Type` line!  It is what keeps uWSGI convinced that what is being returned is ok. The XML will still validate (the same as it always has).

To create a uWSGI systemd service, using your favorite editor put the following text in /lib/systemd/system/uwsgi.service:   

```
[Unit]
Description=uWSGI service

[Service]
ExecStart=/usr/bin/uwsgi --ini /etc/uwsgi/apps-enabled/trss.ini
Restart=always
KillSignal=SIGQUIT
Type=notify
NotifyAccess=all

[Install]
WantedBy=multi-user.target
```

Don't forget to enable it:

```
systemctl enable uwsgi.service
```

At this point you also want to modify your uWSGI trss.ini to enable logging:

```
logto2 = /path/to/logfile/logfile.name
```

With that all of that and a little knowledge of nginx you should be able to get the awesome scrapper and formatter known as twittrssme running on your own server using uWSGI and NGINX.
