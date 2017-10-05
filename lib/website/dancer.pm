package website::dancer ;

use Dancer2;
use utf8 ;
use Data::Dumper ; # pour débugage

use kibini::config ;
use rbxrec::record ;
use rbxrec::record::file ;

our $VERSION = '0.1';

# Paramètres globaux de Dancer : ceci remplace le fichier config.yaml
set appname => "Le havenet - récupération de notices BnF";
set layout => "kibini";
set charset => "UTF-8";
set template => "template_toolkit";
set engines => {
   template => {
     template_toolkit => {
       start_tag => '[%',
       end_tag => '%]'
     }
   }
};

get '/' => sub {
    my $bnfSruServerStatusError = IsBnfSruServerStatusError() ;
    template 'rbxrec', {
        label1 => "Récupération de notices",
        bnfSruServerStatusError => $bnfSruServerStatusError
    };
};
  
post '/records' => sub {
    my $file = {} ;
    my $stat = {} ;
    if ( exists params->{'file'} ) {
        my $data = request->upload('file');
    
        my $dir_conf = GetConfig('dir_record') ;
        my $dir = $dir_conf->{'in'} ;
        mkdir $dir if not -e $dir;
     
        $file->{file_in} = path($dir, $data->basename);
        if (-e $file->{file_in}) {
            return "'$file->{file_in}' already exists";
        }
        $data->link_to($file->{file_in});
    
        $file = GetFilePaths($file) ;
    
        my $charset = params->{'encodage_in'} ;
        $stat = ModRecordsFile($file, $charset) ;
    
        MoveFileInToArchive($file->{file_in}) ;
    } elsif ( exists params->{'idlist'} ) {
        $file = GetFilePathForRecordsById() ;
        $stat = GetBnfRecordsById( params->{'type_query'}, params->{'idlist'}, $file->{file_out} ) ;
    }
    my $list = params->{'idlist'} ;
    
    template 'records_res', {
        label1 => "Récupération de notices",
        file_out => $file->{file_web},
        nb_rec => $stat->{nb_rec},
        nb_bnf => $stat->{nb_bnf_rec},
        ids => $stat->{ids}
    };
} ;

get '/recordsByEan' => sub {
    template 'recordsByEan', {
        label1 => "Récupération de notices"
    };
} ;

post '/recordsByEan/post' => sub {
    my $eanlist = params->{'eanlist'} ;
    my $vars = GetRecordsByEan($eanlist) ;
    template 'recordsByEanList', {  
        nb_notices => $vars->{'nb_notices'},
        nb_foundBnF => $vars->{'nb_foundBnF'},
        nb_foundDec => $vars->{'nb_foundDec'},
        nb_foundLib => $vars->{'nb_foundLib'},
        nb_notFound => $vars->{'nb_notFound'},
        notfound => $vars->{'notfound'}
    } ;
} ;

1 ;
