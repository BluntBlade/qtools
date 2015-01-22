#!/usr/bin/env perl

package Qiniu::Net::HTTP::FileBody;

use strict;
use warnings;

use Fcntl qw(SEEK_SET);

my $open_for_reading = sub {
    my $self = shift;
    my $ret = open(my $rfh, "<", $self->{wfh}->fileno());
    if (not $ret) {
        return undef;
    }
    if (defined($self->{rfh})) {
        close($self->{rfh});
    }
    $self->{rfh} = $rfh;
    return 1;
}; # open_for_reading

sub new {
    my $class = shift || __PACKAGE__;
    my $self = {};

    my $wfh = IO::File->new_tmpfile();
    if (not defined($wfh)) {
        return undef;
    }
    $self->{wfh} = $wfh;
    $self->{fsize} = 0;

    bless $self, $class;
    if (not $open_for_reading->($self)) {
        return undef;
    }

    return $self;
} # new

sub size {
    my $self = shift;
    return $self->{fsize};
} # size

sub read {
    my $self        = shift;
    my $data        = shift;
    my $want_bytes  = shift;

    if (eof($self->{rfh})) {
        return 0;
    }

    return read($self->{rfh}, $$data, $want_bytes);
} # read

sub write {
    my $self            = shift;
    my $data            = shift;
    my $writing_bytes   = shift;

    my $written_bytes = 0;
    if (defined($writing_bytes) && $writing_bytes > 0) {
        $written_bytes = syswrite($self->{wfh}, $data, $writing_bytes);
    } else {
        $written_bytes = syswrite($self->{wfh}, $data);
    }
    if (defined($written_bytes)) {
        $self->{fsize} += $written_bytes;
    }
    return $written_bytes;
} # write

sub rewind {
    my $self = shift;
    if (defined($self->{rfh})) {
        return seek($self->{rfh}, 0, SEEK_SET);
    }
    return 1;
} # rewind

sub clear {
    my $self = shift;
    my $wfh = IO::File->new_tmpfile();
    if (not $wfh) {
        return undef;
    }
    close($self->{wfh});
    $self->{wfh} = $wfh;
    $self->{fsize} = 0;

    return $open_for_reading->($self);
} # clear

sub close {
    my $self = shift;
    if (defined($self->{rfh})) {
        close($self->{rfh});
    }
    return close($self->{wfh});
} # close

1;

__END__
