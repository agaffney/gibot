package Weather;

use strict;
use warnings;

use Weather::Underground;
#use Data::Dumper;

use LWP::Simple qw($ua get);
my $url = 'http://mobile.wunderground.com/cgi-bin/findweather/getForecast?query=';

$ua->timeout(5);
$ua->agent("Gibot v0.1.2.3.4.5.6.7.mustthiscontinue?");

sub get_default_location {
  my $network = shift;
  my $nick = shift;
  my $place = shift || "";

  my $sth = main::db_query("SELECT * FROM weather_aliases WHERE network=? AND nick=? AND alias=? LIMIT 1", $network, $nick, $place);
  my $row = $sth->fetchrow_hashref;
  if(!defined $row) {
    return "";
  }
  return $row->{'realplace'};
}

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
  if($cmd =~ /^\s*${regexextra}weather(?:\s+(.+))?$/) {
    my $place = (defined $1) ? $1 : "";
    my $dbloc = get_default_location($network, $from, $place);
    if(!$place && !$dbloc) {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "there is no saved location for you. please try again with a location");
      return;
    }
    my $realplace = ($dbloc) ? $dbloc : $place;
    my $weather = Weather::Underground->new( place => $realplace, debug => 0);
    my $results;
    if(!defined $weather or !defined ($results = $weather->get_weather())) {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "no results (or too many...blame the Weather::Underground module for not distinguishing between 0 and >1)");
    } else {
      my $result = $results->[0];
      $result->{place} =~ s/^(.+?)\. Elevation/$1/;
      my $output = "$result->{place} at $result->{updated}: [Temp: $result->{fahrenheit} F / $result->{celsius} C $result->{conditions}]" . (defined $result->{windchill_fahrenheit} ? " [Windchill: $result->{windchill_fahrenheit} F / $result->{windchill_celsius} C]" : "") . " [Hum: " . ($result->{humidity} ? "$result->{humidity}%" : "N/A") . "] [Wind: " . ((defined $result->{wind_milesperhour} && $result->{wind_milesperhour} != 0) ? "$result->{wind_direction} $result->{wind_milesperhour} mph / $result->{wind_kilometersperhour} kph" : "Calm") . "]";
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . $output);
      if($place && !$dbloc) {
        main::db_query("DELETE FROM weather_aliases WHERE network=? AND nick=? AND alias=''", $network, $from);
        main::db_query("INSERT INTO weather_aliases VALUES(NULL, ?, ?, '', ?)", $network, $from, $place);
      }
    }
  } elsif($cmd =~ /^\s*${regexextra}forecast(ex)?(?:\s+(.+))?$/) {
    my $ex = $1;
    my $place = (defined $2) ? $2 : "";
    my $dbloc = get_default_location($network, $from, $place);
    if(!$place && !$dbloc) {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "there is no saved location for you. please try again with a location");
      return;
    }
    my $realplace = ($dbloc) ? $dbloc : $place;
    my $document = get($url . $realplace);
    if (!$document || $document !~ /observed at/i) {
      main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "could not retrieve forecast...try being more specific with your location (non-US forecasts don't work right now)");
    } else {
      $document =~ m|Observed at.+?<b>(.+?)</b>|s;
      my $location = $1;
#      print "$location\n";
      $document =~ m|<td align="left">(.+?)</td></tr></table>|s;
      $document = $1;
      my @forecast;
      while($document =~ m|<b>([^<]+?)</b><br />\r?\n<img src=".+?" width="\d+" height="\d+" border="1" alt="" /><br />\r?\n(.+?)\.?\s*<br /><br />|cgs) {
#        print "$1 - $2\n";
        push @forecast, [ $1, $2 ];
      }
      if($forecast[0][0]) {
        if($ex) {
          main::sendmsg($network, $from, "Forecast for ${location}:");
          foreach my $day (@forecast) {
            main::sendmsg($network, $from, "$day->[0] - $day->[1]");
          }
        } else {
          main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "Forecast for ${location}: $forecast[0][0] - $forecast[0][1], $forecast[1][0] - $forecast[1][1]");
        }
      } else {
        main::sendmsg($network, ($channel eq "/msg" ? $from : $channel), ($channel eq "/msg" ? "" : "$from: ") . "sorry, I couldn't retrieve your forecast");
      }
      if($place) {
        main::db_query("DELETE FROM weather_aliases WHERE network=? AND nick=? AND alias=''", $network, $from);
        main::db_query("INSERT INTO weather_aliases VALUES(NULL, ?, ?, '', ?)", $network, $from, $place);
      }
    }
  }
}

1;
