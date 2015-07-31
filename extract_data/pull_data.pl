#!/usr/bin/perl -w
use strict;
use lib '../../perl-Pg-Helper/lib';
use Pg::Helper;
use Data::Dumper;
use XML::Bare qw/xval forcearray/;

my $report_type = $ARGV[0];
my $report_id = $ARGV[1];

my $conf_file = "../configuration/config_$report_type.xml";
if( ! -e $conf_file ) {
  die "File does not exist: $conf_file";
}
my ( $ob, $conf ) = XML::Bare->new( file => $conf_file );
$conf = $conf->{'xml'};
my $pconf = $conf->{'pulldata'};
my $dbconf = $pconf->{'db'};

my $hostip = xval( $dbconf->{'ip'} );# "127.0.0.1";
my $user = xval( $dbconf->{'user'} );#"user";
my $pw = xval( $dbconf->{'pw'} );#"password";

print "Connecting to $hostip with user $user\n";
my $sql = Pg::Helper->new( { host => $hostip, user => $user, password => $pw } );

my $xml;

my $sources = forcearray( $pconf->{'source'} );
for my $source ( @$sources ) {
  my $ns = xval $source->{'ns'};
  my $name = xval $source->{'name'};
  if( $source->{'table'} ) {
    dumpt( $ns, $name, $report_id );
  }
  elsif( $source->{'file'} ) {
    dump_file( $name, xval( $source->{'file'} ) );
  }
  else {
    dumpf( $ns, $name, $report_id );
  }
  #dumpf( 'reporting', 'fn_detail', $report_id );
}

my $rawf = "../data/raw_${report_type}_$report_id.xml";
open( my $f, ">$rawf" ) or die "Cannot open $rawf for writing";
print $f XML::Bare::Object::xml( 0, $xml );
close( $f );

sub dump_file {
  my ( $name, $file ) = @_;
  my $path = "../configuration/$file";
  if( ! -e $path ) {
    die "Cannot open $path";
  }
  my ( $ob, $xml1 ) = XML::Bare->new( file => $path );
  $xml->{ $name } = $xml1;
}

sub dumpt {
  my ( $loc, $func, $param ) = @_;
  print "\n";
  my $res = $sql->query( 'pg_catalog.pg_proc', ['pg_catalog.pg_get_function_result(oid) as a'], { proname => $func }, limit => 1 );
  my $a = $res->{'a'};
  my @qcols;
  if( $a =~ m/^TABLE\((.+)\)$/ ) {
    my $raw = $1;
    my @cols = split(', ', $raw );
    for my $col ( @cols ) {
      if( $col =~ m/^([^ ]+) (.+)$/ ) {
        my $name = $1;
        my $type = $2;
        push( @qcols, $name );
        #print "$name\n";
      }
    }
  }
  
  my $res2 = $sql->query( "$loc.$func($param)", \@qcols, {} );
  #print Dumper( $res2 );
  my @rows;
  for my $row ( @$res2 ) {
    my $rowx = {};
    for my $col ( keys %$row ) {
      $rowx->{ $col } = { value => $row->{ $col } };
    }
    push( @rows, $rowx );
  }
  my $res2 = { row => \@rows };
  if( !@rows ) {
    $res2->{'empty'} = 1;
  }
  $xml->{ $func } = $res2;
}

sub dumpf {
  my ( $loc, $func, $param ) = @_;
  print "\n";
  my $res = $sql->query( 'pg_catalog.pg_proc', ['pg_catalog.pg_get_function_result(oid) as a'], { proname => $func }, limit => 1 );
  
  my $a = $res->{'a'};
  my @qcols;
  if( $a =~ m/^TABLE\((.+)\)$/ ) {
    my $raw = $1;
    my @cols = split(', ', $raw );
    for my $col ( @cols ) {
      if( $col =~ m/^([^ ]+) (.+)$/ ) {
        my $name = $1;
        my $type = $2;
        push( @qcols, $name );
        #print "$name\n";
      }
    }
  }
  
  #return;
  my $res2 = $sql->query( "$loc.$func($param)", \@qcols, {} );
  #print Dumper( $res2 );
  my @rows;
  for my $row ( @$res2 ) {
    my $rowx = {};
    for my $col ( keys %$row ) {
      $rowx->{ $col } = { value => $row->{ $col } };
    }
    push( @rows, $rowx );
  }
  my $res2 = { row => \@rows };
  if( !@rows ) {
    $res2->{'empty'} = 1;
  }
  $xml->{ $func } = $res2;
}
#my $res = $sql->query( 'report_run', ['report_id'], { id => $rid }, limit => 1 );