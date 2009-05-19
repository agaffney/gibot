package Calc;

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
  if($cmd =~ /^\s*${regexextra}calc (.+)$/) {
    my $calcstr = $1;
    $calcstr =~ s/'//g;
    my $result = `echo '${calcstr}' | bc`;
    chomp $result;
    $result =~ s/\\\n//gs;
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . $result);
  }
}

1;
