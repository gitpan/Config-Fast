#!/usr/bin/perl -I.. -w

# 01stdconfig - read the first config file, which is "standard"

use strict;
use Test;

# use a BEGIN block so we print our plan before module is loaded
BEGIN { plan tests => 10 }

my $conf = "t/config.cf1";

use Config::Fast;

my %cf = fastconfig($conf);

ok($cf{one}, 1);
ok($cf{two}, 2);
ok($cf{three}, 3);
ok($cf{support}, 'nate@wiger.org');
ok($cf{website}, 'http://nate.wiger.org');
ok($cf{date}, "today don't you know");
ok($cf{time}, "today don't you know 11:31");
ok($cf{animals}, 'Rhino, Giraffe, Magical Elephant');
ok($cf{mixedcase}, 'no$problemo');

my @n = keys %cf;
my $n = @n;
ok($n, 12);

