#!/usr/bin/perl -w
use strict;
use lib '../../perl-Pg-Helper/lib';
use Pg::Helper;
use Data::Dumper;
use lib '../../perl-XML-Bare/blib/lib';
use lib '../../perl-XML-Bare/blib/arch';
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

my $sql;
if( $dbconf ) {
  my $hostip = xval( $dbconf->{'ip'} );# "127.0.0.1";
  my $user = xval( $dbconf->{'user'} );#"user";
  my $pw = xval( $dbconf->{'pw'} );#"password";
  
  print "Connecting to $hostip with user $user\n";
  $sql = Pg::Helper->new( { host => $hostip, user => $user, password => $pw } );
}

my $xml;

my $sources = forcearray( $pconf->{'source'} );
my %openfiles;
for my $source ( @$sources ) {
  my $ns = xval $source->{'ns'};
  my $name = xval $source->{'name'};
  if( $source->{'table'} ) {
    dumpt( $ns, $name, $report_id );
  }
  elsif( $source->{'query'} ) {
    dump_query( $name, xval( $source->{'query'} ), $source );
  }
  elsif( $source->{'file'} ) {
    dump_file( $name, xval( $source->{'file'} ), xval( $source->{'tag'} ) );
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
  my ( $name, $file, $tag ) = @_;
  my $path = "../configuration/$file";
  if( ! -e $path ) {
    die "Cannot open $path";
  }
  my ( $ob, $xml1 );
  if( $openfiles{ $file } ) {
    $xml1 = $openfiles{ $file };
  }
  else {
    ( $ob, $xml1 ) = XML::Bare->new( file => $path );
    $openfiles{ $file } = $xml1;
  }
  
  if( $tag ) {
    $xml1 = $xml1->{ $tag };
  }
  
  $xml->{ $name } = $xml1;
}


sub dump_query {
  my ( $name, $query, $conf ) = @_;
  
  #<where col='x' val='$report_id'/>
  #<where col='svwp.survey_id'>
  #      <value_source source="xml_surveys" column="survey_id" />
  #    </where>
  my $cwheres = forcearray( $conf->{'where'} );
  my $where = {};
  my $lookup_col = '';
  for my $cwhere ( @$cwheres ) {
    my $col = xval $cwhere->{'col'};
    my $val;
    if( $cwhere->{'val'} ) {
      $val = xval $cwhere->{'val'};
      if( $val eq '$report_id' ) {
        $val = $report_id;
      }
    }
    if( $cwhere->{'value_source'} ) {
      my $src = $cwhere->{'value_source'};
      my $ds = xval $src->{'source'};
      my $ds_col = xval $src->{'column'};
      #print STDERR Dumper( $xml );
      my $xmlrows = forcearray( $xml->{ $ds }{'row'} );
      my %valhash;
      $cwhere->{'valhash'} = \%valhash;
      #print STDERR Dumper( $xmlrows );
      for my $xmlrow ( @$xmlrows ) {
        my $value = xval $xmlrow->{ $ds_col };
        #push( @values, $value );
        $valhash{ $value } ||= [];
        my $arr = $valhash{ $value };
        push( @$arr, $xmlrow );
      }
      if( $src->{'link'} ) {
        $lookup_col = xval( $cwhere->{'colraw'} ) || $col;
      }
      $val = [ keys %valhash ];
    }
    
    $where->{ $col } = $val;
  }
  
  my @cols = split( ',', xval( $conf->{'cols'} ) );
  my $res = $sql->query( 'x', \@cols, $where, query => $query );
  
  my $rows = db_rows_to_xml_hash( $res );
  my $res2 = { row => $rows };
  if( !@$rows ) {
    $res2->{'empty'} = 1;
  }
  
  #print STDERR Dumper( $res2 );
  #exit;
  $xml->{$name} = $res2;
  
  if( $lookup_col && @$rows ) {
    my %lookup;
    for my $row ( @$rows ) {
      my $val = xval $row->{ $lookup_col };
      #print STDERR $val . " - " . Dumper( $row );
      $lookup{ $val } = $row;
    }
    
    for my $cwhere ( @$cwheres ) {
      if( $cwhere->{'value_source'} ) {
        my $src = $cwhere->{'value_source'};
        if( $src->{'link'} ) {
          my $link = xval $src->{'link'};
          my $ds_col = xval $src->{'column'};
          my $valhash = $cwhere->{'valhash'};
          for my $key ( %$valhash ) {
            my $nodeset = $valhash->{ $key };
            my $linked = $lookup{ $key };
            for my $node ( @$nodeset ) {
              $node->{ $link } = $linked;
              #print STDERR Dumper( $src );
              #print STDERR Dumper( $node );
            }
          }
        }
      }
    }
  }
}
sub db_rows_to_xml_hash {
  my $rows = shift;
  my @outrows;
  for my $row ( @$rows ) {
    my $rowx = {};
    for my $col ( keys %$row ) {
      $rowx->{ $col } = { value => $row->{ $col } };
    }
    push( @outrows, $rowx );
  }
  return \@outrows;
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
  my $rows = db_rows_to_xml_hash( $res2 );
  
  my $res3 = { row => $rows };
  if( !$rows ) {
    $res3->{'empty'} = 1;
  }
  $xml->{ $func } = $res3;
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
  my $res3 = { row => \@rows };
  if( !@rows ) {
    $res3->{'empty'} = 1;
  }
  $xml->{ $func } = $res3;
}
#my $res = $sql->query( 'report_run', ['report_id'], { id => $rid }, limit => 1 );