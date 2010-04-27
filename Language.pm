package Language;

use warnings;

require LWP::UserAgent;
use URI::Escape (uri_escape_utf8);

sub on_msg {
  my $from = shift;
  my $network = shift;
  my $channel = shift;
  my $arg = shift;
  my $cmd;
  my $mynick = main::get_nick($network, 1);

  my $tome = 0;
  if($channel eq "/msg") {
    $cmd = $arg;
    $tome = 1;
  } elsif($arg =~ /^\s*${mynick}[,:]\s+(.+)$/i) {
    $cmd = $1;
    $tome = 1;
  } else {
    $cmd = $arg;
  }
  my $regexextra;
  if($tome) {
    $regexextra = "!?";
  } else {
    $regexextra = "!";
  }
  if($cmd =~ /^\s*${regexextra}translate (\w+)(?:\s+|->|\|)(\w+) (.+)$/) {
    my $fromlang = $1;
    my $tolang = $2;
    my $query = $3;
    my $ua = LWP::UserAgent->new(agent => "Mozilla/5.0");
    $ua->timeout(3);
    my $response = $ua->get("http://translate.google.com/#${fromlang}|${tolang}|" . uri_escape_utf8($query));
    if($response->is_success) {
      my $html = $response->content;
#      print $html;
      undef $1;
      $html =~ /<span id="result_box"[^>]*>([^>]+)</s;
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . $1);
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "could not translate");
    }
  } elsif($cmd =~ /^\s*${regexextra}google (.+)$/) {
    my $query = $1;
    $query =~ s/ /+/g;
    my $ua = LWP::UserAgent->new(agent => "Mozilla/5.0");
    $ua->timeout(3);
    $ua->max_redirect(0);
    my $response = $ua->get("http://www.google.com/search?btnI=&q=${query}");
    if($response->is_redirect) {
      my $url = $response->header("Location");
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . $url);
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "could not perform google search");
    }
  } elsif($cmd =~ /^\s*${regexextra}define (\w+)/) {
    my $word = $1;
    my $ua = LWP::UserAgent->new(agent => "Mozilla/5.0");
    $ua->timeout(3);
    my $response = $ua->get("http://www.google.com/search?btnI=&q=define%3A${word}");
    if($response->is_success) {
      my $html = $response->content;
      if($html =~ /\<li\>(.+?)\</s) {
        main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . $1);
      } else {
        main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "definition for '$word' not found");
      }
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "could not get definition of '$word'");
    }
  } elsif($cmd =~ /(\w+)\s*\(sp\??\)/) {
    my $word = $1;
    my $results = `echo ${word} | aspell -a | tail -n 2 | head -n 1`;
    $results =~ s/^&.+?: //;
    chomp $results;
    if($results eq "*") {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "'${word}' appears to be correct");
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "suggestions for '$word': $results");
    }
  }
}

1;
