#!/usr/bin/perl
use strict;
use warnings;

use 5.010;

use WWW::Mechanize;
use HTML::TreeBuilder;
use XML::XPath;
use DB_File;
use Getopt::Long;

my $PAT =
    "http://www.paulnoll.com/Books/Clear-English/words-%02d-%02d-hundred.html";



sub get_url_direct {
    my ($url) = @_;

    state $mech ||= WWW::Mechanize->new(agent => 'jon');

    print STDERR "GET $url\n";
    $mech->get($url);
    $mech->is_html or die "Fatal: page $url not HTML\n";

    return $mech->content;
}

sub cache {
    state $cache ||= do {
        my %cache;
        if (my $bdb = tie %cache, 'DB_File', ".wordlist-url-cache.bdb") {
            $bdb->filter_fetch_value(sub { utf8::decode($_) });
            $bdb->filter_store_value(sub { utf8::encode($_) });
        } else {
            warn "Warning: tie: $!; using only in-memory cache\n";
        }
        \%cache;
    };
    return $cache;
}

sub get_url_cached {
    my ($url) = @_;
    my $cache = cache();
    return ($cache->{$url} ||= get_url_direct($url));
}

sub fetch_page {
    my ($idx) = @_;
    # Retrieve the page as HTML
    my $url = (sprintf $PAT, $idx, $idx+1);
    my $html = get_url_cached($url);
    # Convert to well-formed XML
    my $tree = HTML::TreeBuilder->new_from_content($html);
    my $xml = $tree->as_XML;
    $tree->delete;
    # Parse it
    utf8::encode($xml); # expat wants bytes
    my $parser = XML::Parser->new(ParseParamEnt => 0,
                                  ProtocolEncoding => 'UTF-8', # necessary
                                  ErrorContext => 1);
    my $xpath = XML::XPath->new(parser => $parser,  xml => $xml);
    return $xpath;
}

sub extract_words {
    my ($xroot, $wordarr) = @_;
    $wordarr ||= [];
    for my $li ($xroot->find('//ol/li')->get_nodelist) {
        my @items = $xroot->find('./child::node()', $li)->get_nodelist;
        @items == 1 and $items[0]->isa('XML::XPath::Node::Text')
                or die "List element doesn't have exactly one (text) body.\n";
        for (my $word = $items[0]->getData) {
            s/^\s+//; s/\s+$//;
            push @$wordarr, $word;
        }
    }
    return $wordarr;
}

sub filter_words {
    my ($in) = @_;
    my %words;
    my %excludes = map { $_ => 1 } qw(an and the 1/2 1/4);
    for (@$in) {
        next if /['. ]/;
        next if $excludes{$_};
        next unless length >= 3;
        $words{lc $_} ++;
    }
    my @words = sort keys %words;
    return \@words;
}

sub main {
    my @words_initial;
    for my $idx (1 .. 29) {
        next unless ($idx % 2 == 1); # each page is two word groups
        my $xp = fetch_page($idx);
        extract_words($xp, \@words_initial);
    }
    my $filtered = filter_words(\@words_initial);
    print "[\n", join(",\n", map "\"$_\"", @$filtered), "\n]\n";
}

main();
