#!/usr/bin/perl

use strict;
use warnings;

use POE qw(Component::IRC Component::IRC::Plugin::CTCP);
use Module::Reload;
use Symbol qw(delete_package);
use DBI;
use Data::Dumper;

our %networks;
our $dbh;
our $modules = {};

my $quitting = 0;

#sub restart_bot {
#  my $msg = shift || undef;
#  foreach my $network (keys %networks) {
#    quit($network, $msg);
#  }
#  sleep(5); # To allow quit message to send
#  exec($0);
#}

sub reset_pong_alarm {
  $SIG{ALRM} = 'check_connected';
  alarm 30;
}

sub ping_server {
  my $network = shift;

  if($networks{$network}->{cur_server}) {
    yield($network, ping => $networks{$network}->{cur_server});
  }
}

sub reconnect {
  my $network = shift;

  my $irc = get_conn($network);
  $irc->disconnect() if($irc->connected);
  yield($network, connect => { } )
}

sub check_connected {
  my $curtime = time();
  foreach my $network (keys %networks) {
    my $irc = get_conn($network);
    if(!$irc->connected() || $curtime - $networks{$network}->{lastpong} > 300) {
#      restart_bot();
      reconnect($network);
    }
    ping_server($network);
  }
  reset_pong_alarm();
}

sub get_conn {
  my $network = shift;

  return $networks{$network}->{'conn'};
}

sub yield {
  my $network = shift;
  my $irc = get_conn($network);
  $irc->yield(@_);
}

sub irc_command {
  my $network = shift;
  my $foo = shift;
  my @parts = split(/\s+/, $foo);

#  print join(',', @parts) . "\n";
  my $cmd = shift @parts;
  if($cmd eq "/msg") {
    my $to = shift @parts;
    sendmsg($network, $to, join(" ", @parts));
  }
}

sub get_nick {
  my $network = shift;
  my $regex = shift || 0;

  my $mynick = $networks{$network}->{config}->{nick};
  if($regex) {
    $mynick =~ s/\|/\\|/g;
  }

  return $mynick;
}

sub irc_pong {
  my ($kernel,$sender) = @_[KERNEL,SENDER];
  my $network = $sender->get_heap()->session_alias();

  $networks{$network}->{lastpong} = time();
}

sub db_query {
  my $query = shift;
  my @args = @_;

#  print "$query (" . join(", ", @args) . ")\n";
  my $sth = $dbh->prepare($query);
  $sth->execute(@args);
  return $sth;
}

sub auth {
  my $action = shift;
  my $nick = shift;
  my $param = shift || "";

  my $sth = db_query("SELECT * FROM access WHERE nick=?", $nick);
  my $row = $sth->fetchrow_hashref;
  return 0 if(!defined $row);
  my @privs = split(",", $row->{'privs'});
  foreach(@privs) {
    if($action eq $_) {
      return 1;
    }
  }
  return 0;
}

sub sendmsg {
  my $network = shift;
  my $to = shift;
  my $msg = shift;

  my $pos = 0;
  while($pos < length($msg)) {
    yield($network, privmsg => $to => substr($msg, $pos, 300));
    $pos += 300;
  }
  logmsg("SENDMSG $to $msg");
}

sub mode {
  my $network = shift;
  my $target = shift;
  my $arg = shift;
  my $target2 = shift;

  my $irc = get_conn($network);
  if(defined $target2) {
    yield($network, mode => $target => $arg => $target2);
  } else {
    yield($network, mode => $target, $arg);
  }
}

sub op {
  my $network = shift;
  my $channel = shift;
  my $toop = shift || "";

  if(!$toop) {
    sendmsg("chanserv", "op $channel");
    sleep(2);
  } else {
    mode($network, $channel, "+o", $toop);
  }
}

sub deop {
  my $network = shift;
  my $channel = shift;
  my $todeop = shift || get_nick($network);

  mode($network, $channel, "-o", $todeop);
}

sub joinchan {
  my $network = shift;
  my $channel = shift;

  return if($channel !~ /^#/);
  yield($network, 'join' => $channel);
  my $sth = db_query("SELECT * FROM channels WHERE network=? AND name=?", $network, $channel);
  if(!defined $sth->fetchrow_hashref) {
    db_query("INSERT INTO channels VALUES(NULL, ?, ?, '', 'all,-Admin,-GentooInstaller')", $network, $channel);
  }
}

sub partchan {
  my $network = shift;
  my $channel = shift;

  yield($network, 'part' => $channel);
  db_query("DELETE FROM channels WHERE name=?", $channel);
}

sub ctcp {
  my $network = shift;
  my $type = shift;
  my $to = shift;
  my $arg = shift || undef;

  if(defined $arg) {
    yield($network, ctcp => $to => "${type} ${arg}");
  } else {
    yield($network, ctcp => $to => $type);
  }
}

sub quit {
  my $network = shift;
  my $reason = shift;

  $quitting = 1;
  yield($network, quit => $reason);
}

sub kick {
  my $network = shift;
  my $channel = shift;
  my $tokick = shift;
  my $reason = shift;

#  print "Kicking $tokick from $channel for reason '$reason'\n";
  yield($network, kick => $channel => $tokick => $reason);
}

sub nick {
  my $network = shift;
  my $newnick = shift;

  yield($network, nick => $newnick);
}

sub reload_modules {
#  print "Reloading modules\n";
  Module::Reload->check;
}

sub load_module {
  my $newmodule = shift;

  return 0 if($modules->{$newmodule});
  eval "use $newmodule;";
  return 0 if($@);
  my $fname = $newmodule;
  $fname =~ s|::|/|g;
  $fname .= ".pm";
  if(exists $INC{$fname}) {
    $modules->{$newmodule} = 1;
    my $sth = db_query("SELECT * FROM modules WHERE name=?", $newmodule);
    if(!$sth->rows) {
      db_query("INSERT INTO modules VALUES(NULL, ?)", $newmodule);
    }
    return 1;
  } else {
    return 0;
  }
}

sub unload_module {
  my $module = shift;
  my $fname = $module;

  return 0 if(!$modules->{$module});
  $fname =~ s|::|/|g;
  $fname .= ".pm";
  delete_package($module);
  delete $INC{$fname};
  $modules->{$module} = 0;
  db_query("DELETE FROM modules WHERE name=?", $module);

  return 1;
}

sub call_handlers {
  my $func = shift;
  my $network = shift;
  my $channel = shift;

  my $call_modules = {};
  my $sth = db_query("SELECT * FROM channels WHERE network=? AND name=?", $network, $channel);
  my $row = $sth->fetchrow_hashref;
  my @modules = split(",", defined $row->{modules} ? $row->{'modules'} : "");
  foreach my $module (@modules) {
    if($module eq "*" || $module eq "all") {
      foreach my $tmpmodule (keys %{$modules}) {
        $call_modules->{$tmpmodule} = 1 if($modules->{$tmpmodule});
      }
    } elsif($module =~ /[-!](.+)/) {
      $call_modules->{$1} = 0;
    } else {
      $call_modules->{$module} = 1;
    }
  }
  foreach my $module (keys %{$call_modules}) {
    next if(!$call_modules->{$module});
    if(defined "${module}"->can($func)) {
#      print "Calling function '${func}' in module '${module}' with args: \n";
#      print Dumper(@_);
      (\&{$module.'::'.$func})->(@_);
    }
  }
}

sub logmsg {
  my $msg = shift;

#  print "$msg\n";
  print LOGFILE localtime() . " ${msg}\n";
}

# We registered for all events, this will produce some debug info.
sub _default {
  my ($event, $args) = @_[ARG0 .. $#_];
  my @output = ( "$event: " );

  foreach my $arg ( @$args ) {
      if ( ref($arg) eq 'ARRAY' ) {
              push( @output, "[" . join(" ,", @$arg ) . "]" );
      } else {
              push ( @output, "'$arg'" );
      }
  }
  print STDOUT join ' ', @output, "\n";
  return 0;
}

sub _start {
  my ($kernel,$heap) = @_[KERNEL,HEAP];

  my $irc_session = $heap->{irc}->session_id();
  my $network = $heap->{irc}->session_alias();
  $networks{$network}->{session_id} = $irc_session;
  $heap->{irc}->plugin_add( 'CTCP' => POE::Component::IRC::Plugin::CTCP->new( version => $networks{$network}->{config}->{ircname}, userinfo => $networks{$network}->{config}->{ircname} ) );
  $kernel->post( $irc_session => register => 'all' );
  $kernel->post( $irc_session => connect => { } );
}

sub irc_001 {
  my ($kernel,$sender) = @_[KERNEL,SENDER];

  # Get the component's object at any time by accessing the heap of
  # the SENDER
  my $poco_object = $sender->get_heap();
  my $network = $poco_object->session_alias();
  print "Connected to ", $poco_object->server_name(), "\n";
  $networks{$network}->{cur_server} = $poco_object->server_name();
  logmsg("Connected");

  if($networks{$network}->{config}->{identcmd}) {
    irc_command($network, $networks{$network}->{config}->{identcmd});
    sleep(2);
  }
  my $sth = db_query("SELECT * FROM channels WHERE network=? ORDER BY channelid", $network);
  while(my $row = $sth->fetchrow_hashref) {
    joinchan($network, $row->{'name'});
  }
  reset_pong_alarm();
  ping_server($network);
#  check_connected(1);
}

sub irc_433 {
  my ($kernel,$sender,$who,$where,$msg) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2];
  my $network = $sender->get_heap()->session_alias();

  logmsg("Nick taken...ghosting");
  my $sth = db_query("SELECT * FROM misc WHERE name='identify_pass'");
  my $row = $sth->fetchrow_hashref;
  my $mynick = get_nick($network);
  nick($network, $mynick . "_");
  sendmsg($network, "nickserv", "ghost ${mynick} " . $row->{'value'});
  sleep(10);
#  restart_bot();
  reconnect($network);
}

sub irc_public {
  my ($kernel,$sender,$who,$where,$msg) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2];
  my $network = $sender->get_heap()->session_alias();
  my $nick = ( split /!/, $who )[0];
  my $channel = $where->[0];

  logmsg("${network} ${channel} <${nick}> ${msg}") if($msg =~ /\b$networks{$network}->{config}->{nick}\b/);
  call_handlers("on_msg", $network, $channel, $nick, $network, $channel, $msg);
}

sub irc_join {
  my ($kernel,$sender,$who,$channel) = @_[KERNEL,SENDER,ARG0,ARG1];
  my $network = $sender->get_heap()->session_alias();
  my $nick = ( split /!/, $who )[0];
  my $userhost = ( split /@/, $who )[1];

  call_handlers("on_join", $network, $channel, $nick, $userhost, $network, $channel) unless($nick eq $networks{$network}->{'config'}->{nick});
}

sub irc_part {
  my ($kernel,$sender,$who,$channel,$msg) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2];
  my $network = $sender->get_heap()->session_alias();
  my $nick = ( split /!/, $who )[0];

  call_handlers("on_part", $network, $channel, $nick, $network, $channel);
}

sub irc_msg {
  my ($kernel,$sender,$who,$where,$msg) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2];
  my $network = $sender->get_heap()->session_alias();
  my $nick = ( split /!/, $who )[0];
#  my $channel = $where->[0];

  logmsg("*${nick}* $msg");
  if(lc($nick) ne "nickserv" && $nick !~ /\./) {
    call_handlers("on_msg", $network, "/msg", $nick, $network, "/msg", $msg);
  }
}

sub irc_ctcp_action {
  my ($kernel,$sender,$who,$where,$msg) = @_[KERNEL,SENDER,ARG0,ARG1,ARG2];
  my $network = $sender->get_heap()->session_alias();
  my $nick = ( split /!/, $who )[0];
  my $to = $where->[0];

  call_handlers("on_ctcpme", $network, $to, $nick, $network, $to, $msg);
}

sub irc_invite {
  my ($kernel,$sender,$who,$channel) = @_[KERNEL,SENDER,ARG0,ARG1];
  my $network = $sender->get_heap()->session_alias();
  my $nick = ( split /!/, $who )[0];

  sendmsg($network, "agaffney", "I was just invited to ${channel} on ${network} by ${nick}");
  joinchan($network, $channel);
}

# Reconnect to the server when we die.
sub irc_disconnected {
  my ($kernel,$sender,$server) = @_[KERNEL,SENDER,ARG0];
  my $network = $sender->get_heap()->session_alias();

  print "Disconnected from ${network}!\n";
  if(!$quitting) {
    logmsg("Disconnected, attempting to reconnect");
    sleep(3);
#    restart_bot();
    reconnect($network);
  } else {
    exit;
  }
}

open LOGFILE, ">> ircbot.log" or die "Can't open log file";
LOGFILE->autoflush(1);

print "Establishing DB connection...";
$dbh = DBI->connect("dbi:SQLite2:dbname=gibot.db","","", {'RaiseError' => 1});
if(defined $dbh) {
  print "done\n";
} else {
  print "ERROR!\n";
  exit;
}

my $sth = db_query("SELECT * FROM networks");
while(my $row = $sth->fetchrow_hashref) {
  $networks{$row->{name}} = { 'config' => $row, 'channels' => [], 'lastpong' => 0 };
}

$sth = db_query("SELECT * FROM modules ORDER BY moduleid");
while(my $row = $sth->fetchrow_hashref) {
  my $module = $row->{'name'};
  print "Loading module $module...";
  if(load_module($module)) {
    print "done\n";
  } else {
    print "ERROR!\n";
  }
}

foreach my $network (keys %networks) {
  print "Creating connection to network '${network}'...\n";
  # We create a new PoCo-IRC object and component.
  $networks{$network}->{'conn'} = POE::Component::IRC->spawn( 
	nick => $networks{$network}->{config}->{nick},
	server => $networks{$network}->{config}->{host},
	port => $networks{$network}->{config}->{port},
	ircname => $networks{$network}->{config}->{ircname},
	username => $networks{$network}->{config}->{username},
    alias => $network
  ) or die "$0: Cannot spawn IRC connection! $!";

  POE::Session->create(
	package_states => [
		'main' => [ qw(_start irc_001 irc_public irc_pong irc_join irc_part irc_msg irc_433 irc_ctcp_action irc_invite irc_disconnected) ],
	],
	heap => { irc => $networks{$network}->{conn} },
  );
}

$poe_kernel->run();
exit 0;
