# Le havenet
Le havenet est une petite application de récupération de notices BnF.
En entrée, deux possibilités sont offertes : 
- fichier de notices unimarc, au format unimarc, codé en ISO 2709, encodé en ISO 5426 ou UTF-8,
- liste d'identifiants (EAN, ark, ...)
En sortie, on récupère un fichier unimarc. ISO 2709 encodé en UTF-8.

Attention, l'outil est basé sur le service SRU de la BnF, encore en version bêta.

## Etape 1 : importer des données
### par fichier unimarc
#### Principe : 
On importe un fichier unimarc (par exemple un fichier Electre), l'outil remplace les notices du fichier par les notices BnF quand il le peut, conserve la notice initiale quand il ne trouve pas de correspondance.

#### Procédure :
Le fichier importé doit être au format unimarc, codé en ISO 2709 et encodé soit en ISO 5426, soit en UTF-8.

On sélectionne un encodage (par défaut, ISO 5426, c'est l'encodage utilisé par Electre, GAM, ADAV, etc...). Les notices proposée par les Lisières sont en revanche en UTF-8.

On importe ensuite un fichier unimarc depuis l'ordinateur et on valide.

#### Traitements effectués :
Une fois le fichier importé :
- on extrait l'EAN (073$a),
- on lance une requête sur cet EAN via le service SRU de la BnF,
- si la BnF renvoie une ou plusieurs notices, on récupère la première d'entre elles, avec les transformations suivantes :
    - on déplace le FRBNF (001) en 035$a,
    - on déplace l'indifiant ark (003) en 033$a,
    - si la notice du fichier d'import comporte un résumé (330$a), on supprime l'éventuel résumé BnF et le remplace par celui de la notice d'import.
- si la BnF ne renvoie pas de notice, on conserve la notice du fichier d'import.


### par liste d'identifiants
#### Principe :
On récupère des notices de la BnF à partir d'identifiants. À l'heure actuelle, on peut récupérer :
- des notices bibliographiques, à partir de :
    - EAN
    - ark
- des notices autorités, à partir de :
    - ark.
    
#### Procédure
On copie-colle une liste d'identifiants (tous de même nature), on sélectionne le type d'identifiant (par défaut EAN) et on valide.

#### Traitements effectués
À partir de l'identifiant, une requête est lancée sur le service SRU de la BnF.
- si la BnF renvoie une ou plusieurs notices, on récupère la première d'entre elles, avec les transformations suivantes :
    - on déplace le FRBNF (001) en 035$a,
    - on déplace l'indifiant ark (003) en 033$a.

## Etape 2 : récupérer un fichier de notice
On récupère en sortie un fichier unimarc ISO 2709 **encodé en UTF-8**. Les fichiers ont pour extension .mrc .

## Etape 3 : importer les données dans Koha.
**Attention, cette procédure doit être suivie scrupuleusement.**
Dans "Outils->Télécharger des notices dans le réservoir" :
- on sélectionne le fichier à uploader,
- on choisit l'encodage : tous les fichiers renvoyés par la Havenet sont **encodés en UTF-8**,
- on sélectionne un modèle de transformation marc (par exemple, "Livres jeune public"), qui va remplir automatiquement le type de document (099$t) et le public cible (339$a),
- dans "Règles de concordance", on sélectionne "ISBN (ISBN)",
- dans "Action en cas de correspondance avec une notice:", on sélectionne "Ignorer la notice entrante (ses exemplaires pourront être traités)".
- dans "Action s'il n'y a pas de concordance :", on sélectionne "Ajouter la notice entrante".
- dans "Vérifier les données exemplaires incluses ?", on sélectionne "Non".
- Cliquer sur "Télécharger dans le réservoir"

![Import : étape 1](https://github.com/medrbx/havenet/blob/master/public/doc/kh_import1.JPG)

Le fichier est alors importé dans Koha. Pour ajouter les nocites à la base, on clique sur "Gestion des notices téléchargées".

![Import : étape 2](https://github.com/medrbx/havenet/blob/master/public/doc/kh_import2.JPG)

Dans "Ajouter des notices bibliographiques en utilisant cette grille :", on sélectionne "Catalogage", puis on clique sur "Importer ce lot dans le catalogue".

![Import : étape 3](https://github.com/medrbx/havenet/blob/master/public/doc/kh_import3.JPG)
