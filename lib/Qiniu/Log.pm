#!/usr/bin/env perl

package Qiniu::Log;

use strict;
use warnings;

use IO::Handle;

### Setting module-dependent subroutines

my $get_timestamp = undef;
{
    require Time::HiRes;
    $get_timestamp = sub {
        my ($sec, $usec) = Time::HiRes::gettimeofday();
        my ($s, $m, $h, $D, $M, $Y) = localtime($sec);
        return sprintf(
            "%04d-%02d-%02d %02d:%02d:%02d.%06d",
            $Y + 1900,
            $M + 1,
            $D,
            $h,
            $m,
            $s,
            $usec,
        );
    };
}
if ($@) {
    $get_timestamp = sub {
        my ($s, $m, $h, $D, $M, $Y) = localtime(time());
        return sprintf(
            "%04d-%02d-%02d %02d:%02d:%02d",
            $Y + 1900,
            $M + 1,
            $D,
            $h,
            $m,
            $s,
        );
    };
}

### Define constants

use constant LOG_VERBOSE        => 0;
use constant LOG_DEBUG          => 1;
use constant LOG_INFO           => 2;
use constant LOG_WARN           => 3;
use constant LOG_ERROR          => 4;
use constant LOG_FATAL          => 5;

use constant LOG_VERBOSE_MARK   => '[VERBOSE]';
use constant LOG_DEBUG_MARK     => '[DEBUG]';
use constant LOG_INFO_MARK      => '[INFO]';
use constant LOG_WARN_MARK      => '[WARN]';
use constant LOG_ERROR_MARK     => '[ERROR]';
use constant LOG_FATAL_MARK     => '[FATAL]';

use constant LOG_DEFAULT_FORMAT => '%s';

### TODO: Output CRLF for Windows environment.
use constant LOG_LINE_SEPERATOR => "\n";

my $default_logger = undef;

my $printfs = sub {
    my $self        = shift;
    my $stack_level = shift;
    my $mark        = shift;
    my $format      = shift;

    my $timestamp   = $get_timestamp->();
    my (undef, $file, $line) = caller($stack_level);
    my $short_file = (split(/[\/\\]/, $file))[-1];

    printf {$self->{fh}} sprintf(
        "%s %s %s " . $format . LOG_LINE_SEPERATOR,
        $timestamp,
        "${short_file}:${line}",
        $mark,
        @_,
    );
}; # printfs

sub new {
    my $class = shift || __PACKAGE__;
    my $fh = shift;
    if (not defined($fh)) {
        $fh = IO::Handle->new_from_fd(STDERR->fileno(), "w");
    }
    if (-t $fh) {
        $fh->autoflush(1);
    }

    my $self = {
        fh          => $fh,
        threshold   => LOG_INFO,
    };

    return bless $self, $class;
} # new

$default_logger = new();

sub debug_f {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_DEBUG) {
        $printfs->($self, 1, LOG_DEBUG_MARK, @_);
    }
} # debug_f

sub debug {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_DEBUG) {
        $printfs->($self, 1, LOG_DEBUG_MARK, LOG_DEFAULT_FORMAT, @_);
    }
} # debug

sub info_f {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_INFO) {
        $printfs->($self, 1, LOG_INFO_MARK, @_);
    }
} # info_f

sub info {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_INFO) {
        $printfs->($self, 1, LOG_INFO_MARK, LOG_DEFAULT_FORMAT, @_);
    }
} # info

sub warn_f {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_WARN) {
        $printfs->($self, 1, LOG_WARN_MARK, @_);
    }
} # warn_f

sub warn {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_WARN) {
        $printfs->($self, 1, LOG_WARN_MARK, LOG_DEFAULT_FORMAT, @_);
    }
} # warn

sub error_f {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_ERROR) {
        $printfs->($self, 1, LOG_ERROR_MARK, @_);
    }
} # error_f

sub error {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_ERROR) {
        $printfs->($self, 1, LOG_ERROR_MARK, LOG_DEFAULT_FORMAT, @_);
    }
} # error

sub fatal_f {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_FATAL) {
        $printfs->($self, 1, LOG_FATAL_MARK, @_);
    }
} # fatal_f

sub fatal {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    if ($self->{threshold} <= LOG_FATAL) {
        $printfs->($self, 1, LOG_FATAL_MARK, LOG_DEFAULT_FORMAT, @_);
    }
} # fatal

sub set_threshold {
    my $self = (ref($_[0]) eq __PACKAGE__) ? shift : $default_logger;
    my $old_threshold = $self->{threshold};
    $self->{threshold} = shift;
    return $old_threshold;
} # set_threshold

1;

__END__
