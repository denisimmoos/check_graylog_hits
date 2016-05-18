package Graylog::ParseOptions;

#===============================================================================
#
#         FILE: ParseOptions.pm
#      PACKAGE: Graylog::ParseOptions
#
#  DESCRIPTION: ParseOptions for Graylog
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Denis Immoos (<denisimmoos@gmail.com>)
#    AUTHORREF: Senior Linux System Administrator (LPIC3)
#      VERSION: 1.0
#      CREATED: 11/22/2015 03:11:47 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;

sub new
{
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
} 

sub error {
	my $caller = shift;
	my $msg = shift || $caller;
	die( "ERROR($caller): $msg" );
}

sub verbose {
	my $caller = shift;
	my $msg = shift || $caller;
	print( "INFO($caller): $msg" . "\n" );
}


sub parse {
	my $self = shift;
	my $ref_Options = shift;
	my %Options = %{ $ref_Options };
	my $caller = (caller(0))[3];


	foreach my $opt (keys(%Options)) {
		next if ( $opt eq 'print-options' );
		&error($caller,'$Options{' . $opt . '} not defined') if not ($Options{$opt}); 
	    &verbose($caller,'$Options{' . $opt . '} defined') if ( $Options{'v'} or $Options{'verbose'} ); 
	}

	#
	# critical,warning,minutes
	#

	if ($Options{'minutes'}) { $Options{'M'} = $Options{'minutes'} };
	if ($Options{'M'}) { $Options{'minutes'} = $Options{'M'} };
	&error($caller,'$Options{minutes} must be defined') if not ( $Options{'M'} or $Options{'minutes'} ); 

	if ($Options{'warning'}) { $Options{'W'} = $Options{'warning'} };
	if ($Options{'W'}) { $Options{'warning'} = $Options{'W'} };
	&error($caller,'$Options{warning} must be defined') if not ( $Options{'W'} or $Options{'warning'} ); 

	if ($Options{'critical'}) { $Options{'C'} = $Options{'critical'} };
	if ($Options{'C'}) { $Options{'critical'} = $Options{'C'} };
	&error($caller,'$Options{critical} must be defined') if not ( $Options{'C'} or $Options{'critical'} ); 

	# gt
	&error($caller,'$Options{critical} must be greater than $Options{warning}') if ( $Options{'warning'} ge $Options{'critical'} ); 

    # 
	# hostname
	#
	&error($caller,'$Options{hostname} must be defined') if not ( $Options{'H'} or $Options{'hostname'} ); 
	if ($Options{'H'}) { $Options{'hostname'} = $Options{'H'} };
	if ($Options{'hostname'}) { $Options{'H'} = $Options{'hostname'} };
	&verbose($caller,'$Options{hostname} = ' . $Options{'hostname'}  ) if ( $Options{'v'} or $Options{'verbose'} ); 

	#
	# json-file
	#
	if ($Options{'J'}) { $Options{'json-file'} = $Options{'J'} };
	if ($Options{'json-file'}) { $Options{'J'} = $Options{'json-file'} };
	&error($caller,'$Options{json-file} not a file') if not ( -f $Options{'json-file'} ); 
	&verbose($caller,'$Options{json-file} = ' . $Options{'json-file'}) if ( $Options{'v'} or $Options{'verbose'} ); 

	return %Options;
}

1;

__END__

=head1 NAME

Graylog::ParseOptions - ParseOptions for Graylog 

=head1 SYNOPSIS

use Graylog::ParseOptions;

my $object = Graylog::ParseOptions->new();

my %HASH = $object->parse(\%HASH);

=head1 DESCRIPTION

This description does not exist yet, it
was made for the sole purpose of demonstration.

=head1 LICENSE

This is released under the GPL3.

=head1 AUTHOR

Denis Immoos - <denisimmoos@gmail.com>,
Senior Linux System Administrator (LPIC3)

=cut


