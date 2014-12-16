#!/usr/bin/env perl

package Qiniu::Net::Http::Client;

use strict;
use warnings;

use Errno;

use constant CRLF => "\r\n";

### module methods

use constant ON_WRITE_REQUEST   => 'on_write_request';
use constant ON_WRITE_HEADER    => 'on_write_header';
use constant ON_WRITE_BODY      => 'on_write_body';
use constant ON_WRITE_STOP      => 'on_write_stop';

sub post_handler {
    my $url     = shift;
    my $header  = shift;
    my $body    = shift;

    my $new_headers = {};

    ### avoid to calculate the length many times
    my $content_length = $body->size();
    if (defined($content_length) and $content_length > 0) {
        $new_headers->{'Content-Length'} = $content_length;
    }

    my $content_type = $body->mime_type();
    if (defined($content_type)) {
        $new_headers->{'Content-Type'} = $content_type;
    } else {
        $new_headers->{'Content-Type'} = 'application/octet-stream';
    }

    ### merge headers passed by caller and override default ones
    my $final_headers = $header->clone_and_merge($new_headers);

    my $url_line = "POST ${url} HTTP/1.1" . CRLF;
    my $url_off = 0;
    my $hdr_nms = [ keys(%$final_headers) ];
    my $hdr_idx = 0;
    my $on_write_phase = ON_WRITE_REQUEST;

    my $handler = {};
    $handler->{on_close} = sub {
        undef $url_line;
        undef $final_headers;
        undef $hdr_nms;
    };

    $handler->{on_write} = sub {
        my $fd       = shift;
        my $max_size = shift;

        if ($on_write_phase eq ON_WRITE_STOP) {
            return 0;
        }

        my $remainder = $max_size;

        if ($on_write_phase eq ON_WRITE_REQUEST) {
            my $writing_size = length($url_line) - $url_off;
            if ($writing_size > $remainder) {
                $writing_size = $remainder;
            }

            my $written_bytes = $fd->write(substr($url_line, $url_off, $writing_size));
            if ($written_bytes == -1) {
                if ($! == Errno::EAGAIN) {
                    return $max_size - $remainder;
                }
                return -1;
            }

            if ($written_bytes == 0) {
                return $max_size - $remainder;
            }

            $url_off += $written_bytes;
            $remainder -= $written_bytes;
            if ($url_off < length($url_line)) {
                return $max_size - $remainder;
            }

            $on_write_phase = ON_WRITE_HEADER;
        } # ON_WRITE_REQUEST

        if ($on_write_phase eq ON_WRITE_HEADER) {
            while ($hdr_idx < scalar(@$hdr_nms)) {
                my $hdr = $hdr_nms->[$hdr_idx];
                my $val = join ";", @{ $final_headers->{$hdr} };
                my $hdr_line = "${hdr}: $val" . CRLF;

                if (length($hdr_line) > $remainder) {
                    return $max_size - $remainder;
                }

                my $written_bytes = $fd->write($hdr_line);
                if ($written_bytes == -1) {
                    if ($! == Errno::EAGAIN) {
                        return $max_size - $remainder;
                    }
                    return -1;
                }

                if ($written_bytes == 0) {
                    return $max_size - $remainder;
                }

                $remainder -= length($hdr_line);
                $hdr_idx += 1;
                if ($remainder == 0) {
                    return $max_size - $remainder;
                }
            } # while

            $on_write_phase = ON_WRITE_BODY;
        } # ON_WRITE_HEADER

        if ($on_write_phase eq ON_WRITE_BODY) {
            my $written_bytes = $body->write($fd, $remainder);
            if ($written_bytes == -1) {
                if ($! == Errno::EAGAIN) {
                    return $max_size - $remainder;
                }
                return -1;
            }

            if ($written_bytes == 0) {
                $on_write_phase = ON_WRITE_STOP;
                return $max_size - $remainder;
            }

            $remainder -= $written_bytes;
            return $max_size - $remainder;
        } # ON_WRITE_BODY
    };

    return $handler;
} # post_handler

1;

__END__
