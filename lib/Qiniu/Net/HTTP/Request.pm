#!/usr/bin/env perl

package Qiniu::Net::HTTP::Request;

use strict;
use warnings;

use Errno;

use Qiniu::Net::HTTP::Header;

use constant GET    => 'GET';
use constant POST   => 'POST';

use constant CRLF   => "\r\n";

my $new = sub {
    my $class   = shift || __PACKAGE__;
    my $url     = shift;
    my $headers = shift;
    my $body    = shift;
    my $method  = shift;
    my $self = {
        method  => $method,
        url     => $url,
        headers => $headers,
        body    => $body,

        url_line => "${method} ${url} HTTP/1.1" . CRLF,
    };

    return bless $self, $class;
}; # new

sub new_get {
    return $new->(@_, GET);
} # new_get

sub new_post {
    return $new->(@_, POST);
} # new_post

sub sending_headers {
    my $self = shift;

    my $new_headers = {};

    ### avoid to calculate the length many times
    my $content_length = $self->{headers}{'Content-Length'} || $self->{body}->size();
    if (defined($content_length) and $content_length > 0) {
        $new_headers->{'Content-Length'} = $content_length;
    }

    my $content_type = $self->{headers}{'Content-Type'} || $self->{body}->mime_type();
    if (defined($content_type) and $content_type ne q{}) {
        $new_headers->{'Content-Type'} = $content_type;
    } else {
        $new_headers->{'Content-Type'} = 'application/octet-stream';
    }

    return $self->{headers}->clone_and_merge($new_headers);
} # sending_headers

use constant ON_SEND_REQUEST_LINE  => 'on_send_request_line';
use constant ON_SEND_HEADERS       => 'on_send_headers';
use constant ON_SEND_BODY          => 'on_send_body';
use constant ON_SEND_STOP          => 'on_send_stop';

sub to_callback_handler {
    my $self = shift;

    my $req = {};
    $req->{headers}         = $self->sending_headers();
    $req->{url_line}        = $self->{url_line};
    $req->{url_line_off}    = 0;
    $req->{hdr_names}       = [ keys(%{$req->{headers}}) ];
    $req->{hdr_index}       = 0;
    $req->{phase}           = ON_SEND_REQUEST_LINE;

    $req->{on_send} = sub {
        my $fh       = shift;
        my $max_size = shift;

        if ($req->{phase} eq ON_SEND_STOP) {
            return 0, 0;
        }

        my $remainder_len = $max_size;

        if ($req->{phase} eq ON_SEND_REQUEST_LINE) {
            my $writing_size = length($req->{url_line}) - $req->{url_line_off};
            if ($writing_size > $remainder_len) {
                $writing_size = $remainder_len;
            }

            my $written_bytes = $fh->write(substr($req->{url_line}, $req->{url_line_off}, $writing_size));
            if ($written_bytes == -1) {
                if ($! == Errno::EAGAIN) {
                    ### cannot write data synchronously
                    return 0, $max_size - $remainder_len;
                }
                return -1, $max_size - $remainder_len;
            } elsif ($written_bytes == 0) {
                return 0, $max_size - $remainder_len;
            }

            $req->{url_line_off} += $written_bytes;
            $remainder_len -= $written_bytes;
            if ($req->{url_line_off} < length($req->{url_line})) {
                ### no more buffer to write url line in, return immediately
                return 0, $max_size - $remainder_len;
            }

            $req->{phase} = ON_SEND_HEADERS;
        } # ON_SEND_REQUEST_LINE

        if ($req->{phase} eq ON_SEND_HEADERS) {
            while ($req->{hdr_index} < scalar(@{$req->{hdr_names}})) {
                my $hdr = $req->{hdr_names}[$req->{hdr_index}];
                my $val = join ";", @{ $req->{headers}{$hdr} };
                my $hdr_line = "${hdr}: $val" . CRLF;

                if (length($hdr_line) > $remainder_len) {
                    ### no more buffer to write head line in, return immediately
                    return 0, $max_size - $remainder_len;
                }

                my $written_bytes = $fh->write($hdr_line);
                if ($written_bytes == -1) {
                    if ($! == Errno::EAGAIN) {
                        return 0, $max_size - $remainder_len;
                    }
                    return -1, $max_size - $remainder_len;
                } elsif ($written_bytes == 0) {
                    ### no more buffer to write head line in, return immediately
                    return 0, $max_size - $remainder_len;
                }

                $remainder_len -= length($hdr_line);
                $req->{hdr_index} += 1;
                if ($remainder_len == 0) {
                    ### no more buffer to write head line in, return immediately
                    return 0, $max_size - $remainder_len;
                }
            } # while

            $req->{phase} = ON_SEND_BODY;
        } # ON_SEND_HEADERS

        if ($req->{phase} eq ON_SEND_BODY) {
            my $written_bytes = $self->{body}->on_send($fh, $remainder_len);
            if ($written_bytes == -1) {
                if ($! == Errno::EAGAIN) {
                    ### no more buffer to write body in, return immediately
                    return 0, $max_size - $remainder_len;
                }
                return -1, $max_size - $remainder_len;
            } elsif ($written_bytes == 0) {
                ### no more buffer to write body in, return immediately
                $req->{phase} = ON_SEND_STOP;
                return 0, $max_size - $remainder_len;
            }

            $remainder_len -= $written_bytes;
            return 0, $max_size - $remainder_len;
        } # ON_SEND_BODY
    }; # on_send

    return $req;
} # to_callback_handler

1;

__END__
