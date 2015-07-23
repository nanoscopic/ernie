#!/usr/bin/perl -w
use strict;
use XML::Bare qw/forcearray xval/;
use Data::Dumper;
#use Text::Template qw/fill_in_string/;
use lib '../../Template-Bare/lib';
use Template::Bare qw/fill_in_string tpl_to_chunks create_delayed fill_in_delayed/;
use JSON::XS;
use lib '../../HTML-Bare/blib/lib';
use lib '../../HTML-Bare/blib/arch';
use HTML::Bare qw//;
use Carp;

my $report_type = $ARGV[0];
my $report_run_id = $ARGV[1] || 97;

my %vmap;
my $alldata;
my %map;

my ( $ob1, $conf ) = XML::Bare->new( file => "../configuration/config_$report_type.xml" );
$conf = $conf->{'xml'};

my %backend_charts;
my $mapped_data = transform_data();
config_to_json_tpl( $mapped_data );
write_backend_charts();

sub write_backend_charts {
  open( OUTC, ">../data/charts_$report_run_id.json" );
  print OUTC JSON::XS->new->utf8->pretty(1)->encode( \%backend_charts );
  close( OUTC );
}

sub transform_data {
  #my ( $ob1, $conf ) = XML::Bare->new( file => 'simple_config.xml' );
  
  $alldata = read_data();
  
  my $tables = read_table_confs( forcearray( $conf->{'table'} ) );
  delete $tables->{'data'};
  
  my $output = {};
  my $table_outputs = {};
  $output->{'tables'} = $table_outputs;
  
  my $section = "all";
  
  sources_to_maps(); # creates %map and %vmap
  my $mapped_data = map_to_mapped();
  
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
  
  if( $conf->{'json'} ) {
    my $json_tpl = XML::Bare::Object::simplify( $conf->{'json'} );
    my $ctx = { data => $mapped_data, report_id => $report_run_id };
    $TPL::ctx = $ctx;
    recurse_fill( $json_tpl, $ctx );
    $output->{'json'} = $json_tpl;
  }
  
  open( OUT, ">../data/out_$report_run_id.json" );
  print OUT JSON::XS->new->utf8->pretty(1)->encode( $output );
  close( OUT );
  #print Dumper( $output );
  
  return $mapped_data;
}

sub recurse_fill {
  my ( $node, $ctx ) = @_;
  
  #print STDERR Dumper( $node );
  
  if( !ref( $node ) ) {
    my $val = $node;
    if( $val =~ m/\{/ ) {
      my $a = fill_in_string( $val, $ctx, 'TPL' );
      if( ! defined $a ) {
        print "rf: ". $Text::Template::ERROR . "--" . $val . "--";
        exit;
      }
      $val = $a;
    }
    return $val;
  }
  
  my $ref = ref( $node );
  if( $ref eq 'HASH' ) {
    for my $key ( keys %$node ) {
      my $sub = $node->{ $key };
      my $val = recurse_fill( $sub, $ctx );
      $node->{ $key } = $val;
    }
    return $node;
  }
  die "error";
}

# Use the map of named tables ( %map ) to generate a hash '%mapped' from names to datasets
sub map_to_mapped {
  my %mapped;
  for my $key ( keys %map ) {
    #print "Key: $key\n";
    my $dest = $map{ $key };
    
    my $node = $alldata->{ $dest };
    if( ref( $node ) && $node->{'row'} ) {
      my $row = $node->{'row'};
      if( ref( $row ) eq 'HASH' ) {
        $row = [ $row ];
      }
      $mapped{ $key } = $row;
    }
    else {
      $mapped{ $key } = [];
    }
  }
  return \%mapped;
}

sub config_to_json_tpl {
  my ( $mapped_data ) = @_;
  
  my $pages = forcearray( $conf->{'page'} );
  
  #print Dumper( $mapped{ 'survey_info' } );
  #exit;
    
  my $ctx = { data => $mapped_data, report_id => $report_run_id };
  $TPL::ctx = $ctx;
  
  my $pagearr = [];
  my $all = { pages => $pagearr };
  for my $page ( @$pages ) {
    my $tpl = xval( $page );
    #print "Running page: " . substr( $tpl, 0, 50 ) . "\n\n";
    my $chunks = tpl_to_chunks( $tpl, $ctx, 'TPL' );
    $chunks = combine_fragments( $chunks );
    push( @$pagearr, $chunks );
  }
  
  #print "Pages have been run\n";
  
  my $file = "../data/config_$report_run_id.json";
  unlink $file;
  open( my $confj, ">$file" ) or die "Cannot open $file";
  print $confj JSON::XS->new->utf8->pretty(1)->encode( $all );
  close $confj;
}

sub combine_fragments {
  my $in = shift;
  my @out;
  my $curchunk = 0;
  my $append = 0;
  for my $chunk ( @$in ) {
    my $type = $chunk->[ 0 ];
    if( !$type && !$chunk->[ 1 ] ) { next; }
    
    if( !$curchunk ) {
      if( !$type ) {
        if( html_complete( $chunk->[1] ) ) {
          push( @out, $chunk );
          next;
        }
        else {
          $curchunk = [ 2, [ $chunk ] ];
          $append = 1;
          next;
        }
      }
      else {
        push( @out, $chunk );
        next;
      }
    }
    # we have a multi part chunk
    my $parts = $curchunk->[1];
    my $numparts = scalar @$parts;
    my $lastpart = $parts->[ $numparts - 1 ];
    my $lasttype = $lastpart->[0];
    
    if( !$lasttype ) { # currently working on an html chunk
      if( !$type ) { # got an html chunk
        if( $append ) {
          $lastpart->[ 1 ] .= $chunk->[ 1 ];
        }
        else {
          push( @$parts, $chunk );
        }
      }
      else {
        push( @$parts, $chunk );
      }
    }
    else { # currently have non html chunk
      push( @$parts, $chunk );
    }
    
    my @htmlchunks;
    $numparts = scalar @$parts;
    for( my $i=0;$i<$numparts;$i++ ) {
      my $part = $parts->[ $i ];
      if( !$part->[0] ) { push( @htmlchunks, $part ); }
    }
    #print STDERR Dumper( \@htmlchunks );
    my $res = chunks_complete( \@htmlchunks );
    #print STDERR Dumper( $res );
    if( $res->{'complete'} ) {
      if( $numparts == 1 ) {
        push( @out, $curchunk->[1][0] );
        $curchunk = 0;
        next;
      }
      else {
        if( $res->{'more'} ) {
          #my $last = pop @htmlchunks;
          #push( @htmlchunks, [ 0, $res->{'parsed'} ] );
          my $last = pop @{$curchunk->[1]};
          push( @{$curchunk->[1]}, [ 0, $res->{'parsed'} ] );
          push( @out, $curchunk );
          
          #print STDERR Dumper( $curchunk );
          if( html_complete( $res->{'more'} ) ) {
            push( @out, [ 0, $res->{'more'} ] );
            $curchunk = 0;
            next;
          }
          else {
            $curchunk = [ 2, [ [ 0, $res->{'more'} ] ] ];
            $append = 1;
            next;
          }
        }
        else {
          push( @out, $curchunk );
        }
      }
      $curchunk = 0;
    }
  }
  return \@out;
}

sub chunks_complete {
  my $chunks = shift;
  
  #print Dumper( $chunks );
  
  my $txt = '';
  my $len = scalar @$chunks;
  if( $len == 1 ) {
    return {
      complete => html_complete( $chunks->[0][1] )
    }
  }
  $len--;
  #for my $chunk ( @$chunks ) {
  for( my $i=0;$i<$len;$i++ ) {
    my $chunk = $chunks->[$i];
    $txt .= $chunk->[1];
  }
  my $lasthtml = $chunks->[ $len ][1];
  my ( $ob, $html ) = HTML::Bare->new( text => $txt );
  $ob->stop_outside();
  $ob->read_more( text => $lasthtml );
  my $len1 = length( $lasthtml );
  my $res = $ob->get_parse_position();
  if( $res->{'depth'} ) { return { complete => 0 }; }
  my $pos = $res->{'position'};
  if( $len1 == $pos ) {
    return { complete => 1, more => 0 };
  }
  my $left = substr( $lasthtml, $pos );
  my $parsed = substr( $lasthtml, 0, $pos );
  return { complete => 1, more => $left, parsed => $parsed };
}

sub html_complete {
  my $txt = shift;
  return 1 if( !$txt );
  #print STDERR "HTML: $html\n";
  my ( $ob, $html ) = HTML::Bare->new( text => $txt);
  my $res = $ob->get_parse_position();
  return !$res->{'depth'};
}

sub read_data {
  #my ( $ob2, $data ) = XML::Bare->simple( file => 'simple_data.xml' );
  
  my ( $ob2, $data ) = XML::Bare->simple( file => "../data/raw_${report_type}_$report_run_id.xml" );
  #$data = $data->{'xml'};
  return $data;
}

sub get_data {
  my ( $name ) = @_;
  if( !$alldata->{ $name } ) {
    confess "Cannot get data for $name\n";
  }
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

# reads datasources from configuration and created %map and %vmap
sub sources_to_maps {
  my $sources_node = $conf->{'datasources'};
  my $sources = forcearray( $sources_node->{'func'} );
  
  
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
}

sub run_table {
  #my ( $tb_name ) = @_;
  #my $table = $tables->{ $tb_name };
  my $table = shift;
  
  #print Dumper( \%map );
  my $odataname = xval $table->{'ds'};
  my $dataname = $map{ $odataname };
  if( !$dataname ) {
    print STDERR "No mapping for data '$odataname'\n";
    return '';
  }
  
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
    my $charts = forcearray( $table->{'chart'} );
    my @chart_data_blocks;
    for my $chart ( @$charts ) {
      my $chartdata = pass_chart_options( $chart );
      push( @chart_data_blocks, $chartdata );
    }
    $output->{'chart'} = \@chart_data_blocks;
    find_backend_charts( xval( $table->{'name'} ), $output->{'chart'}, find_xys( $output ) );
  }
  
  if( $table->{'islegend'} ) {
    $output->{'islegend'} = 1;
  }
  
  return $output;
}

sub find_xys {
  my $conf = shift;
  return if( !$conf || !ref( $conf ) );
  my $ref = ref( $conf );
  my @xys;
  if( $ref eq 'HASH' ) {
    if( $conf->{'xys'} ) {
      return $conf->{'xys'};
    }
    
    for my $key ( keys %$conf ) {
      my $val = $conf->{ $key };
      my $res = find_xys( $val );
      if( $res ) {
        push( @xys, @$res );
      }
    }
    
  }
  if( $ref eq 'ARRAY' ) {
    for my $item ( @$conf ) {
      my $res = find_xys( $item );
      if( $res ) {
        push( @xys, @$res );
      }
    }
  }
  if( @xys ) {
    return \@xys;
  }
  return 0;
}

sub find_backend_charts {
  my ( $tb_name, $charts, $xys ) = @_;
  for my $chart ( @$charts ) {
    if( $chart->{'name'} ) {
      $tb_name .= "-".$chart->{'name'};
    }
    next if( $chart->{'type'} ne 'pie' );
    my @ys;
    for my $xy ( @$xys ) {
      push( @ys, $xy->{'y'}*1 );
    }
    $backend_charts{ $tb_name } = {
      data => \@ys
    };
  }
}

sub pass_chart_options {
  my ( $chart ) = @_;
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
  if( $chart->{'name'} ) {
    $o->{'name'} = xval( $chart->{'name'} );
  }
  return $o;
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
  
  #my $tablen = xval( $table->{'name'} );
  #print STDERR "table: $tablen, type: $type_name\n";
  
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
      
      
      #$group->{'name'} = $gp_name;
      
      $output->{ 'groups'} ||= [];
      my $ogroups = $output->{'groups'};
      
      my $gpsets = [];
      my $gp = { name => $gp_name, sets => $gpsets };
      if( $group->{'new_table_per_group'} ) {
        $gp->{'use_new_table'} = 1;
      }
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
        #print "Group key: $key\n";
        
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
      
      #print STDERR Dumper( $gpsets );
      
      if( @$gpsets ) {
        if( $gpsets->[0]{'sort'} ) {
          my @sorted;
          my $dir = $gpsets->[0]{'sortdir'};
          
          # set the 'pi' value to be an original 1 to n order
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
          
          if( !$dir || $dir eq '1' || $dir eq 'asc' ) {
            @sorted = sort {
              $a->{'sort'} <=> $b->{'sort'}
            } @$gpsets;
          }
          elsif( $dir eq 'desc' ) { @sorted = sort { $b->{'sort'} <=> $a->{'sort'} } @$gpsets; }
          else {
            print "Undefined sort dir $dir\n";
          }
          
          #print STDERR Dumper( \@sorted );
          
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
            
            # Use the original 'pi' 1 to n values to sort xy values the same as sorted items
            for( my $i=0;$i<scalar @sorted; $i++ ) {
              my $item = $sorted[ $i ];
              my $n = $xys->[ $item->{'pi'} ];
              #if( $n && ref( $n ) ne 'ARRAY' ) {
                $n = fill_in_xy( $n, { gi => $i } );
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
          
          pop( @$group_stack );
        }
        else {
          # We need to convert xy values from 'parts with types' to text, even when they aren't sorted
          if( $gp->{'xys'} ) {
            my @sxys = ();
            
            my $xys = $gp->{'xys'};
            
            
            for( my $i=0;$i<scalar @$xys; $i++ ) {
              my $xy = $xys->[ $i ];
              next if( !$xy );
              $xy = fill_in_xy( $xy, { gi => $i } );
              push( @sxys, $xy );
            }
            
            $gp->{'xys'} = \@sxys;
          }
        }
        
        my $sets = $gp->{'sets'};
        my $gi = 0;
        for my $set ( @$sets ) {
          fill_in_rows( $set, 'header', $gi++ );
        }
      }
    }
  }
  
  if( !$grouped && $type_name eq 'detail' ) {
    #if( $headers->[0]{'sort'} ) {
    if( $output->{'sort'} && @{$output->{'sort'}} ) {
      #print STDERR Dumper( $output );
      my $sort = $output->{'sort'};
      
      my $dir = $output->{'sortdir'};
      
      my @fakeitems;
      for( my $i=0;$i<scalar @$sort;$i++ ) {
        push( @fakeitems, { sort => $sort->[ $i ], pi => $i } );
      }
      
      if( !$dir || $dir eq '1' || $dir eq 'asc' ) {
        @fakeitems = sort {
          return 0 if( $a->{'sort'} eq '' || $b->{'sort'} eq '' );
          $a->{'sort'} <=> $b->{'sort'}
        } @fakeitems;
      }
      elsif( $dir eq 'desc' ) { @fakeitems = sort { $b->{'sort'} <=> $a->{'sort'} } @fakeitems; }
      else {
        print "Undefined sort dir $dir\n";
      }
      
      my @newdet;
      my @newxys;
      my @s2;
      for( my $i=0;$i<scalar @$sort;$i++ ) {
        #my $s = $sort->[ $i ];
        my $s = $fakeitems[ $i ];
        my $pi = $s->{'pi'};
        my $det = $output->{'detail'}[ $pi ];
        
        push( @newdet, $det ) if( $det );
        
        my $xy = $output->{'xys'}[ $pi ];
        if( defined $xy ) {
          $xy = fill_in_xy( $xy, { gi => $i } );
          push( @newxys, $xy );
        }
      }
      
      $output->{'detail'} = \@newdet;
      $output->{'xys'} = \@newxys;
    }
    else {
      my $xys = $output->{'xys'};
            
      my @sxys;
      for( my $i=0;$i<scalar @$xys; $i++ ) {
        my $xy = $xys->[ $i ];
        next if( !$xy );
        $xy = fill_in_xy( $xy, { gi => $i } );
        push( @sxys, $xy );
      }
      
      $output->{'xys'} = \@sxys;
    }
  }
  
  fill_in_rows( $output, $type_name, 0 );
}

sub fill_in_rows {
  my ( $output, $type_name, $gi ) = @_;
  
  my $detail = $output->{$type_name};
  if( !$detail || ! @$detail ) { return; }
  
  if( $type_name eq 'header' ) {
    #print STDERR Dumper( $detail );
  }
  
  my @det2;
    
  #print STDERR Dumper( $detail );
  for my $arr ( @$detail ) {
    next if( !$arr );
    if( !ref( $arr ) ) {
      push( @det2, $arr );
      next;
    }
    
    my $one = '';
    for my $item ( @$arr ) {
      next if( !$item );
      my $type = $item->{'type'};
      if( $type eq 'text' ) {
        my $val = $item->{'text'};
        if( defined $val ) {
          #push( @det2, $val );
          $one .= $val;
        }
      }
      if( $type eq 'delayed' ) {
        my $pre = $item->{'pre'};
        my $post = $item->{'post'};
        $one .= $pre;
        $one .= fill_in_delayed( $item->{'object'}, { gi => $gi } );
        $one .= $post;
      }
    }
    push( @det2, $one );
  }
  
  if( $type_name eq 'header' ) {
    #print STDERR Dumper( \@det2 );
  }
  
  $output->{$type_name} = \@det2;
}

sub fill_in_xy {
  my ( $xy, $hash ) = @_;
  
  #print STDERR Dumper( $xy );
  my %xy2;
  for my $key ( keys %$xy ) {
    my $ob = $xy->{ $key };
    my $out;
    if( ref( $ob ) eq 'ARRAY' ) {
      my @r;
      for my $oneob ( @$ob ) {
        push( @r, fill_xy_val( $oneob, $hash ) );
      }
      $out  = \@r;
    }
    else {
      $out = fill_xy_val( $ob, $hash );
    }
    
    $xy2{ $key } = $out;
  }
  
  return \%xy2;
}

sub fill_xy_val {
  my ( $ob, $hash ) = @_;
  my $type = $ob->{'type'};
  my $out;
  if( $type eq 'text' ) {
    $out = $ob->{'text'};
  }
  elsif( $type eq 'delayed' ) {
    my $pre = $ob->{'pre'} || '';
    my $post = $ob->{'post'} || '';
    $out = $pre . fill_in_delayed( $ob->{'object'}, $hash ) . $post;
  }
  return $out;
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
      
      my $xy = 0;
      my $sort = '';
      my $sort_dir = 'asc';
      
      if( $header->{'raw'} ) {
        my $raws = forcearray( $header->{'raw'} );
        for my $raw ( @$raws ) {
          my $val = xval( $raw ) || '';
          if( $val =~ m/\{/ ) {
            $val = fill_in_string( $val, $ctx, 'TPL' );
            if( ! defined $val ) {
              print "1r: ". $Text::Template::ERROR . "--" . xval( $raw ) . "--";
              exit;
            }
          }
          
          if( $raw->{'c'} ) {
            $xy ||= {};
            process_c( $xy, xval( $raw->{'c'} ), $val );
          }
          if( $raw->{'sort'} ) {
            $sort = $val;
            $sort_dir = xval( $raw->{'sort'} ) || 'desc';
          }
        }
      }
      
      my $ths;
      my $th_td;
      if( $header->{'th'} ) { $ths = forcearray( $header->{'th'} ); $th_td = 'th'; }
      if( $header->{'td'} ) { $ths = forcearray( $header->{'td'} ); $th_td = 'td'; }
      #$out .= "  <tr>\n";
      my $out = "";
      #if( $type_name eq 'detail' ) {
        $out = [];
      #}
      
      for my $th ( @$ths ) {
        my $val = xval( $th ) || '';
        my $dval;
        if( $val =~ m/\{/ ) {
          if( $th->{'delay'} ) {
            $dval = create_delayed( $val, $ctx, 'TPL' );
            $val = 'delayed';
          }
          else {
            $val = fill_in_string( $val, $ctx, 'TPL' );
            if( ! defined $val ) {
              print "1: ". $Text::Template::ERROR . "--" . xval( $th ) . "--";
              exit;
            }
          }
        }
        
        if( $th->{'c'} ) {
          $xy ||= {};
          if( $th->{'delay'} ) {
            process_c( $xy, xval( $th->{'c'} ), { type => 'delayed', object => $val } );
          }
          else {
            process_c( $xy, xval( $th->{'c'} ), { type => 'text', text => $val } );
          }
        }
        if( $th->{'name'} ) {
          $byname->{ xval( $th->{'name'} ) } = $val;
        }
        my $cs = '';
        if( $th->{'colspan'} ) {
          $cs = " colspan=\"" . xval( $th->{'colspan'} ) . "\"";
        }
        if( $th->{'width'} ) {
          $cs = " width=\"" . xval( $th->{'width'} ) . "\"";
        }
        
        if( $th->{'fullnode'} ) {
          if( $th->{'delay'} ) {
            push( $out, { type => 'delayed', object => $dval } );
          }
          else {
            push( $out, { type => 'text', text => $val } );
          }
        }
        else {
          if( $th->{'delay'} ) {
            push( $out, { type => 'delayed', pre => "    <$th_td$cs>", post => "</$th_td>\n", object => $dval } );
          }
          else {
            push( $out, { type => 'text', text => "    <$th_td$cs>$val</$th_td>\n" } );
          }
        }
        
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
        #print STDERR "Sort: $sortt\n";
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
      if( $type_name eq 'detail' ) {
        if( @$out ) {
          add_array_item( $output, $type_name, $out );
        }
      }
      else {
        add_array_item( $output, $type_name, $out );
      }
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

sub process_c {
  my ( $xy, $c, $val ) = @_;
  
  if( $c eq 'y' ) {
    if( defined $xy->{'y'} ) {  $xy->{'y'} = [ $xy->{'y'}, $val ]; }
    else                     {  $xy->{'y'} =               $val;   }
    return;
  }
  $xy->{ $c } = $val;
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
  my $rows = $gp || $ctx->{'rows'};
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
  my $rows = $gp || $ctx->{'rows'};
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

sub table {
  my $tname = shift;
  return "$tname";
}

sub chart {
  my $cname = shift;
  return "$cname";
}

sub std_color {
  my $i = shift;
  if( $i == -1 ) { return 'rgb(192,192,192)'; } 
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
  my $num = scalar @$colors;
  if( $i >= $num ) { return 'rgb(192,192,192)'; }
  
  my $color = $colors->[ $i ];
  return 'rgb('.$color->[0].','.$color->[1].','.$color->[2].')';
}

sub color_block {
  my $i = shift;
  my $color = std_color( $i );
  return "<div style='width: 20px; height: 20px; background: $color'>&nbsp;</div>";
}
