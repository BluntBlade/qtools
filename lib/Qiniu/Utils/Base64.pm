#!/usr/bin/env perl

##############################################################################
#
#
#
##############################################################################

package Qiniu::Utils::Base64;

use strict;
use warnings;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
    base64_encode
    base64_decode
    base64_urlsafe_encode
    base64_urlsafe_decode
);

sub base64_encode {
    return &encode;
} # base64_encode

sub base64_decode {
    return &decode;
} # base64_decode

sub base64_urlsafe_encode {
    return &urlsafe_encode;
} # base64_urlsafe_encode

sub base64_urlsafe_decode {
    return &url_urlsafe_decode;
} # base64_urlsafe_decode

my $encode_impl = sub {
    my $buf     = shift;
    my $map     = shift;

    if (ref($buf) eq q{}) {
        $buf = [split("", $buf)];
    }

    my $buf_len = scalar(@$buf);
    if ($buf_len == 0) {
        return "", 0;
    }

    my $remainder   = $buf_len % 3;
    my $padding_len = ($remainder == 0) ? 0 : 3 - $remainder;

    my $ret = "";
    my $len = $buf_len + $padding_len;

    push @$buf, chr(0), chr(0);
    for (my $i = 0; $i < $len; $i += 3) {
        my $d1 = ord($buf->[$i + 0]);
        my $d2 = ord($buf->[$i + 1]);
        my $d3 = ord($buf->[$i + 2]);

        my $p1 = (($d1 >> 2) & 0x3F);
        my $p2 = (($d1 & 0x3) << 4) | (($d2 & 0xF0) >> 4);
        my $p3 = (($d2 & 0xF) << 2) | (($d3 & 0xC0) >> 6);
        my $p4 = ($d3 & 0x3F);

        my $c1 = $map->[$p1];
        my $c2 = $map->[$p2];
        my $c3 = $map->[$p3];
        my $c4 = $map->[$p4];

        if ($i + 1 == $buf_len) {
            $ret .= "${c1}${c2}";
            last;
        }
        if ($i + 2 == $buf_len) {
            $ret .= "${c1}${c2}${c3}";
            last;
        }
        $ret .= "${c1}${c2}${c3}${c4}";
    } # for

    return $ret, $padding_len;
}; # encode_impl

use constant FIRST  => 1;
use constant SECOND => 2;
use constant THIRD  => 3;
use constant FOURTH => 4;

my $decode_impl = sub {
    my $buf = shift;
    my $map = shift;

    if (ref($buf) eq q{}) {
        $buf = [split("", $buf)];
    }

    my $buf_len = scalar(@$buf);
    if ($buf_len == 0) {
        return "";
    }

    my $state = FIRST;
    my $chr = 0;
    my $ret = "";
    foreach my $code (@$buf) {
        my $val = $map->{$code};
        if ($state == FIRST) {
            $chr = ($val & 0x3F) << 2;
            $state = SECOND;
            next;
        }
        if ($state == SECOND) {
            $chr |= ($val & 0x30) >> 4;
            $ret .= chr($chr);
            $chr = ($val & 0xF) << 4;
            $state = THIRD;
            next;
        }
        if ($state == THIRD) {
            $chr |= ($val & 0x3C) >> 2;
            $ret .= chr($chr);
            $chr = ($val & 0x3) << 6;
            $state = FOURTH;
            next;
        };

        $chr |= ($val & 0x3F);
        $ret .= chr($chr);
        $state = FIRST;
    } # foreach

    return $ret;
}; # decode_impl

use constant ENCODE_MIME_MAP => [
    qw{A B C D E F G H I J K L M N O P Q R S T U V W X Y Z},
    qw{a b c d e f g h i j k l m n o p q r s t u v w x y z},
    qw{0 1 2 3 4 5 6 7 8 9},
    qw{+ /},
];

sub encode {
    my $buf = shift;
    my ($ret, $padding_len) = $encode_impl->($buf, ENCODE_MIME_MAP);
    $ret .= "=" x $padding_len;
    $ret =~ s/(.{76})/$1\r\n/g;
    return $ret;
} # encode

use constant DECODE_MIME_MAP => {
    "A" => 0,  "B" => 1,  "C" => 2,  "D" => 3,  "E" => 4,  "F" => 5,
    "G" => 6,  "H" => 7,  "I" => 8,  "J" => 9,  "K" => 10, "L" => 11,
    "M" => 12, "N" => 13, "O" => 14, "P" => 15, "Q" => 16, "R" => 17,
    "S" => 18, "T" => 19, "U" => 20, "V" => 21, "W" => 22, "X" => 23,
    "Y" => 24, "Z" => 25, "a" => 26, "b" => 27, "c" => 28, "d" => 29,
    "e" => 30, "f" => 31, "g" => 32, "h" => 33, "i" => 34, "j" => 35,
    "k" => 36, "l" => 37, "m" => 38, "n" => 39, "o" => 40, "p" => 41,
    "q" => 42, "r" => 43, "s" => 44, "t" => 45, "u" => 46, "v" => 47,
    "w" => 48, "x" => 49, "y" => 50, "z" => 51, "0" => 52, "1" => 53,
    "2" => 54, "3" => 55, "4" => 56, "5" => 57, "6" => 58, "7" => 59,
    "8" => 60, "9" => 61, "+" => 62, "/" => 63,
};

sub decode {
    my $str = shift;
    $str =~ s/[=]+$//;
    $str =~ s/\r\n//g;
    return $decode_impl->($str, DECODE_MIME_MAP);
} # decode

use constant ENCODE_URL_MAP => [
    qw{A B C D E F G H I J K L M N O P Q R S T U V W X Y Z},
    qw{a b c d e f g h i j k l m n o p q r s t u v w x y z},
    qw{0 1 2 3 4 5 6 7 8 9},
    qw{- _},
];

sub urlsafe_encode {
    my $buf = shift;
    my ($ret, $padding_len) = $encode_impl->($buf, ENCODE_URL_MAP);
    $ret .= "=" x $padding_len;
    return $ret;
} # urlsafe_encode

use constant DECODE_URL_MAP => {
    "A" => 0,  "B" => 1,  "C" => 2,  "D" => 3,  "E" => 4,  "F" => 5,
    "G" => 6,  "H" => 7,  "I" => 8,  "J" => 9,  "K" => 10, "L" => 11,
    "M" => 12, "N" => 13, "O" => 14, "P" => 15, "Q" => 16, "R" => 17,
    "S" => 18, "T" => 19, "U" => 20, "V" => 21, "W" => 22, "X" => 23,
    "Y" => 24, "Z" => 25, "a" => 26, "b" => 27, "c" => 28, "d" => 29,
    "e" => 30, "f" => 31, "g" => 32, "h" => 33, "i" => 34, "j" => 35,
    "k" => 36, "l" => 37, "m" => 38, "n" => 39, "o" => 40, "p" => 41,
    "q" => 42, "r" => 43, "s" => 44, "t" => 45, "u" => 46, "v" => 47,
    "w" => 48, "x" => 49, "y" => 50, "z" => 51, "0" => 52, "1" => 53,
    "2" => 54, "3" => 55, "4" => 56, "5" => 57, "6" => 58, "7" => 59,
    "8" => 60, "9" => 61, "-" => 62, "_" => 63,
};

sub urlsafe_decode {
    my $str = shift;
    $str =~ s/[=]+$//;
    return $decode_impl->($str, DECODE_URL_MAP);
} # urlsafe_decode

1;

__END__
