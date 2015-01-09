#!/usr/bin/env perl

package Qiniu::Utils::Misc;

use strict;
use warnings;

use English;

use constant OS_LINUX   => 'linux';
use constant OS_WIN     => 'windows';
use constant OS_MAC     => 'mac_os_x';
use constant OS_UNKNOWN => 'unknown_os';

sub os_version {
    my $osname = lc($OSNAME);
    if ($osname eq 'linux') {
        return OS_LINUX;
    }
    if ($osname eq 'mswin32') {
        return OS_WIN;
    }
    if ($osname eq 'darwin') {
        return OS_MAC;
    }
    return OS_UNKNOWN;
} # os_version

1;

__END__
