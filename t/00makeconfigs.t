#!/usr/bin/perl


# 00configfile - create temporary config file for subsequent tests

use strict;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 3 }

my $conf = "config.cf";

ok(open(F, ">${conf}1"), 1);
print F <<'EOCF';
#
# standard config file
#
one     1
two     2
three   3

support nate@wiger.org
website http://nate.wiger.org

date    today don\'t you know
time    $date 11:31

animals Rhino, Giraffe, Magical Elephant
mixedCase   no\$problemo
EOCF
close F;

ok(open(F, ">${conf}2"), 1);
print F <<'EOCT';
#
# ala Bourne shell
#

one=1
two=2
three=3
#immediate comment

    # indented comment

oracle_user=oracle
ORACLE_SID=testdb
ORACLE_HOME=/oracle/orahome1
Oracle_Data=/oracle/orahome1/oradata

# skip this $oracle_user comment

spacing=    pre-spaces
trailing=end-spaces     

reuse=$spacing

# damn French knights
if you say so=   No! Now go away!   

EOCT
close F;

ok(open(F, ">${conf}3"), 1);
print F <<'EOCL';
#
# fancy variable names and misc edge cases
#

Why-Not     "Hooka' Brutha' Up!!"

999+disembodied+heads   "who doesn't love late\-night horror flix?"

===?===?===     If this works, it's official, I\\\'m a PIMP with mad \$\$

1|2|3       "Ain't nobody that should fix ta' use \"this\""

$3.50       Damn you loch ness monster!

EOCL
close F;

