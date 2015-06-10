#!/usr/bin/perl -w
use strict;
use XML::Bare qw/forcearray xval/;
use Data::Dumper;
#use Text::Template qw/fill_in_string/;
use lib '../../Template-Bare/lib';
use Template::Bare qw/fill_in_string/;
use JSON::XS;

my $report_type = $ARGV[0];
my $report_run_id = $ARGV[1] || 97;

#my ( $ob1, $conf ) = XML::Bare->new( file => 'simple_config.xml' );
my ( $ob1, $conf ) = XML::Bare->new( file => "../configuration/config_$report_type.xml" );
$conf = $conf->{'xml'};

my %vmap;
my $alldata = read_data();

my $tables = read_table_confs( forcearray( $conf->{'table'} ) );
delete $tables->{'data'};

my $output = {};
my $table_outputs = {};
$output->{'tables'} = $table_outputs;

my $section = "all";

#for my $table ( @$tables ) {
for my $tb_name ( keys %$tables ) {
  if( $section eq $tb_name ) {}
  elsif( $section eq 'all' ) {}
  else { next; }
  #run_table( 'table1' );
  my $tb_out = run_table( $tables->{ $tb_name } );
  #my $tb_name = xval $table->{'name'};
  $table_outputs->{ $tb_name } = $tb_out;
}
open( OUT, ">../data/out_${report_type}_$report_run_id.json" );
print OUT JSON::XS->new->utf8->pretty(1)->encode( $output );
close( OUT );
#print Dumper( $output );

sub read_data {
  #my ( $ob2, $data ) = XML::Bare->simple( file => 'simple_data.xml' );
  
  my ( $ob2, $data ) = XML::Bare->simple( file => "../data/raw_${report_type}_$report_run_id.xml" );
  #$data = $data->{'xml'};
  return $data;
}

sub get_data {
  my ( $name ) = @_;
  return $alldata->{ $name };
}

sub read_table_confs {
  my ( $tables ) = @_;
  my %hash;
  for my $table ( @$tables ) {
    my $name = xval $table->{'name'};
    my $dataset = xval $table->{'ds'};
    $hash{ $name } = $table;
  }
  return \%hash;
}

sub run_table {
  #my ( $tb_name ) = @_;
  #my $table = $tables->{ $tb_name };
  my $table = shift;
  
  my $sources_node = $conf->{'datasources'};
  my $sources = forcearray( $sources_node->{'func'} );
  my %map;
  
  #print Dumper( $sources_node );
  for my $source ( @$sources ) {
    my $sname = xval $source->{'name'};
    my $fn = xval $source->{'func'};
    $map{$sname} = $fn;
    if( $source->{'virtuals'} ) {
      if( !$vmap{ $sname } ) {
        $vmap{$sname} = { done => 0, v => forcearray( $source->{'virtuals'}{'v'} ) };
      }
    }
  }
  #print Dumper( \%map );
  my $odataname = xval $table->{'ds'};
  my $dataname = $map{ $odataname };
  
  #print "Fetching data $dataname\n";
  my $data = get_data( $dataname );
  
  #print Dumper( $data );
  my $rows = forcearray( $data->{'row'} );
  
  #print Dumper( \%vmap );
  #print "o: $odataname\n";
  my $virt = $vmap{ $odataname };
  if( $virt ) {
    process_virtuals( $virt, $rows );
  }
  
  if( $table->{'filter'} ) {
    my $filters = forcearray( $table->{'filter'} );
    for my $filter ( @$filters ) {
      $rows = run_filter( $rows, $filter );
    }
  }
  
  my $group_stack = [];
  my $byname = {};
  my $output = {};
  
  run_type( $output, 'header', $group_stack, $table, $rows, $byname, $table->{'group'} ? 1 : 0 );
  run_type( $output, 'detail', $group_stack, $table, $rows, $byname, $table->{'group'} ? 1 : 0 );
  run_type( $output, 'footer', $group_stack, $table, $rows, $byname, $table->{'group'} ? 1 : 0 );
  
  if( $table->{'chart'} ) {
    pass_chart_options( $table->{'chart'}, $output );
  }
  
  return $output;
}

sub pass_chart_options {
  my ( $chart, $output ) = @_;
  my $type = $chart->{'type'};
  my $o = {
    type => xval( $chart->{'type'} ),
    options => XML::Bare::Object::simplify( $chart->{'options'} )
  };
  if( $chart->{'onDraw'} ) {
    $o->{'onDraw'} = xval( $chart->{'onDraw'} );
  }
  if( $chart->{'jitterLabels'} ) {
    $o->{'jitterLabels'} = 1;
  }
  $output->{'chart'} = $o;
}

sub process_virtuals {
  my ( $virt, $rows ) = @_;
  return if( $virt->{'done'} );
  my $vs = $virt->{'v'};
  my $ctx = {};
  $TPL::ctx = $ctx;
  for my $row ( @$rows ) {
    $ctx->{'row'} = $row;
    for my $v ( @$vs ) {
      my $name = xval $v->{'name'};
      my $tpl = xval $v;
      $row->{ $name } = fill_in_string( $tpl, $ctx, 'TPL', 'virtuals' );
    }
  }
  $virt->{'done'} = 1;
}

sub run_filter {
  my ( $rows, $filter ) = @_;
  my $cond = xval $filter->{'cond'};
  my @res;
  if( $cond =~ m/\{/ ) {
    my $ctx = { rows => $rows };
    $TPL::ctx = $ctx;
    for my $row ( @$rows ) {
      $ctx->{'row'} = $row;
      my $a = fill_in_string( $cond, $ctx, 'TPL' );
      if( ! defined $a ) {
        print "3: ". $Text::Template::ERROR . "--" . $cond . "--";
        exit;
      }
      #print "a:$a\n";
      push( @res, $row ) if( $a );
    }
  }
  else {
    for my $row ( @$rows ) {
      push( @res, $row ) if( $row->{ $cond } );
    }
  }
  return \@res;
}

sub group_data {
  my ( $group, $rows ) = @_;
  #my $rows = forcearray( $data->{'row'} );
  my $by = xval $group->{'by'};
  
  my %hash;
  if( $by =~ m/\{/ ) {
    my $ctx = { rows => $rows } ;
    $TPL::ctx = $ctx;
    
    for my $row ( @$rows ) {
      $ctx->{'row'} = $row;
      my $bydata = fill_in_string( $by, $ctx, 'TPL' );
      if( ! defined $bydata ) {
        print "4: ". $Text::Template::ERROR . "--" . $by . "--";
        exit;
      }
      if( $bydata ) {
        $hash{ $bydata } ||= [];
        my $set = $hash{ $bydata };
        push( @$set, $row );
      }
    }
  }
  else {
    for my $row ( @$rows ) {
      my $bydata = $row->{ $by };
      if( ! defined $bydata ) {
        print "No $by in row\n";
        print "Keys:\n";
        my @keys = sort keys %$row;
        print join("\n", @keys );
      }
      if( $bydata ) {
        $hash{ $bydata } ||= [];
        my $set = $hash{ $bydata };
        push( @$set, $row );
      }
    }
  }
  #print keys %hash;
  #exit;
  #$grouping->{ $gp_name } = \%hash;
  return \%hash;
}

sub run_type {
  my ( $output, $type_name, $group_stack, $table, $rows, $byname, $grouped ) = @_;
  
  my $headers = forcearray( $table->{$type_name} );
  
  run_raw_type( $output, $type_name, $group_stack, $headers, $rows, $byname, $grouped );
  if( $type_name eq 'detail' && $table->{'group'} ) {
    my $groups = forcearray( $table->{'group'} );
    for my $group ( @$groups ) {
      my $by = xval $group->{'by'};
      my $gp_name;
      if( $group->{'name'} ) {
        $gp_name = xval $group->{'name'};
      }
      else {
        $gp_name = $by;
      }
      
      if( $group->{'new_table_per_group'} ) {
        $output->{'use_new_table'} = 1;
      }
      #$group->{'name'} = $gp_name;
      
      $output->{ 'groups'} ||= [];
      my $ogroups = $output->{'groups'};
      
      my $gpsets = [];
      my $gp = { name => $gp_name, sets => $gpsets };
      push( $ogroups, $gp );
      
      my $gprows = group_data( $group, $rows );
      push( @$group_stack, {
        name => $gp_name, # name of the group
        group => $table, # xml configuration of the group
        grouped => $gprows # rows grouped by key specified in the group 'by'
      } );
      
      my $gpheaders = forcearray( $group->{'header'} );
      my $gpfooters = forcearray( $group->{'footer'} );
      
      my @gpkeys = keys %$gprows;
      my @allxys;
      for my $key ( @gpkeys ) {
        my $gpoutput = {};
        push( @$gpsets, $gpoutput );
        
        my $subrows = $gprows->{ $key };
        
        run_raw_type( $gpoutput, 'header', $group_stack, $gpheaders, $subrows, $byname, $grouped );
        
        my $gpdetails = forcearray( $group->{'detail'} );
        
        #run_raw_type( 'details', $gpdetails, $subrows );
        run_type( $gpoutput, 'detail', $group_stack, $group, $subrows, $byname, $grouped );
        
        run_raw_type( $gpoutput, 'footer', $group_stack, $gpfooters, $subrows, $byname, $grouped );
        
        if( $gpoutput->{'xys'} ) {
          push( @allxys, @{ $gpoutput->{'xys'} } );
          delete $gpoutput->{'xys'};
        }
      }
      if( scalar @allxys ) {
        $gp->{'xys'} = \@allxys;
      }
      
      if( @$gpsets && $gpsets->[0]{'sort'} ) {
        my @sorted;
        my $dir = $gpsets->[0]{'sortdir'};
        
        my @cleansets;
        my $j = 0;
        for( my $i=0;$i<scalar @$gpsets; $i++ ) {
          my $item = $gpsets->[ $i ];
          next if( !$item || !%$item );
          $item->{'pi'} = $j;
          $j++;
          push( @cleansets, $item );
        }
        @$gpsets = @cleansets;
        
        #print STDERR Dumper( $gpsets );
        
        if( $dir eq 'asc' ) { @sorted = sort { $a->{'sort'} <=> $b->{'sort'} } @$gpsets; }
        elsif( $dir eq 'desc' ) { @sorted = sort { $b->{'sort'} <=> $a->{'sort'} } @$gpsets; }
        
        if( $gp->{'xys'} ) {
          my @sxys = ();
          
          my $xys = $gp->{'xys'};
          
          #print STDERR Dumper( $xys );
          
          my @cleanxys;
          for( my $i=0;$i<scalar @$xys; $i++ ) {
            my $xy = $xys->[ $i ];
            next if( !$xy );
            push( @cleanxys, $xy );
          }
          @$xys = @cleanxys;
          
          my $numgpsets = scalar( @$gpsets );
          my $numxys = scalar( @$xys );
          #print STDERR "numgpsets: $numgpsets, numxys: $numxys\n";
          
          for( my $i=0;$i<scalar @sorted; $i++ ) {
            my $item = $sorted[ $i ];
            my $n = $xys->[ $item->{'pi'} ];
            #if( $n && ref( $n ) ne 'ARRAY' ) {
              push( @sxys, $n );
              delete $item->{'pi'};
            #}
          }
          
          #print STDERR Dumper( \@sxys );
          
          $gp->{'xys'} = \@sxys;
          #print STDERR Dumper( $gp->{'xys'} );
        }
        
        $gp->{'sets'} = \@sorted;
        for my $item ( @sorted ) {
          delete $item->{'sort'};
          delete $item->{'sortdir'};
        }
      }
      
      pop( @$group_stack );
    }
  }
  
  if( !$grouped ) {
    if( $headers->[0]{'sort'} ) {
      #$print STDERR Dumper( $output );
      my $sort = $output->{'sort'};
      my @s2;
      for( my $i=0;$i<scalar @$sort;$i++ ) {
        my $s = $sort->[ $i ];
        $s2[ $s - 1 ] = $i;
      }
      my $sortdir = $output->{'sortdir'};
      my @newdet;
      my @newxys;
      for my $i ( @s2 ) {
        push( @newdet, $output->{'detail'}[ $i ] );
        push( @newxys, $output->{'xys'}[ $i ] );
      }
      $output->{'detail'} = \@newdet;
      $output->{'xys'} = \@newxys;
    }
  }
}

sub run_raw_type {
  my ( $output, $type_name, $group_stack, $headers, $rows, $byname, $grouped ) = @_;
  
  my $row1 = $rows->[ 0 ];
  my $looprows = [ 0 ];
  if( $type_name eq 'detail' ) { $looprows = $rows; }
  
  my $numrows = scalar @$looprows;
  
  my @sortstack;
  my $sortdir2 = 'asc';
  my @xys;
  for( my $i=0;$i<$numrows;$i++ ) {
    my $looprow = $looprows->[ $i ];
    
    my $ctx = { groups => $group_stack, row => $looprow, i => $i, row1 => $row1, rows => $rows, byname => $byname } ;
    $TPL::ctx = $ctx;
    
    for my $header ( @$headers ) {
      if( $header->{'cond'} ) {
        my $cond = xval $header->{'cond'};
        if( $cond =~ m/\{/ ) {
          $cond = fill_in_string( $cond, $ctx, 'TPL' );
          if( ! defined $cond ) {
            print "2c: ". $Text::Template::ERROR;
            exit;
          }
        }
        else {
          $cond = $row1->{ $cond };
        }
        next if( !$cond );
      }
      if( $header->{'set'} ) { # arbitrary expression to precompute before running through columns
        my $sets = forcearray( $header->{'set'} );
        for my $set ( @$sets ) {
          my $name = xval $set->{'name'};
          my $val = xval( $set ) || '';
          if( $val =~ m/\{/ ) {
            $val = fill_in_string( $val, $ctx, 'TPL' );
            if( ! defined $val ) {
              print "2: ". $Text::Template::ERROR;
              exit;
            }
            #print $val;
          }
          $byname->{ $name } = $val;
        }
      }
      my $ths;
      my $th_td;
      if( $header->{'th'} ) { $ths = forcearray( $header->{'th'} ); $th_td = 'th'; }
      if( $header->{'td'} ) { $ths = forcearray( $header->{'td'} ); $th_td = 'td'; }
      #$out .= "  <tr>\n";
      my $out = '';
      my $sort = '';
      my $sort_dir = 'asc';
      
      my $xy = 0;
      for my $th ( @$ths ) {
        my $val = xval( $th ) || '';
        if( $val =~ m/\{/ ) {
          $val = fill_in_string( $val, $ctx, 'TPL' );
          if( ! defined $val ) {
            print "1: ". $Text::Template::ERROR . "--" . xval( $th ) . "--";
            exit;
          }
        }
        
        if( $th->{'x'} ) {
          $xy ||= {};
          $xy->{'x'} = $val;
        }
        if( $th->{'y'} ) {
          $xy ||= {};
          if( defined $xy->{'y'} ) {
            $xy->{'y'} = [ $xy->{'y'}, $val ];
          }
          else {
            $xy->{'y'} = $val;
          }
        }
        if( $th->{'name'} ) {
          $byname->{ xval( $th->{'name'} ) } = $val;
        }
        my $cs = '';
        if( $th->{'colspan'} ) {
          $cs = " colspan=\"" . xval( $th->{'colspan'} ) . "\"";
        }
        $out .= "    <$th_td$cs>$val</$th_td>\n";
        if( $th->{'sort'} ) {
          $sort = $val;
          $sort_dir = xval( $th->{'sort'} ) || 'desc';
        }
      }
      if( $header->{'sort'} ) {
        my $sortt = xval $header->{'sort'};
        if( $sortt =~ m/\{/ ) {
          $sortt = fill_in_string( $sortt, $ctx, 'TPL' );
          if( ! defined $sortt ) {
            print "st: ". $Text::Template::ERROR;
            exit;
          }
        }
        #print STDERR "$sortt ";
        $sort = $sortt;
        if( $header->{'sort'}{'dir'} ) {
          $sort_dir = xval $header->{'sort'}{'dir'};
        }
      }
      
      if( $xy ) {
        push( @xys, $xy );
      }
      if( $grouped ) {
        if( $sort ) {
          $output->{'sort'} = $sort;
          $output->{'sortdir'} = $sort_dir;
        }
      }
      else {
        push( @sortstack, $sort );
        $sortdir2 = $sort_dir;
      }
      #$out .= "  </tr>\n";
      add_array_item( $output, $type_name, $out );
    }
  }
  if( !$grouped ) {
    $output->{'sortdir'} = $sortdir2;
    $output->{'sort'} = \@sortstack;
  }
  if( scalar @xys ) {
    $output->{'xys'} = \@xys;
  }
  
  #$output->{ $type_name } = $out;
}

sub add_array_item {
  my ( $hash, $name, $item ) = @_;
  $hash->{$name} ||= [];
  my $arr = $hash->{ $name };
  push( @$arr, $item );
}

sub run_details {
  my ( $table, $grouping, $data ) = @_;
}

sub run_footers {
  my ( $table, $grouping, $data ) = @_;
}

package TPL;
use Data::Dumper;
use List::Util qw/min max/;
our $ctx;

sub perc {
  my ( $a, $b ) = @_;
  #print STDERR "a:$a, b:$b\n";
  return "" if ( !$b );
  return "0.0\%" if( !$a ); 
  return "<1.0\%" if( ( $a / $b ) < 0.01 );
  return (int( ( $a / $b ) * 1000)/10)."\%";
}

sub ceil {
  my $num = shift;
  return int( $num );
}

sub group_column {
  my ( $gp, $col, $rows ) = @_;
  my %r;
  for my $row ( @$rows ) {
    $r{ $row->{ $col } } = 1;
  }
  return keys %r;
  # return $col from each $rows ( an array ) -> to do further stuff with
}

sub count_where {
  my ( $gp, $cond, $col ) = @_;
  my $rows = $ctx->{'rows'};
  #if( $cond eq 'immediate_action_required' ) {
  #  print STDERR Dumper( $rows );
  #  print STDERR "\n" . ref( $cond );
  #}
  my %hash;
  my $cnt = 0;
  if( !ref( $cond )) { # eq 'SCALAR' 
    for my $row ( @$rows ) {
      if( $row->{ $cond } ) { $cnt++; }
    }
  }
  else {
  }
  
  return $cnt;
}

sub count_distinct {
  my ( $gp, $col ) = @_;
  my $rows = $ctx->{'rows'};
  my %hash;
  for my $row ( @$rows ) {
    $hash{ $row->{$col} } = 1;
  }
  my $cnt = scalar keys %hash;
  return $cnt;
}

sub count_distinct_where {
  my ( $gp, $cond, $col ) = @_;
  my $rows = $ctx->{'rows'};
  my %hash;
  #my $ref = ref( $cond );
  #print "ref:$ref\n";
  if( !ref( $cond ) ) {
    for my $row ( @$rows ) {
      #print $row->{'times_retreaded'}. "\n";
      if( $row->{ $cond } ) {
        $hash{ $row->{$col} } = 1;
      }
    }
  }
  elsif( ref( $cond ) eq 'CODE' ) {
    for my $row ( @$rows ) {
      my $r = $cond->( $row );
      #print $row->{'times_retreaded'}. " [$r]\n";
      if( $r ) {
        $hash{ $row->{ $col } } = 1;
      }
    }
  }
  #print Dumper( \%hash );
  
  my $cnt = scalar keys %hash;
  return $cnt;
}

sub min_where {
  my ( $gp, $cond, $col ) = @_;
  my $rows = $ctx->{'rows'};
  my $min = 200000;
  #my $ref = ref( $cond );
  #print "ref:$ref\n";
  if( !ref( $cond ) ) {
    for my $row ( @$rows ) {
      #print $row->{'times_retreaded'}. "\n";
      if( $row->{ $cond } ) {
        my $val = $row->{$col};
        if( $val < $min ) { $min = $val; }
      }
    }
  }
  elsif( ref( $cond ) eq 'CODE' ) {
    for my $row ( @$rows ) {
      my $r = $cond->( $row );
      #print $row->{'times_retreaded'}. " [$r]\n";
      if( $r ) {
        my $val = $row->{$col};
        if( $val < $min ) { $min = $val; }
      }
    }
  }
  
  if( $min == 200000 ) { return ''; }
  return $min;
}

sub max_where {
  my ( $gp, $cond, $col ) = @_;
  my $rows = $ctx->{'rows'};
  my $max = 0;
  #my $ref = ref( $cond );
  #print "ref:$ref\n";
  if( !ref( $cond ) ) {
    for my $row ( @$rows ) {
      #print $row->{'times_retreaded'}. "\n";
      if( $row->{ $cond } ) {
        my $val = $row->{$col};
        if( $val > $max ) { $max = $val; }
      }
    }
  }
  elsif( ref( $cond ) eq 'CODE' ) {
    for my $row ( @$rows ) {
      my $r = $cond->( $row );
      #print $row->{'times_retreaded'}. " [$r]\n";
      if( $r ) {
        my $val = $row->{$col};
        if( $val > $max ) { $max = $val; }
      }
    }
  }
  
  if( $max == 0 ) { return ''; }
  return $max;
}

sub sum_where {
  my ( $gp, $cond, $col ) = @_;
  my $rows = $ctx->{'rows'};
  my $tot = 0;
  #my $ref = ref( $cond );
  #print "ref:$ref\n";
  if( !ref( $cond ) ) {
    for my $row ( @$rows ) {
      #print $row->{'times_retreaded'}. "\n";
      if( $row->{ $cond } ) {
        my $val = $row->{$col};
        $tot += $val;
      }
    }
  }
  elsif( ref( $cond ) eq 'CODE' ) {
    for my $row ( @$rows ) {
      my $r = $cond->( $row );
      #print $row->{'times_retreaded'}. " [$r]\n";
      if( $r ) {
        my $val = $row->{$col};
        $tot += $val;
      }
    }
  }
  
  return $tot;
}

sub sum_distinct {
  my ( $gp, $col_distinct, $col ) = @_;
  my $rows = $ctx->{'rows'};
  my %hash;
  #my $ref = ref( $cond );
  #print "ref:$ref\n";
  #if( !ref( $cond ) ) {
    for my $row ( @$rows ) {
      #print $row->{'times_retreaded'}. "\n";
      #if( $row->{ $cond } ) {
        $hash{ $row->{$col_distinct} } = $row;
      #}
    }
  #}
  #elsif( ref( $cond ) eq 'CODE' ) {
  #  for my $row ( @$rows ) {
  #    my $r = $cond->( $row );
  #    if( $r ) {
  #      $hash{ $row->{ $col_distinct } } = $row;
  #    }
  #  }
  #}
  #print Dumper( \%hash );
  my $sum = 0;
  for my $key ( keys %hash ) {
    my $row = $hash{ $key };
    $sum += $row->{ $col };
  }
  return $sum;
}

sub li {
  my $v = shift;
  if( $v =~ m/(\[|\])/ ) {
    $v =~ s/(\[|\])//g;
  }
  return $v;
}

sub lip {
  my ( $s, $p, $n ) = @_;
  if( $n == 1 ) { return $s; }
  return $p;
}

sub sum {
  my ( $gp, $col ) = @_;
  my $sum = 0;
  my $rows = $ctx->{'rows'};
  for my $row ( @$rows ) {
    # col could also be an expression
    my $val = $row->{ $col };
    if( ! defined $val ) {
      print "Cannot find $col in row\n";
      print Dumper( $row );
      return 0;
    }
    $sum += $val || 0;
  }
  return $sum;
}

sub max2 {
  my ( $gp, $col ) = @_;
  my $max = 0;
  my $rows = $ctx->{'rows'};
  for my $row ( @$rows ) {
    # col could also be an expression
    my $val = $row->{ $col };
    if( ! defined $val ) {
      print "Cannot find $col in row\n";
      print Dumper( $row );
      return 0;
    }
    if( $val > $max ) { $max = $val; }
  }
  return $max;
}
