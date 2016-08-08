#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use 5.10.0;
use Data::Dumper;
use CGI::Fast;
use Readonly;
use TwitRSS;

Readonly my $OWN_BASEURL => 'http://twitrss.me/twitter_search_to_rss';

while (my $q = CGI::Fast->new) {
  my @ps = $q->param; 
  my $bad_param=0;
  for(@ps) {
    unless ($_=~/^(fetch|term)$/) {
      err("Bad parameters. Naughty.",404); 
      $bad_param++;
      next;
    }
  } 
  next if $bad_param;

  my $term = $q->param('term') || '#triffidinvasion';

  $term = lc $term;
  if($term =~ '^@') {
    err("That was a user, you called the wrong script. Call me for searches.",404); 
    next;
  }
  $term=~s/(@|\?)//g;

  my $content     = fetch_search_feed($term);
  my @items       = items_from_feed($content);
  my $feed_url    = "$OWN_BASEURL/?term=$term";
  my $feed_title  = "Twitter search feed for: $term.";
  my $twitter_url = "$TWITTER_BASEURL/search?f=tweets&amp;src=typd&amp;q=$term";
  display_feed($feed_url, $feed_title, $twitter_url, @items);
}
