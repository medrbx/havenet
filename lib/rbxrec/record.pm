package rbxrec::record;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( GetBnfRecordsById IsBnfSruServerStatusError ModRecordsFile _GetBnfRecords _GetCatmanduFixer );

use strict;
use warnings;
use List::MoreUtils qw(uniq);
use MARC::Batch;
use Catmandu;
use Catmandu::Importer::SRU;

use rbxrec::record::charset;
use kibini::config;
use kibini::time;

sub GetBnfRecordsById {
    my ( $type_query, $idlist, $file_out ) = @_;
    
    my ($recordtype, $idtype) = split(/\./, $type_query);
    my (@ids) = uniq (split(/\n/, $idlist));
    chomp(@ids);
    
    my $nb_rec = scalar(@ids);
    my $nb_bnf_rec = 0;
    my $exporter = Catmandu->exporter( 'MARC', type => 'ISO', file => $file_out ); # XML ou ISO
    
    while ( my $id = <@ids> ) {
#    foreach my $id (@ids) { # foreach ne fonctionne pas... pq ?
        my $record = { $idtype => $id };
        if ( $idtype eq 'persistentid' ) {
            $record->{'ark'} =~ s/http\:\/\/catalogue\.bnf\.fr\/(.*)/$1/;
        }
        my @bnf_data = _GetBnfRecords($record, $recordtype, $idtype );
        if ( defined $bnf_data[0] ) {
            my $record_bnf = $bnf_data[0];
            $record->{record} = $record_bnf->{record};
            $record->{ark_bnf} = $record_bnf->{ark_bnf};
            $record->{frbnf} = $record_bnf->{frbnf};
            $record->{f210} = $record_bnf->{f210};
            $record->{f219} = $record_bnf->{f219};
            $nb_bnf_rec++;
            my $fixer;
            if ( $recordtype eq 'bib' ) {
                $fixer = _GetCatmanduFixer( 'to_export_records', $record );
            } elsif ( $recordtype eq 'aut' ) {
                $fixer = _GetCatmanduFixer( 'to_export_auth_records', $record );
            }
            $exporter->add_many($fixer->fix($record));
        }     
    }
    
    return {
        nb_rec => $nb_rec,
        nb_bnf_rec => $nb_bnf_rec,
        ids => \@ids
    };
}

sub IsBnfSruServerStatusError {
    my $status_error = 1;
    my %options = ( agent => 'MEDRBX' );
    my $ua = LWP::UserAgent->new( %options );
    my $base = "http://catalogue.bnf.fr/api/SRU";
    my $req = HTTP::Request->new( GET => $base );
    my $res = $ua->request($req);
    if ( $res->is_success == 1 ) {
        $status_error = 0;
    }
    
    return $status_error;
}

sub ModRecordsFile {
    my ( $file, $charset ) = @_;
    
    my $nb_rec = 0;
    my $nb_bnf_rec = 0;
        
    if ( $charset ne 'UTF-8' ) {
        $file->{file_in} = _ModFileFromIso5426ToUtf8($file->{file_in}, $charset);
    }

    my $importer = Catmandu->importer( 'MARC', type => 'RAW', file => $file->{file_in} );
    my $exporter = Catmandu->exporter( 'MARC', type => 'ISO', file => $file->{file_out} ); # XML ou ISO
   
    my $fixer = _GetCatmanduFixer( 'to_parse_input' );
    $fixer->fix($importer)->each(sub {
        my $record = shift;
        $nb_rec++;
        if ( $record->{ean} ) {
            my @bnf_data = _GetBnfRecords($record, 'bib', 'ean');
            if ( defined $bnf_data[0] ) {
                my $record_bnf = $bnf_data[0];
                $record->{record} = $record_bnf->{record};
                $record->{ark_bnf} = $record_bnf->{ark_bnf};
                $record->{frbnf} = $record_bnf->{frbnf};
                #$record->{f210} = $record_bnf->{f210};
                #$record->{f219} = $record_bnf->{f219};
                $nb_bnf_rec++;
            }
        }   
    
        my $fixer = _GetCatmanduFixer( 'to_export_records', $record );
        $exporter->add_many($fixer->fix($record));
    });

    return {
        nb_rec => $nb_rec,
        nb_bnf_rec => $nb_bnf_rec
    };
    
}

sub _GetBnfRecords {
    my ($record, $recordtype, $idtype ) = @_;
    my $sruquery = _GetSruQuery( $recordtype, $idtype, $record->{$idtype} );

    my %attrs = (
        base => "http://catalogue.bnf.fr/api/SRU",
        version => "1.2",
        query => $sruquery,
        recordSchema => "unimarcXchange",
        parser => "marcxml"
    );
    my $importer = Catmandu::Importer::SRU->new(%attrs);
    
    my @bnf_data;
    my %result;
    my $fixer = _GetCatmanduFixer( 'to_parse_bnf' );          
    $fixer->fix($importer)->each(sub {
        my $record_bnf = shift;
        push @bnf_data, $record_bnf;
    });

    return @bnf_data;
}

sub _GetCatmanduFixer {
    my ( $to_do, $record ) = @_;
    
    my $fixer;
    if ( $to_do eq 'to_parse_input' ) {
        my @fix = (
            "marc_remove('9..')",
            "marc_map(073a,ean)",
            "marc_map(330a,summary)",
            "retain(_id, ean, summary, record)"
        );
        $fixer = Catmandu->fixer(\@fix);    
    } elsif ( $to_do eq 'to_parse_bnf' ) {
        my @fix = (
            "marc_map(001,frbnf)",
            "marc_map(003,ark_bnf)",
            "marc_remove('9..')",
            "marc_copy(214, f214)",
            "set_field(f214.0.tag , 210)",
            "marc_paste(f214.0)"
 #           "marc_map(219, c219) if exists(c219) marc_map(210, c210) if exists(c210) marc_map(210a, f210.a) marc_map(210b, f210.b) marc_map(210c, f210.c) marc_map(210d, f210.d) marc_map(210e, f210.e) marc_map(210f, f210.f) marc_map(210g, f210.g) marc_map(210h, f210.h) marc_map(210r, f210.r) marc_map(210s, f210.s) end marc_map(219a, f219.a) marc_map(219b, f219.b) marc_map(219c, f219.c) marc_map(219d, f219.d) marc_map(219i, f219.i) marc_map(219p, f219.p) end"
        );        
        $fixer = Catmandu->fixer(\@fix);    
    } elsif ( $to_do eq 'to_export_records' ) {
        my @fix = (
            "marc_remove('003')"
        );
        push @fix, "marc_add('033', ind1 , ' ' , ind2 , ' ' , a, \"$record->{ark_bnf}\")" if ( defined $record->{ark_bnf} );
        push @fix, "marc_add('035', ind1 , ' ' , ind2 , ' ' , a, \"$record->{frbnf}\")" if ( defined $record->{frbnf} );
        
#        if ( $record->{f219} ) {
#            my $fix_new_210 = _GetFix210($record);
#            push @fix, "marc_remove('210')";
#            push @fix, $fix_new_210;
#        }
        
        if ( defined $record->{summary} && defined $record->{ark_bnf} ) {
            push @fix, "marc_remove('330')";
            $record->{summary} =~ s/"/\\"/g;
            push @fix, "marc_add('330', ind1 , ' ' , ind2 , ' ' , a, \"$record->{summary}\")";
        }
 
       $fixer = Catmandu->fixer(\@fix);
       
       
    } elsif ( $to_do eq 'to_export_auth_records' ) {
        my @fix = (
            "marc_remove('003')",
            "marc_remove('2..789')"
        );
        push @fix, "marc_add('009', ind1 , ' ' , ind2 , ' ' , a, \"$record->{ark_bnf}\")" if ( defined $record->{ark_bnf} ); # Non conforme à l'unimarc/A, mais pour le moment on fait comme ça.
        if ( defined $record->{frbnf} ) {
            push @fix, "marc_add('035', ind1 , ' ' , ind2 , ' ' , a, \"$record->{frbnf}\")";
            my $frbnf_number = substr $record->{frbnf}, 5;
            push @fix, "marc_add('999', ind1 , ' ' , ind2 , ' ' , a, $frbnf_number)";
        }
        $fixer = Catmandu->fixer(\@fix);    
    }
    
    return $fixer;
}

sub _GetSruQuery {
    my ( $recordtype, $idtype, $id ) = @_;
    
    my $query;
    if ($recordtype eq 'aut') {
        $query = '(' . $recordtype . '.' . $idtype . ' any "' . $id . '")';
    } elsif ($recordtype eq 'bib') {
        $query = '(' . $recordtype . '.' . $idtype . ' any "' . $id . '")';
    }
    
    return $query;
}

sub _ModFileFromIso5426ToUtf8 {
    my ($file, $charset) = @_;

    my @records;
    my $batch = MARC::Batch->new( 'USMARC', $file );
    while ( my $record = $batch->next ) {
        my @resp = MarcToUTF8Record($record, 'UNIMARC', $charset); #'ISO-5426');
        $record = MARC::File::USMARC->encode($record);
        push @records, $record;
    }
    
    open(my $fh, '>:encoding(UTF-8)', $file) or die "Could not open file '$file' $!";
    foreach my $rec (@records) {
        print $fh $rec;
    }
    close $fh;
    
    return $file;
}

sub _GetFix210 {
    my ($record) = @_;
     
    my $fix_new_210 = "marc_add('210', ind1, ' ', ind2, ' '";

    if ( $record->{f210}->{a} ) {
        $record->{f210}->{a} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", a, \"" . $record->{f210}->{a} . "\"";
    } elsif  ( $record->{f219}->{a} ) {
        $record->{f219}->{a} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", a, \"" . $record->{f219}->{a} . "\"";
    }

    if ( $record->{f210}->{b} ) {
        $record->{f210}->{b} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", b, \"" . $record->{f210}->{b} . "\"";
    } elsif  ( $record->{f219}->{b} ) {
        $record->{f219}->{b} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", b, \"" . $record->{f219}->{b} . "\"";
    }

    if ( $record->{f210}->{c} ) {
        $record->{f210}->{c} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", c, \"" . $record->{f210}->{c} . "\"";
    } elsif  ( $record->{f219}->{c} ) {
        $record->{f219}->{c} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", c, \"" . $record->{f219}->{c} . "\"";
    }

    if ( $record->{f210}->{d} ) {
        $record->{f210}->{d} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", d, \"" . $record->{f210}->{d} . "\"";
    } elsif  ( $record->{f219}->{d} ) {
        $record->{f219}->{d} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", d, \"" . $record->{f219}->{d} . "\"";
    } elsif  ( $record->{f219}->{i} ) {
        $record->{f219}->{i} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", d, \"" . $record->{f219}->{i} . "\"";
    } elsif  ( $record->{f219}->{p} ) {
        $record->{f219}->{p} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", d, \"" . $record->{f219}->{p} . "\"";
    }

    if ( $record->{f210}->{e} ) {
        $record->{f210}->{e} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", e, \"" . $record->{f210}->{e} . "\"";
    }

    if ( $record->{f210}->{f} ) {
        $record->{f210}->{f} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", f, \"" . $record->{f210}->{f} . "\"";
    }

    if ( $record->{f210}->{g} ) {
        $record->{f210}->{g} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", g, \"" . $record->{f210}->{g} . "\"";
    }

    if ( $record->{f210}->{h} ) {
        $record->{f210}->{h} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", h, \"" . $record->{f210}->{h} . "\"";
    }

    if ( $record->{f210}->{r} ) {
        $record->{f210}->{r} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", r, \"" . $record->{f210}->{r} . "\"";
    }

    if ( $record->{f210}->{s} ) {
        $record->{f210}->{s} =~ s/"//g;
        $fix_new_210 = $fix_new_210 . ", s, \"" . $record->{f210}->{s} . "\"";
    }

    $fix_new_210 = $fix_new_210 . ")";
    
    return $fix_new_210;
}

1;