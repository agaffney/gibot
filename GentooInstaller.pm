package GentooInstaller;

use strict;
use warnings;

sub on_msg {
  my $from = shift;
  my $network = shift;
  my $channel = shift;
  my $arg = shift;
  my $cmd;
  my $mynick = main::get_nick($network, 1);
  my $srcdir = "/home/agaffney/dev/gli";

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
  if($cmd =~ /^\s*n00bkick (.+)$/) {
    if(main::auth("kick", $from, $1)) {
#        main::op("#gentoo-installer");
      main::kick($network, "#gentoo-installer", $1, "read the topic...go to #gentoo");
#        main::deop("#gentoo-installer");
    }
  } elsif($cmd =~ /^\s*voiceme$/) {
#    main::op("#gentoo-installer");
#    if($from !~ /^BenUrban/i) {
      main::mode($network, "#gentoo-installer", "+v $from");
#    }
#      main::deop("#gentoo-installer");
  } elsif($cmd =~ /^\s*${regexextra}mksnap(shot)?\b/) {
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "working...");
    system "cd /home/agaffney/dev/gentoo/svn/gli && svn up &>/dev/null && /home/agaffney/bin/cpsnap &>/dev/null";
    main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "complete...new snapshot up");
  } elsif($cmd =~ /^\s*${regexextra}changelog(?: (.+))?/) {
    my %logs = (main => "${srcdir}/installer/ChangeLog", gtk => "${srcdir}/installer/src/fe/gtk/ChangeLog", dialog => "${srcdir}/installer/src/fe/dialog/Changelog");
    my $whichone = (defined $1) ? $1 : "main";
    my $logfile;
    if(exists $logs{$whichone}) {
      $logfile = $logs{$whichone};
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "that ChangeLog is not available");
      return;
    }
    my $logcontents;
    open LOG, "< $logfile";
    foreach my $line (<LOG>) {
      $logcontents .= $line;
    }
    close LOG;
    $logcontents =~ /\n(  \d+.+?\n)\s*\n/s;
    foreach(split /\n/s, $1) {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), $_);
    }
  } elsif($cmd =~ /(\!+1*){5,}/) {
    if($from ne "agaffney") {
      main::kick($network, "#gentoo-installer", $from, "too much !!!!!1!1!oneoneeleven");
    }
  }
}

sub on_ctcpme {
  my $from = shift;
  my $network = shift;
  my $channel = shift;
  my $arg = shift;
  my $cmd;
  my $mynick = main::get_nick($network, 1);

  if($arg =~ /(\!+1*){5,}/) {
    if($from ne "agaffney") {
      main::kick($network, "#gentoo-installer", $from, "too much !!!!!1!1!oneoneeleven");
    }
  }
}

1;
