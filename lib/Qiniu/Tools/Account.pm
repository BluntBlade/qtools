#!/usr/bin/env perl

package Qiniu::Tools::Account;

use strict;
use warnings;
use errno;

use constant HOME_NAME => '.qtools';

my $get_home_dir = sub {
    my $identity = shift;
    return "$ENV{HOME}/" . HOME_NAME . "/${identity}";
}; # get_home_dir

my $make_path = undef;
eval {
    require File::Path;

    $make_path = sub {
        if (-d $_[0]) {
            return 1;
        }
        return &File::Path::make_path;
    }
};
if ($@) {
    $make_path = sub {
        my $pathname = shift;
        my $opts     = shift || {};

        if (-d $pathname) {
            return 1;
        }

        my $super_pathname = $pathname;
        if ($super_pathname =~ m{/$}) {
            $super_pathname =~ s{[^/]+/$}{};
        } else {
            $super_pathname =~ s{/[^/]+$}{};
        }

        my $ret = $make_path->($super_pathname, $opts);
        if (not $ret) {
            return undef;
        }

        my $perm = $opts->{mask} || 0700;
        $ret = mkdir $pathname, $perm;
        if (not $ret) {
            return undef;
        }
        return 1;
    }; # make_path
} # for loading File::Path

sub make_home {
    my $identity = shift;

    my $ret = $make_path->($get_home_dir->($identity), {
        mask => 0700,
    });
    if (not $ret) {
        return "Failed to create home directory for qtools: $!";
    }

    return '';
} # make_home

sub save_keys {
    my $identity    = shift;
    my $access_key  = shift;
    my $secret_key  = shift;

    my $filename = $get_home_dir->($identity) . "/keys";
    my $old_umask = umask 0077;
    my $ret = open my $fd, ">", $filename;
    my $err = "$!";
    umask $old_umask;
    if (not $ret) {
        return "Failed to create keys file: $err";
    }

    $ret = printf $fd "%s:%s\n", $access_key, $secret_key;
    if (not $ret) {
        return "Failed to write to keys file: $!";
    }

    close $fd;
    return '';
} # save_keys

sub load_keys {
    my $identity = shift;

    my $filename = $get_home_dir->($identity) . "/keys";
    my $ret = open my $fd, "<", $filename;
    if (not $ret) {
        return undef, undef, "Failed to open keys file: $!";
    }

    my $line = <$fd>;
    close($fd);

    chomp $line;
    my ($access_key, $secret_key) = $line =~ m/^(.+?):(.+?)$/;
    return $access_key, $secret_key, '';
} # load_keys

1;
