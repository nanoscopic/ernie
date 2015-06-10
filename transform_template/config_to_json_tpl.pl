#!/usr/bin/perl -w
use strict;
use Data::Dumper;
use lib '.';
use XML::Bare qw/forcearray xval/;
use lib '../../Template-Bare/lib';
use Template::Bare qw/fill_in_string tpl_to_chunks/;

use JSON::XS;

my $report_type = $ARGV[0];

my ( $ob, $xml ) = XML::Bare->new( file => "../configuration/config_$report_type.xml" );
$xml = $xml->{'xml'};
my $pages = forcearray( $xml->{'page'} );

my $pagearr = [];
my $all = { pages => $pagearr };
for my $page ( @$pages ) {
  my $tpl = xval( $page );
  my $output = tpl_to_chunks( $tpl, { a => 1 }, 'TST' );
  push( @$pagearr, $output );
}

open( my $confj, ">../configuration/config_$report_type.json" );
print $confj JSON::XS->new->utf8->pretty(1)->encode( $all );
close $confj;

sub slurp {
  my $file = shift;
  local $/ = undef;
  open( my $f, "<$file" );
  my $data = <$f>;
  close $f;
  return $data;
}

package TST;

sub table {
  my $tname = shift;
  return "$tname";
}

sub chart {
  my $cname = shift;
  return "$cname";
}

sub num7 {
  return '7';
}

sub li {
  return shift;
}

sub count_distinct {
  return "--not implem--";
}

1;