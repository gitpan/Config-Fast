#!/usr/bin/perl -I.. -w

# 01bournesque - read the third config file, which hits all the edge cases

use strict;
use Test;

# use a BEGIN block so we print our plan before module is loaded
BEGIN { plan tests => 6 }

my $conf = "t/config.cf3";

use Config::Fast;

my %cf = fastconfig($conf);

ok($cf{'why-not'}, "Hooka' Brutha' Up!!");
ok($cf{'999+disembodied+heads'}, "who doesn't love late-night horror flix?");
ok($cf{'===?===?==='}, "If this works, it's official, I\\\'m a PIMP with mad \$\$");
ok($cf{'1|2|3'}, "Ain't nobody that should fix ta' use \"this\"");
ok($cf{'$3.50'}, 'Damn you loch ness monster!');

my @n = keys %cf;
my $n = @n;
ok($n, 8);

