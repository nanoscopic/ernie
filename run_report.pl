#!/usr/bin/perl -w
use strict;
use File::Copy;

my $report_type = $ARGV[0];
my $report_id = $ARGV[1];

# read in configuration

# pull data from server, storing for later possible reuse
chdir "extract_data";
`./pull_data.pl $report_type $report_id`;

# process all tables in configuration, generating table and chart JSON structures
chdir "../transform_data";
`./run_report.pl $report_type $report_id`;
chdir "..";

chdir "charting";
`./render_charts.pl $report_id`;

#unlink("./render/out.json");
#copy("./data/out_${report_type}_$report_id.json","./render/out.json");

# transform template from backend XML to frontend JSON, utilizing results from table and chart data generation
#chdir "transform_template";
#`./config_to_json_tpl.pl $report_type`;
#chdir "..";
#copy("./configuration/config_$report_type.json","./render/config.json");

# do "frontend" report generation, reading in created data JSON and transformed template JSON

