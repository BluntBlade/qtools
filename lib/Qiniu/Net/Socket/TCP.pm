#!/usr/bin/env perl

package Qiniu::Net::Socket::TCP;

use strict;
use warnings;

use Socket;

sub new {
    my $class = shift || __PACKAGE__;
    my $host = shift;
    my $port = shift;

    my $fd = undef;
    socket($fd, PF_INET, SOCK_STREAM, getprotobyname("tcp")) or die "$!";

    if ($port =~ /\D/) {
        $port = getservbyname($port, "tcp")
    }
    die "No such port" unless $port;

    my $self = {
        host => $host,
        port => $port,
        fd   => $fd,
    };

    return bless $self, $class;
} # new

sub connect {
    my $self = shift;
    my $iaddr = inet_aton($self->{host});
    my $paddr = sockaddr_in($self->{port}, $iaddr);
    my $done = connect($self->{fd}, $paddr);
    if (not $done) {
        return "$!";
    }
    return "";
} # connect

sub close {
    my $self = shift;
    if (not defined($self->{fd})) {
        return "Socket is not initiated yet";
    } elsif ($self->{fd} < 0) {
        return "Socket has been closed";
    }
    close($self->{fd});
    $self->{fd} = -1;
    return "";
} # close

sub send {
    my $self = shift;
    my $data = shift;
    my $sent_bytes = send($self->{fd}, $data, 0);
    if (not defined($sent_bytes)) {
        return "$!", 0;
    }
    return "", $sent_bytes;
} # send

sub receive {
    my $self = shift;
    my $data = shift;
    my $receiving_bytes = shift;
    if (not defined($receiving_bytes) or ($receiving_bytes ^ $receiving_bytes eq q{}) or ($receiving_bytes <= 0)) {
        $receiving_bytes = 8192;
    }
    my $paddr = recv($self->{fd}, $$data, $receiving_bytes, 0);
    if (not defined($paddr)) {
        return "$!", 0;
    }
    return "", length($data);
} # receive

1;

__END__
