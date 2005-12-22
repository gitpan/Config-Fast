
package Config::Fast;

=head1 NAME

Config::Fast - extremely fast configuration file parser

=head1 SYNOPSIS

    # default config format is a space-separated file
    company    "Supercool, Inc."
    support    nobody@nowhere.com


    # and then in Perl
    use Config::Fast;

    %cf = fastconfig;

    print "Thanks for visiting $cf{company}!\n";
    print "Please contact $cf{support} for support.\n";

=cut

use Carp;
use strict;
use vars qw($VERSION %READCONF @EXPORT $MTIME $ALLCAPS $SOURCE
            $DELIM $ENVCAPS $KEEPCASE $ARRAYS %CONVERT);

use Exporter;
use base 'Exporter';
@EXPORT   = qw(fastconfig);
$VERSION  = do { my @r=(q$Revision: 1.6 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };
%READCONF = ();

#
# Global settings - can override with $Config::Fast::PARAM = 'value';
#
$DELIM    = '\s+';          # default delimiter
$KEEPCASE = 0;              # preserve MixedCase variables?
$ENVCAPS  = 1;              # setenv ALLCAPS variables?
$ARRAYS   = 0;              # set var[0] as array elements?
%CONVERT  = (               # convert these values appropriately
    'true|on|yes'  => 1,
    'false|off|no' => 0,
);

#
# Internal variables; are overridable, but undocumented
#
$MTIME    = '_mtime';
$ALLCAPS  = '_allcaps';
$SOURCE   = '_source';

sub fastconfig (;$$) {
    my $file  = shift;
    my $delim = shift || $DELIM;

    # auto file detection
    unless ($file) {
        require File::Basename;
        my $dir  = File::Basename::dirname($ENV{SCRIPT_NAME} || $0);  # mod_perl usage
        my $prog = File::Basename::basename($ENV{SCRIPT_NAME} || $0);
        require File::Spec;
        $file = File::Spec->catfile($dir, '..', 'etc', "$prog.conf")
    }

    croak "fastconfig: Invalid configuration file '$file'"
        unless -f $file && -r _;

    my %tmp = ();     # to reuse vars
    my $mtime = -M _;
    if (! $READCONF{$file}{$MTIME} || $mtime < $READCONF{$file}{$MTIME}) {
        $READCONF{$file}{$ALLCAPS} ||= [];
        $READCONF{$file}{$SOURCE} = 'file';
        (my $srcpkg = $SOURCE) =~ s/\W+//g;
        {
            #
            # We now parse variables by eval'ing them inline. This gets us
            # the same quoting conventions Perl uses implicitly.
            #
            package Config::Fast::Parser;
            no strict;
            use Carp;

            open CF, "<$file" or croak "fastconfig: Can't open $file: $!";
            while (<CF>) {
                next if /^\s*$/ || /^\s*#/; chomp;

                my($key, $val) = split /$delim/, $_, 2;

                # See if our var is ALLCAPS to setenv it
                my $env = $key =~ /^[A-Z0-9_]+(\[\d+\])?$/ ? $key : undef;

                $val =~ s/^\s*(["']?)(.*)\1\s*$/$2/g;
                my $q = $1 || '"';                          # save quote
                unless ($q eq "'") {
                    $val =~ s/([^a-zA-Z0-9_\$\\'"])/\\$1/g  # escape nasty (sneaky?) chars
                }
                $val = qq{$q$val$q};                        # add quotes back in

                # Now check for "on/off" or "true/false"
                for my $pat (keys %CONVERT) {
                    $val = $CONVERT{$pat} if $val =~ /^($pat)$/i;
                }

                # Convert MixedCaseGook to $mixedcasegook?
                my $pkey = $Config::Fast::KEEPCASE ? $key : lc($key);

                my $ekey;   # eval key
                if ($Config::Fast::ARRAYS && $pkey =~ s/\[(\d+)\]$//) {
                    $ekey = q($Config::Fast::READCONF{$file}{$pkey}[$1] = ${$key}[$1] = );
                } else {
                    $ekey = q($Config::Fast::READCONF{$file}{$pkey} = $$key = );
                }
                eval $ekey . '$tmp = ' . $val;
                warn "Error: \$$key = $val\n       $@" if $@;

                # Push it as an env var if so requested
                if ($Config::Fast::ENVCAPS && $env) {
                    push @{$Config::Fast::READCONF{$file}{$Config::Fast::ALLCAPS}},
                         [ $env => $tmp ];
                }
            }
            $Config::Fast::READCONF{$file}{$Config::Fast::MTIME} = $mtime;
            close CF;
        }   # block
    } else {
        $READCONF{$file}{$SOURCE} = 'cache';
    }

    # ALLCAPS vars go into env, do this each time so that
    # calls to fastconfig() always reset the environment.
    for (@{$READCONF{$file}{$ALLCAPS}}) {
        $ENV{$_->[0]} = $_->[1];
    }

    if (wantarray) {
        return %{$READCONF{$file}};
    } else {
        # import vars into main namespace
        no strict 'refs';
        while (my($k,$v) = each %{$READCONF{$file}}) {
            next if $k =~ /^_/;
            eval {
                *{"main::$k"} = \$v;
            };
            croak "fastconfig: Could not import variable '$k': $@" if $@;
        }
        return 1;
    }
}

1;

__END__

=head1 DESCRIPTION

This module is designed to provide an extremely lightweight way to parse
moderately complex configuration files. As such, it exports a single
function - C<fastconfig()> - and does not provide any OO access methods.
Still, it is fairly full-featured.

Here's how it works:

    %cf = fastconfig($file, $delim);

Basically, the C<fastconfig()> function returns a hash of keys and values
based on the directives in your configuration file. By default, directives
and values are separated by whitespace in the config file, but this can
be easily changed with the delimiter argument (see below).

When the configuration file is read, its modification time is first checked
and the results cached. On each call to C<fastconfig()>, if the config file has
been changed, then the file is reread. Otherwise, the cached results are 
returned automatically. This makes this module great for C<mod_perl> 
modules and scripts, one of the primary reasons I wrote it. Simply include this
at the top of your script or inside of your constructor function:

    my %cf = fastconfig('/path/to/config/file.conf');

If the file argument is omitted, then C<fastconfig()> looks for a file
named C<$0.conf> in the C<../etc> directory relative to the executable.
For example, if you ran:

    /usr/local/bin/myapp

Then C<fastconfig()> will automatically look for:

    /usr/local/etc/myapp.conf

This is great if you're really lazy and always in a hurry, like I am.

If this doesn't work for you, simply supply a filename manually. Note that
filename generation does not work in C<mod_perl>, so you'll need to supply
a filename manually.

=head1 FILE FORMAT

By default, your configuration file is split up on the first white space
it finds. Subsequent whitespace is preserved intact - quotes are not needed
(but you can include them if you wish). For example, this:

    company     Hardwood Flooring Supplies, Inc.

Would result in:

    $cf{company} = 'Hardwood Flooring Supplies, Inc.';

Of course, you can use the delimiter argument to change the delimiter to
anything you want. To read Bourne shell style files, you would use:

    %cf = fastconfig($file, '=');

This would let you read a file of the format:

    system=Windows
    kernel=sortof

In all formats, any space around the value is stripped. This is one situation
where you must include quotes:

    greeting="     Some leading and trailing space    "

Each configuration directive is read sequentially and placed in the
hash. If the same directive is present multiple times, the last one
will override any earlier ones.

In addition, you can reuse previously-defined variables by preceding
them with a C<$> sign. Hopefully this seems logical to you.

    owner       Bill Johnson
    company     $owner and Company, Ltd.
    website     http://www.billjohnsonltd.com
    products    $website/newproducts.html

Of course, you can include literal characters by escaping them:

    price       \$5.00
    streetname  "Guido \"The Enforcer\" Scorcese"
    verbatim    'Single "quotes" are $$ money @ night'
    fileregex   '(\.exe|\.bat)$'

Basically, this modules attempts to mimic, as closely as possible,
Perl's own single and double quoting conventions.

Variable names are B<case-insensitive> by default (see C<KEEPCASE>).
In this example, the last setting of C<ORACLE_HOME> will win:

    oracle_home /oracle
    Oracle_Home /oracle/orahome1
    ORACLE_HOME /oracle/OraHome2

In addition, variables are converted to lowercase before being returned
from C<fastconfig()>, meaning you would access the above as:

    print $cf{oracle_home};     # /oracle/OraHome2

Speaking of which, an extra nicety is that this module will setup 
environment variables for any ALLCAPS variables you define. So, the
above C<ORACLE_HOME> variable will automatically be stuck into %ENV. But
you would still access it in your program as C<oracle_home>. This may
seem confusing at first, but once you use it, I think you'll find it
makes sense.

Finally, if called in a scalar context, then variables will be imported
directly into the C<main::> namespace, just like if you had defined them
yourself:

    use Config::Fast;

    fastconfig('web.conf');

    print "The web address is: $website\n";     # website from conf

Generally, this is regarded as B<dangerous> and bad form, so I would
strongly advise using this form only in throwaway scripts, or not at
all.

=head1 VARIABLES

There are several global variables that can be set which affect how
C<fastconfig()> works. These can be set in the following way:

    use Config::Fast;
    $Config::Fast::VARIABLE = 'value';
    %cf = fastconfig;

The recognized variables are:

=over

=item $DELIM

The config file delimiter to use. This can also be specified as the second
argument to C<fastconfig()>. This defaults to C<\s+>.

=item $KEEPCASE

If set to 1, then C<MixedCaseVariables> are maintained intact. By default,
all variables are converted to lowercase.

=item $ENVCAPS

If set to 0, then any C<ALLCAPS> variables are I<not> set as environment
variables.

=item %ARRAYS

If set to 1, then settings that look like shell arrays are converted into
a Perl array. For example, this config block:

    MATRIX[0]="a b c"
    MATRIX[1]="d e f"
    MATRIX[2]="g h i"

Would be returned as:

    $conf{matrix} = [ 'a b c', 'd e f', 'g h i' ];

Instead of the default:

    $conf{matrix[0]} = 'a b c';
    $conf{matrix[1]} = 'd e f';
    $conf{matrix[2]} = 'g h i';

=item %CONVERT

This is a hash of regex patterns specifying values that should be converted
before being returned. By default, values that look like C<true|on|yes>
will be converted to 1, and values that match C<false|off|no> will be
converted to 0. You could set your own conversions with:

    $Config::Fast::CONVERT{'fluffy|chewy'} = 'taffy';

This would convert any settings of "fluffy" or "chewy" to "taffy".

=back

=head1 NOTES

Variables starting with a leading underscore are considered reserved
and should not be used in your config file, unless you enjoy painfully
mysterious behavior.

For a much more full-featured config module, check out C<Config::ApacheFormat>.
It can handle Apache style blocks, array values, etc, etc. This one is
supposed to be fast and easy.

=head1 VERSION

$Id: Fast.pm,v 1.5 2005/10/11 23:46:22 nwiger Exp nwiger $

=head1 AUTHOR

Copyright (c) 2002-2005 Nathan Wiger <nate@wiger.org>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut

