#! /usr/bin/perl

use strict ;
use warnings ;
use Data::Dumper ;

my $summary = 'Le monde se retrouve plongé dans le chaos après une série de catastrophes appelées "épitaphes". Le jeune Hypothénuse retrouve son petit frère et sa petite soeur à Paris après deux ans d\'amnésie. Ils font route vers le Portugal, espérant prendre la mer pour rejoindre leurs parents à San Francisco. Mais ils doivent affronter un monde dévasté abritant zombies et autres mutants. ­Electre 2017' ;
$summary =~ s/"/\\"/g ;

print "$summary\n" ;