#!/usr/bin/env perl

package Qiniu::Utils::SHA1;

use strict;
use warnings;

use constant CHUNK_SIZE   => 64;
use constant MSG_PADDING  => "\x80" . ("\x0" x 63);
use constant ZERO_PADDING => "\x0" x 56;

my $left_rotate = sub {
    my $val  = shift;
    my $bits = shift;
    return (($val << $bits) & 0xFFFFFFFF) | ($val >> (32 - $bits));
}; # left_rotate

my $mod_add = sub {
    my $sum = 0;
    foreach my $val (@_) {
        $sum += $val;
        $sum &= 0xFFFFFFFF;
    } # foreach
    return $sum;
}; # mod_add

my $calc = sub {
    my $self = shift;
    my $msg  = shift;

    my @w = unpack('N16', $msg);
    for (my $i = 16; $i < 80; $i += 1) {
        $w[$i] = $left_rotate->(
            ($w[$i-3] ^ $w[$i-8] ^ $w[$i-14] ^ $w[$i-16]),
            1,
        );
    } # for

    my $a = $self->{hash}[0];
    my $b = $self->{hash}[1];
    my $c = $self->{hash}[2];
    my $d = $self->{hash}[3];
    my $e = $self->{hash}[4];

    my ($f, $k) = (0, 0);
    for (my $i = 0; $i < 80; $i += 1) {
        if (0 <= $i and $i <= 19) {
            $f = ($b & $c) | (((~$b) & 0xFFFFFFFF) & $d);
            $k = 0x5A827999;
        }
        if (20 <= $i and $i <= 39) {
            $f = $b ^ $c ^ $d;
            $k = 0x6ED9EBA1;
        }
        if (40 <= $i and $i <= 59) {
            $f = ($b & $c) | ($b & $d) | ($c & $d);
            $k = 0x8F1BBCDC;
        }
        if (60 <= $i and $i <= 79) {
            $f = $b ^ $c ^ $d;
            $k = 0xCA62C1D6;
        }

        my $temp = $mod_add->($left_rotate->($a, 5), $f, $e, $k, $w[$i]);
        $e = $d;
        $d = $c;
        $c = $left_rotate->($b, 30);
        $b = $a;
        $a = $temp;
    } # for

    $self->{hash}[0] = $mod_add->($self->{hash}[0], $a);
    $self->{hash}[1] = $mod_add->($self->{hash}[1], $b);
    $self->{hash}[2] = $mod_add->($self->{hash}[2], $c);
    $self->{hash}[3] = $mod_add->($self->{hash}[3], $d);
    $self->{hash}[4] = $mod_add->($self->{hash}[4], $e);
}; # calc

sub new {
    my $class = shift || __PACKAGE__;
    my $self = {};
    bless $self, $class;
    $self->reset();
    return $self;
} # new

sub write {
    my $self = shift;
    my $msg  = shift;

    if (not defined($msg) or ref($msg) ne q{}) {
        return;
    }

    $self->{msg_len} += length($msg);
    $msg = $self->{remainder} . $msg;

    my $msg_len = length($msg);
    if ($msg_len < CHUNK_SIZE) {
        $self->{remainder} = $msg;
        return $self;
    }

    $self->{remainder} = "";
    for (my $pos = 0; $pos < $msg_len; $pos += CHUNK_SIZE) {
        if ($msg_len - $pos < CHUNK_SIZE) {
            $self->{remainder} = substr($msg, $pos);
            last;
        }
        $self->$calc(substr($msg, $pos, CHUNK_SIZE));
    } # for

    return $self;
} # write

sub sum {
    my $self = shift;
    my $msg  = shift;

    $self->write($msg);
    my $last_msg = $self->{remainder} . MSG_PADDING;

    if (CHUNK_SIZE < (length($self->{remainder}) + 1 + 8)) {
        $self->$calc(substr($last_msg, 0, CHUNK_SIZE));
        $last_msg = ZERO_PADDING;
    }
    else {
        $last_msg = substr($last_msg, 0, 56);
    }
    my $msg_bits_len = $self->{msg_len} * 8;
    $last_msg .= pack('N', ($msg_bits_len >> 32) & 0xFFFFFFFF);
    $last_msg .= pack('N', $msg_bits_len & 0xFFFFFFFF);
    $self->$calc($last_msg);
    return join("", map { pack('N', $_) } @{$self->{hash}});
} # sum

sub reset {
    my $self = shift;
    $self->{msg_len} = 0;
    $self->{remainder}  = "";

    $self->{hash} = [
        0x67452301,
        0xEFCDAB89,
        0x98BADCFE,
        0x10325476,
        0xC3D2E1F0,
    ];
    return $self;
} # reset

sub chunk_size {
    return CHUNK_SIZE;
} # chunk_size

1;

__END__
