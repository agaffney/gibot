package Admin;

use warnings;

sub on_msg {
  my $from = shift;
  my $network = shift;
  my $channel = shift;
  my $arg = shift;
  my $cmd;
  my $mynick = main::get_nick($network, 1);

  if($channel eq "/msg") {
    $cmd = $arg;
  } elsif($arg =~ /^\s*${mynick}[,:]\s+(.+)$/i) {
    $cmd = $1;
  } else {
    return;
  }
  if($cmd =~ /^(quit)(?:\s+(.+))?$/) {
    if(main::auth("exit", $from)) {
      main::quit($network, (defined $2 ? $2 : "I guess I'm not wanted"));
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "fsck off");
    }
#  } elsif($cmd =~ /^(restart|reconnect)(?:\s+(.+))?$/) {
#    if(main::auth("exit", $from)) {
#      main::restart_bot((defined $1 ? $1 : "reconnecting"));
#    } else {
#      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "fsck off");
#    }
  } elsif($cmd =~ /^\s*kick (?:(.+?) )?(#.+?) (.+?)(?: (.+))?$/) {
    my $net = defined $1 ? $1 : $network;
    my $kickchan = $2;
    my $tokick = $3;
    if(main::auth("kick", $from, $tokick)) {
#      main::op($kickchan);
      main::kick($net, $kickchan, $tokick, (defined $3) ? $3 : "$from told me to");
#      main::deop($kickchan);
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you're not on my access lists or don't have the proper rights");
    }
  } elsif($cmd =~ /^\s*say (?:(.+?) )?(#.+?) (.+)$/) {
    if(main::auth("say", $from)) {
      my $net = defined $1 ? $1 : $network;
      main::sendmsg($network, $2, $3);
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*\/?me (?:(.+?) )?(#.+?) (.+)$/) {
    if(main::auth("me", $from)) {
      main::ctcp(defined $1 ? $1 : $network, "ACTION", $2, $3);
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*op (?:(.+?) )?(#.+?)(?: (.+))?$/) {
    if(main::auth("admin", $from)) {
      main::op(defined $1 ? $1 : $network, $2, (defined $3 ? $3 : ""));
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*deop (?:(.+?) )?(#.+?)(?: (.+))?$/) {
    if(main::auth("admin", $from)) {
      main::deop(defined $1 ? $1 : $network, $2, (defined $3 ? $3 : ""));
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*mode (?:(.+?) )?(#.+?) (.+)$/) {
    if(main::auth("admin", $from) && defined $2 && defined $3) {
      main::mode(defined $1 ? $1 : $network, "$2", "$3");
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "not enough arguments or no access");
    }
  } elsif($cmd =~ /^\s*reload mod/) {
    if(main::auth("admin", $from)) {
      main::reload_modules();
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "modules reloaded");
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*join channel (?:(.+?) )?(#.+)$/) {
    if(main::auth("admin", $from)) {
      main::joinchan(defined $1 ? $1 : $network, $2);
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*part channel (?:(.+?) )?(#.+)$/) {
    if(main::auth("admin", $from)) {
      main::partchan(defined $1 ? $1 : $network, $2);
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*reconnect(?: (.+))?\s*$/) {
    if(main::auth("admin", $from)) {
      main::reconnect(defined $1 ? $1 : $network);
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*list chan/){
    if(main::auth("admin", $from)) {
      my $sth = main::db_query("SELECT * FROM channels ORDER BY channelid");
      my @channels;
      while(my $row = $sth->fetchrow_hashref) {
        push @channels, $row->{name} if($row->{name} =~ /^#/);
      }
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "currently in channels: " . join(", ", sort @channels));
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*load module (.+?)(?: (.+))?$/) {
    if(main::auth("admin", $from)) {
      if(main::load_module($1, (defined $2 ? $2 : "all"))) {
        main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "module $1 loaded");
      } else {
        main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "module $1 could not be loaded");
      }
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*unload module (.+)$/) {
    if(main::auth("admin", $from)) {
      main::unload_module($1);
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "module $1 unloaded");
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*list modules$/) {
    if(main::auth("admin", $from)) {
      my @tmpmods;
      foreach(sort keys %{$main::modules}) {
        push @tmpmods, $_ if($main::modules->{$_});
      }
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "active modules: " . join(", ", @tmpmods));
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  } elsif($cmd =~ /^\s*set modules\s+(?:(.+?) )?(#.+?)(?:\s+(.+?))?\s*$/) {
    if(main::auth("admin", $from)) {
      if(defined $3) {
        main::db_query("UPDATE channels SET modules=? WHERE network=? AND name=?", $3, defined $1 ? $1 : $network, $2);
        main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "modules updated for channel $1");
      } else {
        my $sth = main::db_query("SELECT modules FROM channels WHERE network=? AND name=?", defined $1 ? $1 : $network, $2);
        my $row = $sth->fetchrow_hashref;
        main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "modules channel $1: " . $row->{modules});
      }
    } else {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "you don't have access to do that");
    }
  }
}

1;
