
package Config::Fast;

=head1 NAME

Config::Fast - extremely fast configuration file reader / parser

=head1 SYNOPSIS

    use Config::Fast;

    %cf = fastconfig;

    print "Please contact $cf{support} for support\n";

=head1 DESCRIPTION

This module is designed to provide an extremely fast and lightweight
way to parse moderately complex configuration files. As such, it exports
a single function - C<fastconfig()> - and does not provide an OO access
method. Still, it is fairly full-featured.

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
named C<progname.conf> in the C<../etc> directory relative to the executable.
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

Variable names are case-sentitive! These are three different variables:

    oracle_home /oracle
    Oracle_Home /oracle/orahome1
    ORACLE_HOME /oracle/OraHome2

Speaking of which, an extra nicety is that this module will setup 
environment variables for any ALLCAPS variables you define. So, the
above ORACLE_HOME variable will automatically be stuck into %ENV.

Finally, if called in a scalar context, then variables will be imported
directly into the C<main::> namespace, just like if you had defined them
yourself:

    use Config::Fast;

    fastconfig;

    print "The web address is: $website\n";     # website from conf

Generally, this is regarded as B<dangerous> and bad form, so I would
strongly advise using this form only in throwaway scripts, or not at
all.

=cut

use Carp;
use strict;
use vars qw($VERSION %READCONF @EXPORT);

use Exporter;
use base 'Exporter';
@EXPORT = qw(fastconfig);

$VERSION  = do { my @r=(q$Revision: 1.3 $=~/\d+/g); sprintf "%d."."%02d"x$#r,@r };
%READCONF = ();

sub fastconfig (;$$) {
    my($dir,$prog) = $0 =~ /(.*)\/(.+)/;
    my $file  = shift || "$dir/../etc/$prog.conf";
    my $delim = shift || '\s+';

    croak "fastconfig: Invalid configuration file '$file'" unless -f $file && -r _;

    my %cache = ();     # cache keys
    my $mtime = -M _;
    if (! $READCONF{mtime} || $mtime < $READCONF{mtime}) {
        open CF, "<$file" or croak "Can't open $file: $!";
        while (<CF>) {
            next if /^\s*$/ || /^\s*#/; chomp;

            my($key, $val) = split /$delim/, $_, 2;

            carp "fastconfig: Magical variable name 'mtime' seen in $file"
                if $key eq 'mtime';

            # This substitutes in variables from the file, somewhat hackishly
            # For some reason my brain is frozen and I can't figure out \$
            $val =~ s/\\\$/~~SCALAR~~/g;
            $val =~ s/\$(\w+)/$cache{$1}/g;
            $val =~ s/~~SCALAR~~/\\\$/g;

            # Strip off surrounding quotes (they're really not needed)
            $val =~ s/"(.*)"/$1/g;
            $val =~ s/\\(.)/$1/g;   # fix escaped thingies

            # Now check for "on/off" or "true/false"
            $val = 1 if $val =~ /^true$/i  || $val =~ /^on$/i;
            $val = 0 if $val =~ /^false$/i || $val =~ /^off$/i;

            # Save it in our conf and also "cache" temporarily
            $READCONF{$key} = $cache{$key} = $val;
        }
        $READCONF{mtime} = $mtime;
        close CF;
    }

    # Uppercase vars go into env, do this each time so that
    # calls to fastconfig() always reset the environment.
    for (keys %READCONF) {
        $ENV{$_} = $READCONF{$_} if /^[A-Z0-9_]+$/;
    }

    if (wantarray) {
        return %READCONF;
    } else {
        # import vars into main namespace
        no strict 'refs';
        while (my($key,$val) = each %READCONF) {
            croak "fastconfig: Illegal variable name '$key', cannot import"
                unless $key =~ /^\w+$/;
            *{"main::$key"} = \$val || return undef;
        }
        return 1;
    }
}

1;

=head1 NOTES

The key "mtime" is magical and cannot be used as a variable name
in your config file.

=head1 VERSION

$Id: Fast.pm,v 1.3 2003/04/05 02:06:28 nwiger Exp $

=head1 AUTHOR

Copyright (c) 2002-2003 Nathan Wiger <nate@sun.com>. All Rights Reserved.

This module is free software; you may copy this under the terms of
the GNU General Public License, or the Artistic License, copies of
which should have accompanied your Perl kit.

=cut

