#!/usr/bin/env perl

package Qiniu::Net::HTTP::RequestBody;

use strict;
use warnings;

use Errno;

use Qiniu::Net::HTTP::BufferBody;
use Qiniu::Net::HTTP::FileBody;

sub new {
    my $class = shift || __PACKAGE__;
    my $body = shift;
    my $self = {};

    my $ref = ref($body);
    if ($body eq 'Qiniu::Net::HTTP::BufferBody' || $body eq 'Qiniu::Net::HTTP::FileBody') {
        $self->{body} = $body;
    } elsif ($body eq 'IO::File' || $body eq 'IO::Handle') {
        $self->{body} = Qiniu::Net::HTTP::FileBody->new_for_read($body);
    } elsif ($body eq q{} || $body eq q{SCALAR}) {
        $self->{body} = Qiniu::Net::HTTP::BufferBody->new_for_read($body);
    }

    return bless $self, $class;
} # new

sub on_send {
    my $self        = shift;
    my $fh          = shift;
    my $max_size    = shift;

    my $data = undef;
    my $read_bytes = $self->{body}->peek(\$data, $max_size);
    if ($read_bytes == -1) {
        if ($! == Errno::EAGAIN) {
            ### read data next time
            return 0, 0;
        }
        ### an error occured, no data read
        return -1, 0;
    } elsif ($read_bytes == 0) {
        ### reach the end of the body
        return 0, 0;
    }

    my $written_bytes = $fh->write($data, $read_bytes);
    if ($written_bytes == -1) {
        if ($! == Errno::EAGAIN) {
            ### write data next time
            return 0, 0;
        }
        ### an error occured, no data wrote
        return -1, 0;
    } elsif ($written_bytes == 0) {
        ### no data wrote
        return 0, 0;
    }

    $self->{body}->advance($written_bytes);
    return 0, $written_bytes;
} # on_send

1;

__END__
