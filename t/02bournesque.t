#!/usr/bin/perl

# 01bournesque - read the second config file, which is Bourne style

use strict;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 12 }

my $conf = "config.cf2";

use Config::Fast;

my %cf = fastconfig($conf, '=');

ok($cf{one}, 1);
ok($cf{two}, 2);
ok($cf{three}, 3);
ok($cf{oracle_user}, 'oracle');
ok($cf{ORACLE_HOME}, '/oracle/orahome1');
ok($cf{Oracle_Data}, '/oracle/orahome1/oradata');
ok($cf{spacing}, '    pre-spaces');
ok($cf{trailing}, 'end-spaces     ');
ok($cf{reuse}, '    pre-spaces');
ok($cf{'if you say so'},    '   No! Now go away!   ');
ok($ENV{ORACLE_HOME}, $cf{ORACLE_HOME});

my @n = keys %cf;
my $n = @n;
ok($n, 12);

