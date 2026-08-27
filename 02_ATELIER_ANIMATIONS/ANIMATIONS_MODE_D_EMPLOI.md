# Atelier d'animation Ragdoll Brawl

L'atelier repart d'une base vide :

- aucune garde préfabriquée ;
- aucun coup préfabriqué ;
- aucun exemple chargé dans Blender ;
- toutes les commandes de coup restent inactives tant que vous n'avez pas créé et exporté leur animation.

Tout fonctionne sans droits administrateur.

## Un seul pantin pour tous les personnages

Vous créez chaque animation une seule fois sur ce pantin. Le jeu l'applique automatiquement aux deux combattants et aux futurs skins 3D.

Le squelette commun est protégé : restez en **Mode Pose** et utilisez uniquement les poignées visibles. Si sa structure est modifiée accidentellement en **Mode Édition**, l'export est refusé afin de protéger toutes les animations déjà créées.

Les fichiers exportés ne contiennent ni personnage ni modèle visible : uniquement l'animation du squelette commun. Un nouveau skin peut donc être chargé dans le jeu sans refaire la garde ou les coups.

## Ouvrir l'atelier

1. Double-cliquez sur `ANIMER_LES_COUPS.bat`.
2. Dans Blender, ouvrez le panneau **Ragdoll Brawl** à droite. Appuyez sur `N` s'il est masqué.
3. L'écran d'accueil sépare la position vulnérable, la garde et les coups.

## Créer la position vulnérable

1. Cliquez sur **Créer / modifier la position vulnérable**.
2. Placez le personnage avec les mêmes poignées que pour les autres poses.
3. Cliquez sur **1. Enregistrer la position**.
4. Cliquez sur **2. Exporter uniquement cette position**.

Le jeu utilise cette pose lorsque le combattant reste neutre et vulnérable. Cet export ne modifie ni la garde ni les coups.

## Créer la garde

1. Cliquez sur **Créer / modifier la garde**.
2. Construisez la pose à partir du personnage neutre.
3. Cliquez sur **1. Enregistrer la garde**.
4. Cliquez sur **2. Exporter uniquement la garde**.

Ce dernier bouton exporte uniquement la garde. Il ne crée et ne modifie aucun coup.

## Créer un coup

1. Enregistrez d'abord votre garde.
2. Sur l'accueil, choisissez le coup puis cliquez sur **Créer ce coup**.
3. Le coup est créé dans Blender, mais il n'est pas encore envoyé au jeu.
4. Choisissez directement l'une des trois poses : **Préparation**, **Impact** ou **Retour**.
5. Modifiez la pose puis cliquez sur **Enregistrer cette pose**.
6. La pose **Impact** doit obligatoirement être enregistrée avant le premier export.
7. Cliquez sur **Exporter uniquement ce coup**.

La préparation et le retour commencent sur la garde. Ils peuvent être personnalisés, puis remis sur la garde avec **Remettre cette pose = garde**.

Un coup non créé ou non exporté ne se déclenche pas dans le jeu. Exporter seulement la garde laisse toutes les commandes de coup inactives.

## Manipuler le personnage

- Cliquez une seule fois sur une poignée dans le panneau : aucun second bouton n'est nécessaire.
- **Coude** + `G` : oriente librement le bras supérieur dans les trois dimensions. L'articulation de l'épaule reste au même endroit, mais elle tourne ; la main suit le coude.
- **Main** + `G` : règle ensuite l'avant-bras à partir du coude.
- **Genou** + `G` : oriente librement la cuisse dans les trois dimensions. La hanche reste au même endroit, mais elle tourne ; le pied suit le genou.
- **Pied** + `G` : règle ensuite le tibia à partir du genou.
- Passez entre **Profil du jeu** et **Face** pour contrôler facilement les trois axes.
- **Pied** + `G` : place la cheville et plie la jambe.
- **Direction genou** + `G` : choisit le sens du pli du genou.
- `R` : tourne la main, le pied, le bassin, le torse ou la tête sélectionnée.
- **Corps entier** + `G` : déplace tout le personnage, notamment pour les attaques aériennes.
- **Face** montre réellement le visage.
- **Profil du jeu** montre réellement le côté du combattant.

## Régler les durées

Les trois durées sont exprimées en images à 60 images par seconde :

- **Avant impact** ;
- **Impact** ;
- **Retour**.

La pose **Préparation** est automatiquement placée à mi-chemin de la durée **Avant impact**. La première moitié va de la garde à la préparation, puis la seconde moitié anime réellement la préparation jusqu'à l'impact.

Après une modification, cliquez sur **Appliquer les durées**. Les poses sont déplacées aux nouvelles images sans être modifiées.

## Séparation garantie

- Le bouton de garde refuse d'exporter un coup.
- Le bouton de la position vulnérable n'exporte que cette position.
- Le bouton d'un coup refuse d'exporter la garde.
- Le premier export d'un coup est refusé tant que son impact n'a pas été personnellement enregistré.
- Le manifeste du jeu ne référence que les fichiers réellement exportés.
- Chaque export est vérifié comme appartenant au même squelette commun.
