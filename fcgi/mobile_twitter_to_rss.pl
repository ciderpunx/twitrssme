#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use 5.10.0;
use Data::Dumper;
use DateTime;
use DateTime::Format::Strptime;
use Readonly;
use HTML::TreeBuilder::XPath;
use HTML::TreeBuilder::LibXML;
use HTML::Entities qw(:DEFAULT encode_entities_numeric);
use LWP::ConnCache; 
use LWP::UserAgent;
use LWP::Protocol::Net::Curl;
use CGI::Fast;
use Encode;
use POSIX qw(strftime);

binmode STDOUT, 'utf8';
binmode STDIN, 'utf8';

HTML::TreeBuilder::LibXML->replace_original();

Readonly my $BASEURL    => 'https://mobile.twitter.com';
Readonly my $OWNBASEURL => 'http://twitrss.me/twitter_user_to_rss';
my $browser = LWP::UserAgent->new;
$browser->agent('Mozilla/5.0');# (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36');
$browser->default_header('Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8');
$browser->conn_cache(LWP::ConnCache->new(5));
$browser->timeout(2);

while (my $q = CGI::Fast->new) {
        my @ps = $q->param; 
        my $bad_param=0;
        for(@ps) {
          unless ($_=~/^(fetch|replies|user)$/) {
            err("Bad parameters. Naughty.",404); 
            $bad_param++;
            last;
          }
        } 
        next if $bad_param;

  my $user = $q->param('user') || 'ciderpunx';

  $user = lc $user;
  if($user =~ '^#') {
    err("That was an hashtag, TwitRSS.me only supports users!",404); 
    next;
  }
  $user=~s/(@|\s|\?)//g;
  $user=~s/%40//g;

  my $max_age=3600;

  my $replies = $q->param('replies') || 0;
  if ($replies && lc($replies) ne 'on') {
          err("Bad parameters. Naughty.",404); 
          $bad_param++;
          next;
  }

  my $url = "$BASEURL/$user";
  $url .= "/with_replies" if $replies;

  my $response = $browser->get($url);
  # say Dumper $response;
  unless ($response->is_success) {
    err('Can&#8217;t screenscrape Twitter',404);
    next;
  }
  my $content = $response->content;


  my @items;

  my $tree= HTML::TreeBuilder::XPath->new;
  $tree->parse($content);

  my $feedavatar = $tree->findvalue('//table' . class_contains("profile-details") . '/tr/td' . class_contains("avatar") .'/img/@src');

  # Get capitalization from Twitter page
  my $normalizedName = $tree->findvalue('//div' . class_contains("fullname"));

  my $tweets = $tree->findnodes( '//table' . class_contains('tweet'));

  if ($tweets) {
    for my $tweet (@$tweets) {
      next unless $tweet;
      my $header = $tweet->findnodes('./tr' 
                                     . class_contains("tweet-header") 
                                     )->[0];
      my $bd   = $tweet->findnodes( './tr' 
                                     . class_contains("tweet-container")
                                     . '/td'
                                     . class_contains("tweet-content")
                                     . '/div'
                                     . class_contains("tweet-text")
                                     . '/div'
                                     )->[0];
      my $body = "<![CDATA[" . encode_entities($bd->as_HTML,'^\n\x20-\x25\x27-\x7e"') . "]]>";
      $body=~s{&amp;(\w+);}{&$1;}gi;
      $body=~s{<a}{ <a}gi; # always spaces before a tags
      $body=~s{href="/}{href="https://twitter.com/}gi; # add back in twitter.com to unbreak links to hashtags, users, etc.
      # Fix pic.twitter.com links.
      $body =~ s{href="https://t\.co/[A-Za-z0-9]+">(pic\.twitter\.com/[A-Za-z0-9]+)}{href="https://$1">$1</a>}g;
      $body=~s{<a[^>]+href="https://t.co[^"]+"[^>]+title="([^"]+)"[^>]*>}{ <a href="$1">}gi;      # experimental! stop links going via t.co; if an a has a title use it as the href.
      $body=~s{<a[^>]+title="([^"]+)"[^>]+href="https://t.co[^"]+"[^>]*>}{ <a href="$1">}gi;      # experimental! stop links going via t.co; if an a has a title use it as the href.
      $body=~s{target="_blank"}{}gi;
      $body=~s{</?s[^>]*>}{}gi;
      $body=~s{data-[\w\-]+="[^"]+"}{}gi; # validator doesn't like data-aria markup that we get from twitter
      my $avatar = $header->findvalue('./td' . class_contains("avatar") . "/a/img/\@src"); 
      my $fst_img_a = ""; #$tweet->findnodes( './a' 
      my $fst_img=""; # TODO: There's no easy way to pull media in a single request to the profile page
      my $fullname = $header->findvalue('./td' . class_contains('user-info') . '/a/strong' . class_contains("fullname"));
      my $username = $header->findvalue('./td' . class_contains('user-info') . '/a/div' . class_contains("username"));
      $username =~ s{<[^>]+>}{}g;
      $username =~ s{^\s+}{};
      $username =~ s{\s+$}{};
      my $title = enctxt($bd->as_text);
      $title=~s{&nbsp;}{}gi;
      $title=~s{http}{ http}; # links in title lose space
      my $uri = $BASEURL . $tweet->findvalue('@href');
      # Limitation: actual timestamps not present in the feed, we have to work out the best we can from the approximate versions given.
      my $timestamp = $header->findvalue('./td'
                      . class_contains("timestamp")
                      . '/a')
      ;
      my $dt = DateTime->from_epoch( epoch => time());
      if($timestamp =~ m{^\d+h}) {  # XXh == this number of hours ago
        my $hours_ago = $timestamp;
        $hours_ago =~ s{[^\d]}{}g;
        my $now = time();
        my $then = $now - $hours_ago * 3600;
        $dt = DateTime->from_epoch( epoch => $then);
      }
      elsif($timestamp =~ m{^\d+m}) { # XXm == this num minutes
        my $mins_ago = $timestamp;
        $mins_ago =~ s{[^\d]}{}g;
        my $now = time();
        my $then = $now - $mins_ago * 60;
        $dt = DateTime->from_epoch( epoch => $then);
      }
      elsif($timestamp =~ m{^\d+ \w{3} \d+$}) {
        my $strp = DateTime::Format::Strptime->new(
          pattern => "%d %b %y"
        );
        $dt = $strp->parse_datetime($timestamp);
      }
      else {
        #  We hope that this is XX Mon, now we need to work out which year.
        #  We assume that anything where the month is after the current one must have been last year
        #  In all other cases it will be the current year.
        my $curr_year = $dt->year;
        my $curr_mon  = $dt->month;

        my $strp = DateTime::Format::Strptime->new(
          pattern => "%b %d"
        );
        $dt = $strp->parse_datetime($timestamp);

        unless ($dt) {
          die "dodgy date: '$timestamp'";
        }
        if($dt->month <= $curr_mon) { # month <= current, year is this year
          $dt->set(year => $curr_year);
        }
        else { # year is last year
          $dt->set(year => $curr_year - 1);
        }
      }
      # my $pub_date = strftime("%a, %d %b %Y %H:%M:%S %z", localtime($timestamp));
      my $pub_date = $dt->strftime("%a, %d %b %Y %H:%M:%S %z");

      push @items, {
        username => enctxt($username),
        fullname => enctxt($fullname),
        link => $uri,
        guid => $uri,
        title => $title,
        description => $body,
        timestamp => $timestamp,
        pubDate => $pub_date,
      }
    }
  }
  else {
    $tree->delete; 
    err("Can't gather tweets for that user",404);
    next;
  }
  $tree->delete; 

  # now print as an rss feed, with header
print<<ENDHEAD
Content-type: application/rss+xml
Cache-control: public, max-age=$max_age
Access-Control-Allow-Origin: *

<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" xmlns:georss="http://www.georss.org/georss" xmlns:twitter="http://api.twitter.com" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
  <channel>
    <atom:link href="$OWNBASEURL/?user=$user" rel="self" type="application/rss+xml" /> 
    <title>Twitter Search / $user </title>
    <link>https://twitter.com/$user</link>
    <description>Twitter feed for: $user. Generated by TwitRSS.me</description>
    <language>en-us</language>
    <ttl>40</ttl>
    <image>
        <url>$feedavatar</url>
    </image>
ENDHEAD
;

for (@items) {
  print<<ENDITEM
    <item>
      <title>$_->{title}</title>
      <dc:creator>$_->{fullname} ($_->{username})</dc:creator>
      <description>$_->{description}</description>
      <pubDate>$_->{pubDate}</pubDate>
      <guid>$_->{guid}</guid>
      <link>$_->{link}</link>
      <twitter:source/>
      <twitter:place/>
    </item>
ENDITEM
;
}

print<<ENDRSS
  </channel>
</rss>      
ENDRSS
;
}

sub enctxt {
  my $text=shift;
  encode_entities_numeric(decode_entities($text));
}
sub class_contains {
  my $classname = shift;
  "[contains(concat(' ',normalize-space(\@class),' '),' $classname ')]";
}

sub err {
  my ($msg,$status) = (shift,shift);
  print<<ENDHEAD
Content-type: text/html
Status: $status
Cache-control: max-age=86400
Refresh: 10; url=http://twitrss.me

<html><head></head><body><h2>ERR: $msg</h2><p>Redirecting you back to <a href="http://twitrss.me">TwitRSS.me</a> in a few seconds. You might have spelled the username wrong or something</p></body></html>
ENDHEAD
;
}
