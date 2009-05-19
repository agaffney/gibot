package Default;

use strict;
use warnings;

sub on_msg {
  my $from = shift;
  my $network = shift;
  my $channel = shift;
  my $arg = shift;
  my $mynick = main::get_nick($network, 1);

  my $tome = 0;
  my $cmd = "";
  if($channel eq "/msg") {
    $cmd = $arg;
    $tome = 1;
  } elsif($arg =~ /^\s*${mynick}[,:]\s+(.+)$/i) {
    $cmd = $1;
    $tome = 1;
  } else {
    $cmd = $arg;
  }

  if($tome && $cmd =~ /^\s*(ping.*)$/i) {
    my $pongstr = $1;
    $pongstr =~ s/ping/pong/ig;
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . $pongstr);
  } elsif(($tome && $cmd =~ /^\s*(hi|hello|cheers|greetings)\b/i) || ($cmd =~ /^\s*(hi|hello|cheers|greetings) ${mynick}/i)) {
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "hello");
  } elsif($cmd =~ /^\s*rh(e{2,60})t\b/) {
    my $rheet = "rh";
    $rheet .= "e"x(length($1)*2); # foreach(1..length($1)*2);
    $rheet .= "t!";
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), $rheet);
  } elsif($from eq "jeeves") {
    if($cmd =~ / needs to grow up$/ || $cmd =~ / would not be so immature$/ || $cmd =~ /^silly \w+$/ || $cmd =~ /^blah \w+$/ || $cmd =~ / don't we all wish we could be as cool as you$/) {
      main::sendmsg($network, $channel, "jeeves needs to remove the stick from his butt");
    } elsif($cmd =~ /^stop (dancing with|chewing on|\w+) (that|my|your|the|this) /) {
      main::sendmsg($network, $channel, "jeeves: that's just uncalled for");
    }
  }
}

1;
