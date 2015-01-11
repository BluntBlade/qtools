#!/usr/bin/env perl

use strict;
use warnings;

package Qiniu::Net::HTTP::Header;

sub new {
    my $class = shift;
    my $self  = {};

    return bless $self, $class;
} # new

sub add {
    my $self = shift;
    my $hdr  = shift;
    my $val  = shift;

    if (not exists $self->{$hdr}) {
        $self->{$hdr} = [ $val ];
    }

    push @{ $self->{$hdr} }, $val;
    return $self;
} # add

sub set {
    my $self = shift;
    my $hdr  = shift;
    my $val  = shift;

    $self->{$hdr} = [ $val ];
    return $self;
} # set

sub unset {
    my $self = shift;
    my $hdr  = shift;

    if (exists $self->{$hdr}) {
        delete $self->{$hdr};
    }
    return $self;
} # unset

sub clone_and_merge {
    my $self    = shift;
    my $headers = shift;

    my $final_headers = {};

    foreach my $key (keys(%{ $self })) {
        $final_headers->{$key} = $self->{$key};
    } # foreach
    foreach my $key (keys(%{ $headers })) {
        $final_headers->{$key} = $headers->{$key};
    } # foreach

    return $final_headers;
} # clone_and_merge

1;

__END__
