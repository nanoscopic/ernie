#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Data::Dumper;

my $rnum = $ARGV[0];
my $jsontext = '';
while( my $line = <STDIN> ) {
  chomp $line;
  last if( $line eq '--' );
  $jsontext .= "$line\n";
}

print "$jsontext\n";
my $json = decode_json( $jsontext );
my $name = $json->{'name'};
my $data = $json->{'data'};
my $reduced = reduce_data( $data );

my $tpl = slurp('pie.tpl');

#my $colors = "\\definecolor{color1}{RGB}{255,0,0}
#\\definecolor{color2}{RGB}{0,0,255}
#\\definecolor{inv1}{RGB}{255,255,255}
#\\definecolor{inv2}{RGB}{255,255,255}\n";
my $colors = "";


#my $piedata = "{45/color1,45/color2,45/red,105/orange,120/yellow}
#    \\draw[inv1] (pc 1) node {\\Large\\textbf{14\\\%}};
#    \\draw[inv2] (pc 2) node {\\Large\\textbf{18\\\%}};";
my $piedata = "";

my $colornum = 1;
my $dataline = "{";
my $perclabels = "";
my $i = 1;
for my $item ( @$reduced ) {
  my $colorname;
  if( $item->{'grey'} ) {
    $colorname = "colorgrey";
  }
  else {
    $colorname = "color" . ( $colornum++ );
  }
  
  my $color = $item->{'color'};
  my $ang = $item->{'ang'};
  my $perc = $item->{'perc'};
  $perc =~ s/%/\\%/g;
  $colors .= "\\definecolor{$colorname}{RGB}{".$color->[0].",".$color->[1].",".$color->[2]."}\n";
  $dataline .= "$ang/$colorname,";
  if( !$item->{'grey'} ) {
    my $invc;
    my $colorsum = $color->[0] + $color->[1] + $color->[2];
    if( $colorsum > 170*3 ) {
      $invc = [ 255, 255, 255 ];
    }
    else {
      $invc = [ 0,0,0 ];
    }
    $colors .= "\\definecolor{inv$colorname}{RGB}{".$invc->[0].",".$invc->[1].",".$invc->[2]."}\n";
    $perclabels .= "\\draw[inv$colorname] (pc $i) node {\\Large\\textbf{$perc}};\n";
  }
  $i++;
}
$dataline = substr( $dataline, 0, -1 ) . "}\n";
$piedata = $dataline . $perclabels;

$tpl =~ s/--PIEDATA--/$piedata/;
$tpl =~ s/--COLORS--/$colors/;

my $ofile = "temp/pie-$rnum-$name.tex";
my $pdf = "temp/pie-$rnum-$name.pdf";
my $crop = "temp/pie-$rnum-$name-crop.pdf";
my $png = "../data/images/pie-$rnum-$name.png";
my $log = "temp/pie-$rnum-$name.log";
my $aux = "temp/pie-$rnum-$name.aux";
open( TEXF, ">$ofile" );
print TEXF $tpl;
close( TEXF );

`pdflatex -output-directory temp $ofile`;
#`./pdfcrop.pl --margins 0 $pdf`;
`convert -density 216 -resize 33% -flatten $pdf -trim +repage $png`; # -quality 70 
unlink $ofile;
unlink $pdf;
#unlink $crop;
unlink $log;
unlink $aux;

sub reduce_data {
  my $data = shift;
  
  my $sum = 0;
  for my $item ( @$data ) {
    $sum += $item;
  }
  
  
  my $colors = [
    [128,166,212],
      [253,133,175],
      [255,156,90],
      [101,198,124],
      [90,204,194],
      [84,199,239],
      [255,194,103],
      [255,128,129]
  ];
  my $numcolors = 8;
  my $grey = [ 128, 128, 128 ];
  my $greynum = 0;
  
  my @reduced;
  my $i = 0;
  for my $item ( @$data ) {
    my $perc = $item / $sum;
    if( $perc < 0.10 ) {
      $greynum += $item;
    }
    else {
      my $color;
      if( $i >= $numcolors ) {
        #$color = $grey;
        $greynum += $item;
      }
      else { 
        $color = $colors->[ $i ];
        
        push( @reduced, { color => $color, n => $item } );
        $i++;
      }
      
    }
  }
  if( $greynum ) {
    push( @reduced, { color => $grey, n => $greynum, grey => 1 } );
  }
  
  my $angtot = 0;
  for my $item ( @reduced ) {
    my $n = $item->{'n'};
    #my $perc = ( int( ( $n / $sum ) * 10000 ) / 100 ) . '%';
    my $perc = ( int( ( $n / $sum ) * 100 ) ) . '%';
    $item->{'perc'} = $perc;
    my $ang = int( ( $n / $sum ) * 360 );
    $angtot += $ang;
    if( $item->{'grey'} ) {
      my $left = 360 - $angtot;
      $ang += $left;
      $angtot += $left;
    }
    $item->{'ang'} = $ang;
  }
  my $left = 360 - $angtot;
  if( $left ) {
    $reduced[0]{'ang'} += $left;
  }
  
  #open( X, ">>x" );
  #print X "left: $left\n";
  #print X "tot: $angtot\n";
  #print X Dumper( \@reduced );
  #close( X );
  
  return \@reduced;
}

sub slurp {
  my $file = shift;
  local $/ = undef;
  open my $handle, "<$file";
  my $data = <$handle>;
  close $handle;
  return $data;
}

#sleep( $seconds );
