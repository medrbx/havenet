#! /usr/bin/perl

use strict ;
use warnings ;
use Data::Dumper ;

use Catmandu;
use Catmandu::Importer::SRU ;
use rbxrec::record ;

my %attrs = (
	base => "http://catalogue.bnf.fr/api/SRU",
    version => "1.2",
    query => "(aut.ark any \"ark:/12148/cb11910868w\")",
    recordSchema => "unimarcXchange",
    parser => "marcxml"
);
 
my $importer = Catmandu::Importer::SRU->new(%attrs) ;
my $fixer    = Catmandu->fixer(["marc_map(001,FRBNF)"]) ;
 $fixer->fix($importer)->each(sub {
    my $record = shift ;
    print Dumper($record) ;
});