#!/usr/bin/env perl

package Qiniu::Net::Http::Client;

use strict;
use warnings;

### package dependencies

use Errno;

use Qiniu::Utils::BufferBody;
use Qiniu::Utils::FileBody;

### constants

use constant CRLF => "\r\n";

use constant ON_WRITE_REQUEST_LINE  => 'on_write_request_line';
use constant ON_WRITE_HEADERS       => 'on_write_headers';
use constant ON_WRITE_BODY          => 'on_write_body';
use constant ON_WRITE_STOP          => 'on_write_stop';
use constant ON_READ_RESPONSE_LINE  => 'on_read_response_line';
use constant ON_READ_HEADERS        => 'on_read_headers';
use constant ON_READ_BODY           => 'on_read_body';

use constant MAX_BUFFER_BODY_SIZE   => 1 << 20;

### module methods

sub http_handler {
    my $url     = shift;
    my $method  = shift;
    my $header  = shift;
    my $body    = shift;

    my $req = {};
    my $res = {
        headers => {},
    };

    my $handler = {};
    $handler->{on_close} = sub {
        if (defined($res->{body})) {
            $res->{body}->rewind();
        }

        undef $req;
        undef $res;
    };

    # set up the on_write callback handler
    {
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
        $req->{headers} = $header->clone_and_merge($new_headers);

        $req->{url_line} = uc($method) . " ${url} HTTP/1.1" . CRLF;
        $req->{url_line_off} = 0;
        $req->{hdr_names} = [ keys(%{$req->{headers}}) ];
        $req->{hdr_index} = 0;
        $req->{phase} = ON_WRITE_REQUEST_LINE;

        $handler->{on_write} = sub {
            my $fd       = shift;
            my $max_size = shift;

            if ($req->{phase} eq ON_WRITE_STOP) {
                return 0;
            }

            my $remainder_len = $max_size;

            if ($req->{phase} eq ON_WRITE_REQUEST_LINE) {
                my $writing_size = length($req->{url_line}) - $req->{url_line_off};
                if ($writing_size > $remainder_len) {
                    $writing_size = $remainder_len;
                }

                my $written_bytes = $fd->write(substr($req->{url_line}, $req->{url_line_off}, $writing_size));
                if ($written_bytes == -1) {
                    if ($! == Errno::EAGAIN) {
                        return $max_size - $remainder_len;
                    }
                    return -1;
                }

                if ($written_bytes == 0) {
                    return $max_size - $remainder_len;
                }

                $req->{url_line_off} += $written_bytes;
                $remainder_len -= $written_bytes;
                if ($req->{url_line_off} < length($req->{url_line})) {
                    return $max_size - $remainder_len;
                }

                $req->{phase} = ON_WRITE_HEADERS;
            } # ON_WRITE_REQUEST_LINE

            if ($req->{phase} eq ON_WRITE_HEADERS) {
                while ($req->{hdr_index} < scalar(@{$req->{hdr_names}})) {
                    my $hdr = $req->{hdr_names}[$req->{hdr_index}];
                    my $val = join ";", @{ $req->{headers}{$hdr} };
                    my $hdr_line = "${hdr}: $val" . CRLF;

                    if (length($hdr_line) > $remainder_len) {
                        return $max_size - $remainder_len;
                    }

                    my $written_bytes = $fd->write($hdr_line);
                    if ($written_bytes == -1) {
                        if ($! == Errno::EAGAIN) {
                            return $max_size - $remainder_len;
                        }
                        return -1;
                    }

                    if ($written_bytes == 0) {
                        return $max_size - $remainder_len;
                    }

                    $remainder_len -= length($hdr_line);
                    $req->{hdr_index} += 1;
                    if ($remainder_len == 0) {
                        return $max_size - $remainder_len;
                    }
                } # while

                $req->{phase} = ON_WRITE_BODY;
            } # ON_WRITE_HEADERS

            if ($req->{phase} eq ON_WRITE_BODY) {
                my $written_bytes = $body->write($fd, $remainder_len);
                if ($written_bytes == -1) {
                    if ($! == Errno::EAGAIN) {
                        return $max_size - $remainder_len;
                    }
                    return -1;
                }

                if ($written_bytes == 0) {
                    $req->{phase} = ON_WRITE_STOP;
                    return $max_size - $remainder_len;
                }

                $remainder_len -= $written_bytes;
                return $max_size - $remainder_len;
            } # ON_WRITE_BODY
        }; # on_write
    } # set up the on_write callback handler

    # set up the on_read callback handler
    {
        my $remainder = "";
        $res->{phase} = ON_READ_RESPONSE_LINE;
        $handler->{on_read} = sub {
            my $fd = shift;
            my $data = "";
            my $total_read_bytes = 0;

            while (my $read_bytes = $fd->read(\$data, 8192)) {
                if ($read_bytes == -1) {
                    if ($! == Errno::EAGAIN) {
                        return $total_read_bytes;
                    }
                    return -1;
                }

                if ($read_bytes == 0) {
                    # no more data
                    return $total_read_bytes;
                }

                $remainder .= $data;
                $total_read_bytes += $read_bytes;

                if ($res->{phase} eq ON_READ_RESPONSE_LINE) {
                    if ($remainder =~ m,^HTTP/(\d+[.]\d+) +(\d{3}) +(.+)\r?\n$,mgc) {
                        $res->{version} = $1;
                        $res->{code}    = $2;
                        $res->{phrase}  = $3;

                        $res->{phase} = ON_READ_HEADERS;
                    } else {
                        next;
                    }
                } # ON_READ_RESPONSE_LINE

                if ($res->{phase} eq ON_READ_HEADERS) {
                    while ($remainder =~ m,^ *([^ :]+) *: *(.+?)\r?\n$,mgc) {
                        my $hdr = $1;
                        my $val = $2;

                        $res->{headers}{$hdr} = [ split(";", $val) ];

                        if ($hdr =~ m/^content-length$/i) {
                            if ($val =~ m/^ *(\d+) *$/) {
                                $res->{body_size} = $val + 0;
                                if ($res->{body_size} < MAX_BUFFER_BODY_SIZE) {
                                    $res->{body} = Qiniu::Utils::BufferBody->new($res->{body_size});
                                }
                            }
                        }
                    } # while

                    if ($remainder =~ m,^\r?\n$,mgc) {
                        $remainder = substr($remainder, 0, pos($remainder));
                        $res->{phase} = ON_READ_BODY;
                    } else {
                        $remainder = substr($remainder, 0, pos($remainder));
                        next;
                    }
                } # ON_READ_HEADERS

                if ($res->{phase} eq ON_READ_BODY) {
                    if (not defined($res->{body})) {
                        $res->{body} = Qiniu::Utils::FileBody->new();
                    }

                    $res->{body}->write($remainder);
                    $remainder = undef;
                } # ON_READ_BODY
            } # while
        }; # on_read
    } # set up the on_read callback handler

    return $handler, $req, $res;
} # http_handler

1;

__END__
