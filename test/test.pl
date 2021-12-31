#! /usr/bin/perl

use Modern::Perl;
use FindBin qw( $Bin );
use Data::Dumper;

use lib "$Bin/../lib";
use rbxrec::record;

my $file = "recid_2021123185329.mrc";
my @fixes = ('marc_map(001,frbnf)',
             'marc_map(003,ark_bnf)',
             'marc_remove(\'9..\')',
             'marc_map(214, c214.$append)
			 if exists(c214)
				marc_map(210, c210)
				if exists(c210)
					marc_map(210a, f210.a)
					marc_map(210b, f210.b)
					marc_map(210c, f210.c)
					marc_map(210d, f210.d)
					marc_map(210e, f210.e)
					marc_map(210f, f210.f)
					marc_map(210g, f210.g)
					marc_map(210h, f210.h)
					marc_map(210r, f210.r)
					marc_map(210s, f210.s)
				end
				marc_map(214a, f214.a)
				marc_map(214b, f214.b)
				marc_map(214c, f214.c)
				marc_map(214d, f214.d)
				marc_map(214i, f214.i)
				marc_map(214p, f214.p)
			end');
			
			
my @fixes2 = (	'marc_copy(214, f214)',
				'set_field(f214.0.tag , 210)',
				'marc_paste(f214.0)',
				'retain(record)');
			
my $importer = Catmandu->importer('MARC', type => 'RAW', file => $file, fix => \@fixes2);
 
$importer->each(sub {
    my $bnf_record = shift;
	#my $fix = _GetCatmanduFixer('to_parse_bnf', $bnf_record);
	#print Dumper($fix);
    print Dumper($bnf_record);
});