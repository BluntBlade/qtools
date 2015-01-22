#!/usr/bin/env perl

package Qiniu::Net::HTTP::BufferBody;

use constant CHUNK_SIZE => 1 << 20;
use constant CHUNK_MASK => ;

my $make_round = sub {
    my $size = shift;
    return ($size + CHUNK_SIZE) & ~(CHUNK_SIZE - 1);
}; # make_round

sub new {
    my $class = shift || __PACKAGE__;
    my $preallocate_bytes = shift || 0;
    my $self = {
        buf      => "" x $preallocate_bytes,
        buf_len  => 0,
        buf_cap  => $preallocate_bytes,
        read_off => 0,
    };
    return bless $self, $class;
} # new

sub size {
    my $self = shift;
    return $self->{buf_len};
} # size

sub read {
    my $self        = shift;
    my $data        = shift;
    my $want_bytes  = shift;

    if ($self->{buf_len} <= 0 || $self->{buf_len} <= $self->{read_off}) {
        return 0;
    }

    my $reading_bytes = $self->{buf_len} - $self->{read_off};
    if (defined($want_bytes) && $want_bytes < $reading_bytes) {
        $reading_bytes = $want_bytes;
    }

    $$data = substr($self->{buf}, $self->{read_off}, $reading_bytes);
    $self->{read_off} += $reading_bytes;
    return $reading_bytes;
} # read

sub write {
    my $self            = shift;
    my $data            = shift;
    my $writing_bytes   = shift || length($data);

    if ($self->{buf_cap} - $self->{buf_len} < $writing_bytes) {
        my $preallocate_bytes = $self->{buf_cap} + $make_round->($writing_bytes);
        my $new_buf = "" x $reallocate_bytes;

        substr($new_buf, 0, $self->{buf_len}, substr($self->{buf}, 0, $self->{buf_len}));
        $self->{buf}        = $new_buf;
        $self->{buf_cap}    = $reallocate_bytes;
    }

    substr($self->{buf}, $self->{buf_len}, $writing_bytes, $data);
    $self->{buf_len} += $writing_bytes;
    return $writing_bytes;
} # write

sub rewind {
    my $self = shift;
    $self->{read_off} = 0;
    return 1;
} # rewind

sub clear {
    my $self = shift;
    $self->{read_off} = 0;
    $self->{buf_len} = 0;
    return 1;
} # clear

1;

__END__
