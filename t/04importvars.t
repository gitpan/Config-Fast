#!/usr/bin/perl

# 04importvars - import vars into main:: from first config file

use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 9 }

my $conf = "config.cf1";

use Config::Fast;

# damn perl warnings piss me off
$one = $two = $three = $support = $website = $date
= $time = $animals = $mixedCase = undef;

fastconfig($conf);

ok($one, 1);
ok($two, 2);
ok($three, 3);
ok($support, 'nate@wiger.org');
ok($website, 'http://nate.wiger.org');
ok($date, "today don't you know");
ok($time, "today don't you know 11:31");
ok($animals, 'Rhino, Giraffe, Magical Elephant');
ok($mixedCase, 'no$problemo');

