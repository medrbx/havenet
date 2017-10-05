package rbxrec::record::file ;

use Exporter ;
@ISA = qw(Exporter) ;
@EXPORT = qw( MoveFileInToArchive GetFilePaths GetFilePathForRecordsById ) ;

use strict ;
use warnings ;
use File::Copy;

use kibini::config ;
use kibini::time ;

sub GetFilePaths {
    my ($file) = @_ ;
    
    my $dir = GetConfig('dir_record') ;
    my $dir_in = $dir->{'in'} ;
    my $dir_out = $dir->{'out'} ;
    my $web_out = $dir->{'web_out'} ;
    my ($file_path, $file_name) = ( $file->{file_in} =~ m/^($dir_in)\/(.*)\..*$/ ) ;
    $file->{file_out} = "$dir_out/$file_name.mrc" ;
    $file->{file_web} = "$web_out/$file_name.mrc" ;
    
    my $time = GetDateTime('now_') ;
    my $dir_arch = $dir->{'arch'} ;
    $file->{file_arch} = "$dir_arch/$time.mrc" ;
    
    return $file ;
}

sub GetFilePathForRecordsById {
    my $file ;
    
    my $dir = GetConfig('dir_record') ;
    my $dir_out = $dir->{'out'} ;
    my $web_out = $dir->{'web_out'} ;
    my $time = GetDateTime('now_') ;
    
    $file->{file_out} = "$dir_out/recid_$time.mrc" ;
    $file->{file_web} = "$web_out/recid_$time.mrc" ;
      
    return $file ;
}

sub MoveFileInToArchive {
    my ( $path ) = @_ ;
    my $time = GetDateTime('now_') ;
    my $dir = GetConfig('dir_record') ;
    my $dir_arch = $dir->{'arch'} ;
    my $new_path = "$dir_arch/$time.mrc" ;
    move($path, $new_path) ;
}

1;