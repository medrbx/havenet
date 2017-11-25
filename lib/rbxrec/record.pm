package rbxrec::record ;

use Exporter ;
@ISA = qw(Exporter) ;
@EXPORT = qw( GetBnfRecordsById IsBnfSruServerStatusError ModRecordsFile _GetBnfRecords _GetCatmanduFixer ) ;

use strict ;
use warnings ;
use List::MoreUtils qw(uniq);
use MARC::Batch ;
use Catmandu;
use Catmandu::Importer::SRU ;

use rbxrec::record::charset ;
use kibini::config ;
use kibini::time ;

sub GetBnfRecordsById {
    my ( $type_query, $idlist, $file_out ) = @_ ;
    
    my ($recordtype, $idtype) = split(/\./, $type_query) ;
    my (@ids) = uniq (split(/\n/, $idlist));
    chomp(@ids) ;
    
    my $nb_rec = scalar(@ids) ;
    my $nb_bnf_rec = 0 ;
    my $exporter = Catmandu->exporter( 'MARC', type => 'ISO', file => $file_out ); # XML ou ISO
    
    while ( my $id = <@ids> ) {
#    foreach my $id (@ids) { # foreach ne fonctionne pas... pq ?
        my $record = { $idtype => $id } ;
        if ( $idtype eq 'ark' ) {
            $record->{'ark'} =~ s/http\:\/\/catalogue\.bnf\.fr\/(.*)/$1/ ;
        }
        my @bnf_data = _GetBnfRecords($record, $recordtype, $idtype ) ;
        if ( defined $bnf_data[0] ) {
            my $record_bnf = $bnf_data[0] ;
            $record->{record} = $record_bnf->{record} ;
            $record->{ark_bnf} = $record_bnf->{ark_bnf} ;
            $record->{frbnf} = $record_bnf->{frbnf} ;
            $nb_bnf_rec++ ;
			my $fixer;
            if ( $recordtype eq 'bib' ) {
                $fixer = _GetCatmanduFixer( 'to_export_records', $record ) ;
            } elsif ( $recordtype eq 'aut' ) {
                $fixer = _GetCatmanduFixer( 'to_export_auth_records', $record ) ;
            }
            $exporter->add_many($fixer->fix($record));
        }     
    }
    
    return {
        nb_rec => $nb_rec,
        nb_bnf_rec => $nb_bnf_rec,
        ids => \@ids
    } ;
}

sub IsBnfSruServerStatusError {
    my $status_error = 1;
    my %options = ( agent => 'MEDRBX' ) ;
    my $ua = LWP::UserAgent->new( %options ) ;
    my $base = "http://catalogue.bnf.fr/api/SRU" ;
    my $req = HTTP::Request->new( GET => $base );
    my $res = $ua->request($req) ;
    if ( $res->is_success == 1 ) {
        $status_error = 0 ;
    }
    
    return $status_error ;
}

sub ModRecordsFile {
    my ( $file, $charset ) = @_ ;
    
    my $nb_rec = 0 ;
    my $nb_bnf_rec = 0 ;
        
    if ( $charset ne 'UTF-8' ) {
        $file->{file_in} = _ModFileFromIso5426ToUtf8($file->{file_in}, $charset);
    }

    my $importer = Catmandu->importer( 'MARC', type => 'RAW', file => $file->{file_in} );
    my $exporter = Catmandu->exporter( 'MARC', type => 'ISO', file => $file->{file_out} ); # XML ou ISO
   
    my $fixer = _GetCatmanduFixer( 'to_parse_input' ) ;
    $fixer->fix($importer)->each(sub {
        my $record = shift;
        $nb_rec++ ;
        if ( $record->{ean} ) {
            my @bnf_data = _GetBnfRecords($record, 'bib', 'ean') ;
            if ( defined $bnf_data[0] ) {
                my $record_bnf = $bnf_data[0] ;
                $record->{record} = $record_bnf->{record} ;
                $record->{ark_bnf} = $record_bnf->{ark_bnf} ;
                $record->{frbnf} = $record_bnf->{frbnf} ;
                $nb_bnf_rec++ ;
            }
        }   
    
        my $fixer = _GetCatmanduFixer( 'to_export_records', $record ) ;
        $exporter->add_many($fixer->fix($record));
    });

    return {
        nb_rec => $nb_rec,
        nb_bnf_rec => $nb_bnf_rec
    } ;
    
}

sub _GetBnfRecords {
    my ($record, $recordtype, $idtype ) = @_ ;
    my $sruquery = _GetSruQuery( $recordtype, $idtype, $record->{$idtype} ) ;

    my %attrs = (
        base => "http://catalogue.bnf.fr/api/SRU",
        version => "1.2",
        query => $sruquery,
        recordSchema => "unimarcXchange",
        parser => "marcxml"
    );
    my $importer = Catmandu::Importer::SRU->new(%attrs) ;
    
    my @bnf_data ;
    my %result ;
    my $fixer = _GetCatmanduFixer( 'to_parse_bnf' ) ;          
    $fixer->fix($importer)->each(sub {
        my $record_bnf = shift ;
        push @bnf_data, $record_bnf ;
    });

    return @bnf_data ;
}

sub _GetCatmanduFixer {
    my ( $to_do, $record ) = @_ ;
    
    my $fixer ;
    if ( $to_do eq 'to_parse_input' ) {
        my @fix = (
            "marc_remove('9..')",
            "marc_map(073a,ean)",
            "marc_map(330a,summary)",
            "retain(_id, ean, summary, record)"
        ) ;
        $fixer = Catmandu->fixer(\@fix);    
    } elsif ( $to_do eq 'to_parse_bnf' ) {
        my @fix = (
            "marc_map(001,frbnf)",
            "marc_map(003,ark_bnf)",
            "marc_remove('9..')"
        ) ;
        $fixer = Catmandu->fixer(\@fix);    
    } elsif ( $to_do eq 'to_export_records' ) {
        my @fix = (
            "marc_remove('003')"
        ) ;
        push @fix, "marc_add('033', ind1 , ' ' , ind2 , ' ' , a, \"$record->{ark_bnf}\")" if ( defined $record->{ark_bnf} ) ;
        push @fix, "marc_add('035', ind1 , ' ' , ind2 , ' ' , a, \"$record->{frbnf}\")" if ( defined $record->{frbnf} ) ;
        if ( defined $record->{summary} && defined $record->{ark_bnf} ) {
            push @fix, "marc_remove('330')" ;
            $record->{summary} =~ s/"/\\"/g ;
            push @fix, "marc_add('330', ind1 , ' ' , ind2 , ' ' , a, \"$record->{summary}\")" ;
        }
        $fixer = Catmandu->fixer(\@fix);    
    } elsif ( $to_do eq 'to_export_auth_records' ) {
        my @fix = (
            "marc_remove('003')",
			"marc_remove('2..789')"
        ) ;
        push @fix, "marc_add('009', ind1 , ' ' , ind2 , ' ' , a, \"$record->{ark_bnf}\")" if ( defined $record->{ark_bnf} ) ; # Non conforme à l'unimarc/A, mais pour le moment on fait comme ça.
        if ( defined $record->{frbnf} ) {
            push @fix, "marc_add('035', ind1 , ' ' , ind2 , ' ' , a, \"$record->{frbnf}\")";
            my $frbnf_number = substr $record->{frbnf}, 5;
            push @fix, "marc_add('999', ind1 , ' ' , ind2 , ' ' , a, $frbnf_number)";
        }
        $fixer = Catmandu->fixer(\@fix);    
    }
    
    return $fixer ;
}

sub _GetSruQuery {
    my ( $recordtype, $idtype, $id ) = @_ ;
    
    my $query ;
    if ($recordtype eq 'aut') {
        $query = '(' . $recordtype . '.' . $idtype . ' any "' . $id . '")' ;
    } elsif ($recordtype eq 'bib') {
        $query = '(' . $recordtype . '.' . $idtype . ' any "' . $id . '")' ;
    }
    
    return $query ;
}

sub _ModFileFromIso5426ToUtf8 {
    my ($file, $charset) = @_ ;

    my @records ;
    my $batch = MARC::Batch->new( 'USMARC', $file );
    while ( my $record = $batch->next ) {
        my @resp = MarcToUTF8Record($record, 'UNIMARC', $charset) ; #'ISO-5426');
        $record = MARC::File::USMARC->encode($record) ;
        push @records, $record ;
    }
    
    open(my $fh, '>:encoding(UTF-8)', $file) or die "Could not open file '$file' $!";
    foreach my $rec (@records) {
        print $fh $rec ;
    }
    close $fh ;
    
    return $file ;
}

1;