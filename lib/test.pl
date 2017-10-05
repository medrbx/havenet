#! /usr/bin/perl

use strict ;
use warnings ;
use Data::Dumper ;
use List::MoreUtils qw(uniq);
use FindBin qw( $Bin );

use lib "$Bin";
use rbxrec::record ;

my $type_query = 'bib.ean' ;
my $idlist = "9782035901415 9782321010623 9782321011095 9782759034925 9782200613426 9782759035083 9791092953657 9791092953626 9782843931970 9782312050188 9782955288900 9782954583105 9782843931956 9782843931987 9782754734363 9782334236553 3782958605908 3782910904902 3782958203906" ;



#sub GetBnfRecordsById {
#	my ( $type_query, $idlist ) = @_ ;
	
	my ($recordtype, $idtype) = split(/\./, $type_query) ;
	my (@ids) = uniq (split(/\s/, $idlist));
	
	my $nb_rec = scalar(@ids) ;
	my $nb_bnf_rec = 0 ;
	
	my $exporter = Catmandu->exporter( 'MARC', type => 'ISO', file => "/home/kibini/rbxrec/public/record/out/test_ean.mrc" ); #$file->{file_out} ); # XML ou ISO
	
	foreach my $id (@ids) {
		my $record = { $idtype => $id } ;
		my @bnf_data = _GetBnfRecords($record, $recordtype, $idtype ) ;
		if ( defined $bnf_data[0] ) {
			my $record_bnf = $bnf_data[0] ;
			$record->{record} = $record_bnf->{record} ;
			$record->{ark_bnf} = $record_bnf->{ark_bnf} ;
			$record->{frbnf} = $record_bnf->{frbnf} ;
			$nb_bnf_rec++ ;
			my $fixer = _GetCatmanduFixer( 'to_export_records', $record ) ;
			$exporter->add_many($fixer->fix($record));
			#print Dumper($exporter) ;
		}
		    
        
		
	}
	
	my $stat = {
        nb_rec => $nb_rec,
        nb_bnf_rec => $nb_bnf_rec
    } ;
	
	print Dumper($stat) ;
#}