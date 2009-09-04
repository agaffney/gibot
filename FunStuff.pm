package FunStuff;

use strict;
use warnings;

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
  if($cmd =~ /^\s*${regexextra}random\b/) {
    my $sth = main::db_query("SELECT * FROM random_responses ORDER BY responseid");
    my @responses;
    while(my $row = $sth->fetchrow_hashref) {
      push @responses, $row->{response};
    }
    my $resp = @responses[int(rand $#responses + 1)];
    $resp =~ s/%from%/$from/g;
    if($resp =~ /^\/me (.+)$/) {
      main::ctcp($network, "ACTION", $channel, $1);
    } else {
      main::sendmsg($network, $channel, $resp);
    }
  } elsif($cmd =~ /^\s*${regexextra}fortune\b/) {
    my $fortune = `fortune -n 120 -s`;
    for my $line (split /\n/s, $fortune) {
      chomp $line;
      $line =~ s/\t/    /g;
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), $line);
    }
  } elsif($cmd =~ /^\s*${regexextra}bushism\b/) {
    my $bushism = `fortune dubya`;
    $bushism =~ s/\r?\n/ /sg;
    $bushism =~ s/^"(.+?)".+$/$1/;
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), $bushism);
  } elsif($cmd =~ /^\s*${regexextra}chuckism\b/) {
    my $chuckism = `fortune chucknorris`;
    $chuckism =~ s/\r?\n/ /sg;
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), $chuckism);
  } elsif($cmd =~ /^\s*${regexextra}pizza\b(?:\s+(.+)$)?/) {
    if(defined $1) {
      main::ctcp($network, "ACTION", $channel, "makes ${from} a $1 pizza");
#      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), "What toppings would you like?");
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), "What toppings would you like?");
    }
  } elsif($cmd =~ /^\s*${regexextra}beer\b/) {
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), "${from}: you really shouldn't drink");
  } elsif($cmd =~ /^\s*${regexextra}8ball\s+[a-z]+/i) {
    my $sth = main::db_query("SELECT * FROM eightball_responses ORDER BY responseid");
    my @responses;
    while(my $row = $sth->fetchrow_hashref) {
      push @responses, $row->{response};
    }
#    my $resp = @responses[int(rand $#responses + 1)];
    my $resp = @responses[time() % $#responses];
#    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), $resp);
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . $resp);
  } elsif($cmd =~ /^\s*${regexextra}pirate (.+)/) {
    my $word = $1;
    my $ua = LWP::UserAgent->new(agent => "Mozilla/5.0");
    $ua->timeout(3);
    $ua->default_header('Referrer' => "http://www.talklikeapirateday.com/translate/index.php");
    my $response = $ua->post("http://www.talklikeapirateday.com/translate/index.php", { text => $word, debug => 0});
    if($response->is_success) {
      my $html = $response->content;
      if($html =~ m|<p><b>Pirate Speak:</b></p>(.+?)<br><br>|s) {
        main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . $1);
      } else {
        main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "could not translate to pirate");
      }
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "could not translate to pirate");
      print $response->content;
    }
  } elsif($cmd =~ /^\s*${regexextra}woot\b/) {
    my $ua = LWP::UserAgent->new();
    $ua->timeout(5);
    my @woots = (
      ["Main", "http://www.woot.com/"],
      ["Shirt", "http://shirt.woot.com/"],
      ["Kids", "http://kids.woot.com/"],
      ["Wine", "http://wine.woot.com/"],
    );
    my $msg = "";
    for my $woot (@woots) {
      my $response = $ua->get($woot->[1]);
      if($response->is_success) {
        my $html = $response->content;
        $html =~ /<h2 class="fn">(.+?)<\/h2>.+?<h3 class="price">.+?<span class="amount">(.+?)<\/span>.+?<\/h3>/s;
        if(defined $1 && defined $2) {
          $msg .= ($msg ? " | " : "") . $woot->[0] . ": " . $1 . " - \$" . $2;
        } else {
          $msg .= ($msg ? " | " : "") . $woot->[0] . ": could not retrieve";
        }
      } else {
        $msg .= ($msg ? " | " : "") . $woot->[0] . ": could not retrieve";
      }
    }

    my $response = $ua->get("http://deals.yahoo.com/?name=woot#woot");
    if($response->is_success) {
      my $html = $response->content;
      $html =~ /<h3><a [^>]+>(.+?)<\/a><\/h3><strong class="price"><a [^>]+>(.+?)<\/a><\/strong>/s;
      if(defined $1 && defined $2) {
        $msg .= ($msg ? " | " : "") . "Sellout: " . $1 . " - " . $2;
      } else {
        $msg .= ($msg ? " | " : "") . "Sellout: could not retrieve";
      }
    } else {
      $msg .= ($msg ? " | " : "") . "Sellout: could not retrieve";
    }

    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . $msg);
  }
}

1;
