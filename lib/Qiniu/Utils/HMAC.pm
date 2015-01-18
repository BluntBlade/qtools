#!/usr/bin/env perl

##############################################################################
#
# Wiki:   http://en.wikipedia.org/wiki/Hash-based_message_authentication_code
#
##############################################################################

package Qiniu::Utils::HMAC;

use strict;
use warnings;

sub new {
    my $class      = shift || __PACKAGE__;
    my $hash       = shift;
    my $secret_key = shift;
    my $self = {
        hash              => $hash,
        origin_secret_key => $secret_key,
    };
    bless $self, $class;

    my $block_size = $hash->chunk_size();

    # Don't extract the length of the secret key since it would be changed
    if (length($secret_key) > $block_size) {
        $secret_key = $hash->reset()->sum($secret_key);
        $hash->reset();
    }
    if (length($secret_key) < $block_size) {
        $secret_key .= "\x0" x ($block_size - length($secret_key));
    }
    $self->{calc_secret_key} = $secret_key;

    $self->{o_key_pad} = ("\x5C" x $block_size) ^ $secret_key;
    $self->{i_key_pad} = ("\x36" x $block_size) ^ $secret_key;

    $self->reset();
    return $self;
} # new

sub write {
    my $self = shift;
    my $msg  = shift;
    $self->{hash}->write($msg);
    return $self;
} # write

sub sum {
    my $self = shift;
    my $msg  = shift;
    my $i_hash = $self->{hash}->sum($msg);
    return $self->{hash}->reset()->sum($self->{o_key_pad} . $i_hash);
} # sum

sub reset {
    my $self = shift;
    $self->{hash}->reset()->write($self->{i_key_pad});
    return $self;
} # reset

1;

__END__
