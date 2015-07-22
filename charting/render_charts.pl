#!/usr/bin/perl -w
use strict;

use JSON::XS;

my $rnum = $ARGV[0];
my $jsontext = slurp( "../data/charts_$rnum.json" );
my $charts = decode_json( $jsontext );

my $json = decode_json( $jsontext );
my @data = ();

for my $name ( sort keys %$json ) {
  my $val = $json->{ $name };
  $val->{ 'name' } = $name;
  push( @data, $val );
}

my $current_proc_count = 0;

while( 1 ) {
  last if( !$current_proc_count && !@data );
  while( $current_proc_count < 8 ) {
    last if( !@data );
    spawn_child( shift @data );
    $current_proc_count++;
    #last;
  }
  my $deadproc = wait();
  #last;
  if( $deadproc == -1 ) {
    next; # no subprocess
  }
  else {
    $current_proc_count--;
  }
}

sub spawn_child {
  my $item = shift;
  my $pid;
  return if( $pid = fork ); # in parent
  #my $res = `perl child.pl $item`;
  #print "$res\n";
  if( !@{$item->{'data'}} ) {
    exit;
  }
  open( X, "|perl child.pl $rnum" );
  my $jsontext = encode_json( $item );
  print X $jsontext, "\n--\n";
  close( X );
  exit;
}

sub slurp {
  my $file = shift;
  local $/ = undef;
  open my $handle, "<$file";
  my $data = <$handle>;
  close $handle;
  return $data;
}