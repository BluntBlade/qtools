#!/usr/bin/env perl

package Qiniu::Flag;

use strict;
use warnings;

use constant STRING => 'string';
use constant NUMBER => 'number';
use constant BOOL   => 'bool';

my %bound_vars = ();

sub bind_string {
    my $ref  = shift;
    my $name = shift;
    $bound_vars{$name} = { ref => $ref, type => STRING };
    return $ref;
} # bind_string

sub bind_number {
    my $ref  = shift;
    my $name = shift;
    $bound_vars{$name} = { ref => $ref, type => NUMBER };
    return $ref;
} # bind_number

sub bind_bool {
    my $ref  = shift;
    my $name = shift;
    $bound_vars{$name} = { ref => $ref, type => BOOL };
    return $ref;
} # bind_bool

sub parse {
    my @argv = ();
    my $name = undef;

    foreach my $val (@ARGV) {
        if ($name) {
            ${ $bound_vars{$name}{ref} } = $val;
            if ($bound_vars{$name}{type} eq NUMBER) {
                ${ $bound_vars{$name}{ref} } += 0;
            }

            undef $name;
            next;
        }

        if ($val =~ m/^(?:--|[+-])(\w+)$/) {
            if ($bound_vars{$name}{type} eq BOOL) {
                my $leading = substr($1, 0, 1);
                ${ $bound_vars{$name}{ref} } = ($leading eq '-') ? 1 : 0;
                next;
            }

            $name = $2;
            next;
        }

        push @argv, $val;
    } # foreach

    return @argv;
} # parse

1;
