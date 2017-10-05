package kibini::config ;

use Exporter ;
@ISA = qw(Exporter) ;
@EXPORT = qw( GetConfig ) ;

use FindBin qw( $Bin );
use YAML qw(LoadFile) ;

sub GetConfig {
	my ($k) = @_ ;

    my $file = "$Bin/../etc/kibini_conf.yaml" ;
    my $file_conf = LoadFile($file);
	
    my $conf ;
    if ( defined $k ) {
        my %config = (
            dir_record => $file_conf->{'dir_record'}
        ) ;
        $conf = $config{$k} ;
    } else {
        $conf = $file_conf ;
    }

    return $conf
};

1;

__END__

=pod

=encoding UTF-8

=head1 NOM

kibini::config

=cut
