#!/usr/bin/perl


# 99configclean - cleanup temporary files

use strict;
use Test;

# use a BEGIN block so we print our plan before CGI::FormBuilder is loaded
BEGIN { plan tests => 3 }

my $conf = "config.cf";
for (my $i=1; $i <= 3; $i++) {
    ok(unlink("${conf}$i"), 1);
}

