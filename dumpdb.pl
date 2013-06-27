#!/usr/bin/perl
use strict;
use warnings;

use DB_File;

my ($file, $key) = @ARGV;
@ARGV == 1 or @ARGV == 2
    or die "Usage: $0 file [key]\n";

my %db;
tie %db, DB_File => $file
    or die "dbopen $file: $!\n";

if (defined $key) {
    binmode STDOUT;
    print $db{$key};
} else {
    while (my $k = each %db) {
        print $k, "\n";
    }
}

