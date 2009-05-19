package Personality;

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
  if($cmd =~ /^\s*${regexextra}ddate\b/) {
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), `ddate`);
  } elsif($cmd =~ /^\s*${regexextra}botsnack\b/) {
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), "yipee!");
  }
}

sub on_ctcpme {
  my $from = shift;
  my $network = shift;
  my $channel = shift;
  my $arg = shift;
  my $cmd;
  my $mynick = main::get_nick($network);

  if($arg =~ /^\s*(kicks|hits|kills|shoots|punches|stabs|hates|slaps|pokes|smacks|beats|bites|rapes)\s+${mynick}\b/) {
    my $sth = main::db_query("SELECT * FROM bad_responses ORDER BY responseid");
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
  } elsif($arg =~ /^\s*(hugs|kisses|pets|loves|pats|comforts|fucks|humps)\s+${mynick}\b/) {
    my $sth = main::db_query("SELECT * FROM good_responses ORDER BY responseid");
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
  }
}

1;
