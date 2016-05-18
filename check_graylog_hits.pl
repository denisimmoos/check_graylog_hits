#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: check_graylog_hits.pl
#
#        USAGE: ./check_graylog_hits.pl  
#
#  DESCRIPTION: nagios/icinga check for graylog
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Denis Immoos (<denisimmoos@gmail.com>)
#    AUTHORREF: Senior Linux System Administrator (LPIC3)
#      VERSION: 1.0
#      CREATED: 11/20/2015 03:21:31 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use Data::Dumper;
use Module::Load;

use lib '/usr/lib64/nagios/plugins/check_graylog_hits/lib';

#===============================================================================
# DEFAULTS 
#===============================================================================

my %Options = ();
$Options{'graylog_ip'} = '10.122.30.40';
$Options{'uri'} = 'http://' . $Options{'graylog_ip'} . ':9200/_search?filter_path=hits.total';
$Options{'lwp_timeout'} = 10;
$Options{'print-options'} = 0;
$Options{'json-default'} = '/usr/lib64/nagios/plugins/check_graylog_hits/templates/default.json';

#===============================================================================
# SYGNALS 
#===============================================================================

# You can get all SIGNALS by:
# perl -e 'foreach (keys %SIG) { print "$_\n" }'
# $SIG{'INT'} = 'DEFAULT';
# $SIG{'INT'} = 'IGNORE';

sub INT_handler {
    my($signal) = @_;
    chomp $signal;
    use Sys::Syslog;
    my $msg = "INT: int($signal)\n";
    print $msg;
    syslog('info',$msg);
    exit(0);
}
$SIG{INT} = 'INT_handler';

sub DIE_handler {
    my($signal) = @_;
    chomp $signal;
    use Sys::Syslog;
    my $msg = "DIE: die($signal)\n";
    syslog('info',$msg);
}
$SIG{__DIE__} = 'DIE_handler';

sub WARN_handler {
    my($signal) = @_;
    chomp $signal;
    use Sys::Syslog;
    my $msg = "WARN: warn($signal)\n";
    syslog('info',$msg);
}
$SIG{__WARN__} = 'WARN_handler';

#===============================================================================
# OPTIONS
#===============================================================================

use Getopt::Long;
Getopt::Long::Configure ("bundling");
GetOptions(\%Options,
	'v',    'verbose', 
	'h',    'help',
	'H:s',  'hostname:s',
	'W:i',  'warning:i',
	'C:i',  'critical:i',
	'M:i',  'minutes:i',
	'J:s',  'json-file:s',
	'print-options',
	'lwp-timeout:i',
);

#===============================================================================
# PARSE OPTIONS
#===============================================================================

my $ParseOptions = 'Graylog::ParseOptions';
load $ParseOptions;
$ParseOptions = $ParseOptions->new();
%Options = $ParseOptions->parse(\%Options);

#===============================================================================
# Datetime
#===============================================================================

use DateTime;

my $dt = DateTime->now();
my $dt_to = $dt->datetime();
$dt_to =~ s/T/\ /g;
$dt_to .= '.0'; # .0 anhängen  da uns millisekunden Pustekuchen sind!
$Options{'to'} = $dt_to;

$dt->add( minutes => -$Options{'minutes'} );
my $dt_from =  $dt->datetime();
$dt_from =~ s/T/\ /g;
$dt_from .= '.0';
$Options{'from'} = $dt_from;

#===============================================================================
# LWP
#===============================================================================

use LWP::UserAgent;
my $lwp = LWP::UserAgent->new;
$lwp->timeout($Options{'lwp-timeout'});
$lwp->env_proxy;

#===============================================================================
# HTTP::Requst
#===============================================================================

use HTTP::Request;
my $req = HTTP::Request->new( 'POST', $Options{'uri'} ); 
my $req_default = HTTP::Request->new( 'POST', $Options{'uri'} ); 
$req->header( 'Content-Type' => 'application/json' ); 
$req_default->header( 'Content-Type' => 'application/json' ); 

#===============================================================================
# JSON
#===============================================================================

# load the .json file into array
use  JSON;
my $json = JSON->new;

open(JSONFILE,$Options{'json-file'}) or die;
my @JSONFILE = <JSONFILE>;
my $json_file = join('',@JSONFILE);
close(JSONFILE);

open(JSONFILE,$Options{'json-default'}) or die;
@JSONFILE = <JSONFILE>;
my $json_default = join('',@JSONFILE);
close(JSONFILE);

# json -> HASH
$json_file = $json->decode($json_file);
$json_default = $json->decode($json_default);

# load json file into hash
my %json_file_hash = %{ $json_file } ;
my %json_default_hash = %{ $json_default } ;
	 
foreach my $outerkey (keys %json_file_hash){
	  &hashValue($json_file_hash{$outerkey});
}

foreach my $outerkey (keys %json_default_hash){
	  &hashValue($json_default_hash{$outerkey});
}

# You got to love recursive functions ;) 
# find and frplace from and to in json file
sub hashValue {

    my $hash = ( shift )[0];
  
	if (ref($hash) eq "HASH") {
	 
	   foreach my $key (keys %$hash){
	     if ( $key eq 'to' ) {
	       # now to to
	       $$hash{$key} = $Options{'to'};
		   #print "to => $$hash{$key}" . "\n";
	     }
         if ( $key eq 'from'  ) {
		   # 1970-01-01 00:00:00.000
		   if ( $$hash{$key} eq 'DEFAULT' ) {
			     $Options{'from'} = '1970-01-01 00:00:00.0';
	             $$hash{$key} = $Options{'from'};
		   } else {
	             # from to now -t
	             $$hash{$key} = $Options{'from'};
		   }
	     }
	     if ( $key eq 'query' and ref($$hash{$key}) ne 'HASH' ) {
		   
		   if ( $$hash{$key} eq 'DEFAULT' ){
             $$hash{$key} = "gl2_remote_ip:$Options{'hostname'}";
			 $Options{'query-default'} = $$hash{$key};
		   } else {
		     # hostname
             $$hash{$key} .= " AND gl2_remote_ip:$Options{'hostname'}";
		     #print "query => $$hash{$key}" . "\n";

		     $Options{'query'} =  $$hash{$key};
           }
	     }
	 
	     &hashValue($$hash{$key});
	  }
	 }
 }

 # manipulated json bachk to json struct
$json_file = $json->encode(\%json_file_hash);

# from the beginning of unix time till the end of the road
$json_default = $json->encode(\%json_default_hash);

#print "json-file => $json_file" . "\n";
$Options{'json-string-default'} = $json_default;
$Options{'json-string'} = $json_file;

# and put it into PAST request
$req->content($json_file);

# open it in lwp browser
my $response = $lwp->request( $req );
	 
if ($response->is_success) {
	 
	 # gfeedback from server
	 $response = $response->decoded_content;
	 
	 # json to -> HASH
	 $response =  $json->decode($response);
	 
	 #print "hits => ${ $response }{'hits'}{'total'}" . "\n";
	 $Options{'hits'} = ${ $response }{'hits'}{'total'};

} else {
	 die $response->status_line;
}

# and put it into PAST request
$req_default->content($json_default);

# open it in lwp browser
$response = $lwp->request( $req_default );
	 
if ($response->is_success) {
	 
	 # gfeedback from server
	 $response = $response->decoded_content;
	 
	 # json to -> HASH
	 $response =  $json->decode($response);
	 
	 #print "hits => ${ $response }{'hits'}{'total'}" . "\n";
	 $Options{'hits-default'} = ${ $response }{'hits'}{'total'};

} else {
	 die $response->status_line;
}

#===============================================================================
# Nagios
#===============================================================================

my %NagiosStatus = (
    OK       => 0,
    WARNING  => 1,
    CRITICAL => 2,
    UNKNOWN  => 3,

    0       => 'OK',
    1       => 'WARNING',
    2       => 'CRITICAL',
    3       => 'UNKNOWN',
);

$Options{'nagios-msg'} = $NagiosStatus{0};
$Options{'nagios-status'} = $NagiosStatus{'OK'};

if ( $Options{'hits'} >= $Options{'warning'}) {
   $Options{'nagios-msg'} = $NagiosStatus{1};
   $Options{'nagios-status'} = $NagiosStatus{'WARNING'};
   $Options{'print-options'} = 1;
} 

if ( $Options{'hits'} >= $Options{'critical'}) {
   $Options{'nagios-msg'} = $NagiosStatus{2};
   $Options{'nagios-status'} = $NagiosStatus{'CRITICAL'};
   $Options{'print-options'} = 1;
} 

if ( not $Options{'hits-default'} ) {
   $Options{'nagios-msg'} = $NagiosStatus{3};
   $Options{'nagios-status'} = $NagiosStatus{'UNKNOWN'};
   $Options{'print-options'} = 2;
} 


print  $Options{'nagios-msg'} . '|hits=' . $Options{'hits'} .  "\n";

if ($Options{'print-options'} == 2 ) {
	print "No data in graylog for $Options{'hostname'}: " . "\n";
	print "Please add the following line to /etc/rsyslog.conf on $Options{'hostname'}" . "\n\n";

	print 'LINE => *.* @' . $Options{'graylog_ip'} . ':514' . "\n\n";

	print 'Options: ' ."\n";
	foreach my $option (keys(%Options)) {
		print "$option => $Options{$option}" . "\n";
	}
}

if ($Options{'print-options'} == 1 ) {
	print "In the last $Options{'minutes'} minutes the following query trigered an alert: " . "\n";
	print "Please check the logs on your graylog server immediately !!!" . "\n\n";

	print "QUERY => $Options{'query'}" . "\n\n";

	print 'Options: ' ."\n";
	foreach my $option (keys(%Options)) {
		print "$option => $Options{$option}" . "\n";
	}
}
# ;) aua aua boom
exit($Options{'nagios-status'});


#===============================================================================
# END
#===============================================================================

__END__


=head1 NAME

check_graylog_hits.pl - nagios/icinga check for graylog hits

=head1 SYNOPSIS

./check_graylog_hits.pl 

=head1 DESCRIPTION

This description does not exist yet, it
was made for the sole purpose of demonstration.

=head1 LICENSE

This is released under the GPL3.

=head1 AUTHOR

Denis Immoos <denisimmoos@gmail.com>,
Senior Linux System Administrator (LPIC3)

