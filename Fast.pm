
package Config::Fast;

=head1 NAME

Config::Fast - extremely fast configuration file parser

=head1 SYNOPSIS

    # config file is simple space-separated format
    company     Supercool, Inc.
    support     nobody@nowhere.com


    # and then in Perl
    use Config::Fast;

    %cf = fastconfig;

    print "Thanks for visiting $cf{company}!\n";
    print "Please contact $cf{support} for support.\n";

=head1 COMPATIBILITY

Please note: Starting with the 1.04 release, all variables are now
matched case-insensitively, and returned in all lowercase in the
hash returned from C<fastconfig()>. If you were using C<MixedCase>
variables, you will have to change your code to access these as
C<$cf{mixedcase}> from now on.

=cut

use Carp;
use strict;
use vars qw($VERSION %READCONF @EXPORT $MTIME $ALLCAPS $SOURCE $PLACEHOLDER $YES $NO);

use Exporter;
use base 'Exporter';
@EXPORT = qw(fastconfig);

$VERSION  = do { my @r=(q$Revision: 1.4 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };
%READCONF = ();
$MTIME    = '_mtime';
$ALLCAPS  = '_allcaps';
$SOURCE   = '_source';

$YES      = 'true|on|yes';
$NO       = 'false|off|no';

# This is a quick hack to handle escaped vars
# If you need to override it, use $Config::Fast::PLACEHOLD = 'whatever';
$PLACEHOLDER = "~PLaCE_h0LDeR_$$~";

sub fastconfig (;$$) {
    my @parts = split '/', $0;
    my $prog  = pop @parts;
    my $dir   = join '/', @parts;
    my $file  = shift || "$dir/../etc/$prog.conf";
    my $delim = shift || '\s+';

    croak "fastconfig: Invalid configuration file '$file'" unless -f $file && -r _;

    my %tmp = ();     # to reuse vars
    my $mtime = -M _;
    if (! $READCONF{$file}{$MTIME} || $mtime < $READCONF{$file}{$MTIME}) {
        $READCONF{$file}{$ALLCAPS} ||= [];
        $READCONF{$file}{$SOURCE} = 'file';
        open CF, "<$file" or croak "fastconfig: Can't open $file: $!";
        while (<CF>) {
            next if /^\s*$/ || /^\s*#/; chomp;

            my($key, $val) = split /$delim/, $_, 2;
            my $env = $key =~ /^[A-Z0-9_]+$/;
            $key = lc $key;

            carp "fastconfig: Magical variable name '$MTIME' seen in $file"
                if $key eq $MTIME;

            # This substitutes in variables from the file, somewhat hackishly
            # For some reason my brain is frozen and I can't figure out \$
            $val =~ s/\\\$/$PLACEHOLDER/g;
            $val =~ s/\$\{?(\w+)/$tmp{$1}/g;
            $val =~ s/$PLACEHOLDER/\$/g;

            # Strip off surrounding quotes (they're really not needed)
            $val =~ s/"(.*)"/$1/g;
            $val =~ s/\\(.)/$1/g;   # fix escaped thingies

            # Now check for "on/off" or "true/false"
            $val = 1 if $val =~ /^($YES)$/i;
            $val = 0 if $val =~ /^($NO)$/i;

            # Save it in our conf and also keep temporarily
            $READCONF{$file}{$key} = $tmp{$key} = $val;
            push @{$READCONF{$file}{$ALLCAPS}}, $key if $env;
        }
        $READCONF{$file}{$MTIME} = $mtime;
        close CF;
    } else {
        $READCONF{$file}{$SOURCE} = 'cache';
    }

    # ALLCAPS vars go into env, do this each time so that
    # calls to fastconfig() always reset the environment.
    for (@{$READCONF{$file}{$ALLCAPS}}) {
        $ENV{uc($_)} = $READCONF{$file}{$_};
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

This module is designed to provide an extremely fast and lightweight
way to parse moderately complex configuration files. As such, it exports
a single function - C<fastconfig()> - and does not provide any OO access
methods. Still, it is fairly full-featured.

Here's how it works:

    %cf = fastconfig($file, $delim);

Basically, the C<fastconfig()> function returns a hash of keys and values
based on the directives in your configuration file. By default, directives
and values are separated by whitespace in the config file, but this can
be easily changed with the delimiter argument (see below).

When the configuration file is read, its modification time is first checked
and the results cached. On each call to C<fastconfig()>, if the config file has
been changed, then the file is reread. Otherwise, the cached results are 
returned automatically. This makes this module great for C<mod_perl> based 
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
it finds. Subsequent whitespace is preserved intact - quotes are not needed.
For example, this:

    company     Hardwood Flooring Supplies, Inc.

Would result in:

    $cf{company} = 'Hardwood Flooring Supplies, Inc.';

Of course, you can use the delimiter argument to change the delimiter to
anything you want, perhaps to read Bourne shell style files:

    %cf = fastconfig($file, '=');

This would let you read a file of the format

    system=Eunice
    kernel=sortof

Each configuration directive is read sequentially and placed in the
hash. If the same directive is present multiple times, the last one
will override any earlier ones.

In addition, you can reuse previously-defined variables by preceding
them with a C<$> sign. Hopefully this seems logical to you.

    owner       Bill Johnson
    company     $owner and Company, Ltd.

Of course, you can include literal characters by escaping them:

    price       \$5.00
    streetname  "Guido \"The Enforcer\" Scorcese"

Unlike previous versions of this module, variable names are
B<case-insensitive>. In this situation, the last setting of
C<ORACLE_HOME> will win:

    oracle_home /oracle
    Oracle_Home /oracle/orahome1
    ORACLE_HOME /oracle/OraHome2

However, variables are converted to lowercase before being returned
from C<fastconfig()>, meaning you would access this as:

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

=head1 NOTES

Variables starting with a leading underscore are considered reserved
and should not be used in your config file, unless you enjoy painfully
mysterious behavior.

There are some global variables that you can use to customize certain
aspects of this module. If you really want to tweak it, read through
the source, then do something like:

    use Config::Fast;
    $Config::Fast::SOMESETTING = 'whatever';
    %cf = fastconfig;

For a much more full-featured config module, check out C<Config::ApacheFormat>.
It can handle Apache style blocks, array values, etc, etc. This one is
supposed to be fast and easy.

=head1 VERSION

$Id: Fast.pm,v 1.4 2003/11/03 21:42:12 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2002-2003 Nathan Wiger <nate@sun.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut

