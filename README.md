# Fight Your Friend

Jeu de combat 3D local pour deux joueurs, realise avec Godot. Les animations,
les hitbox, les degats et les timings peuvent etre modifies avec les ateliers
fournis dans le projet.

## Lancer le jeu

1. Installe [Godot 4.7.2](https://godotengine.org/download/windows/).
2. Double-clique sur `LANCER_LE_JEU.bat`.
3. Si Godot n'est pas detecte, copie `CONFIG_LOCAL.bat.example` sous le nom
   `CONFIG_LOCAL.bat`, puis renseigne le chemin de Godot.

Blender est facultatif pour jouer. Pour creer ou modifier les animations,
installe Blender 5.2, renseigne son chemin dans `CONFIG_LOCAL.bat`, puis lance
`ANIMER_LES_COUPS.bat`.

## Clavier et manettes

Ouvre **Configurer les touches** depuis le menu principal. Les commandes
clavier et manette des deux joueurs sont affichees cote a cote. Le saut, le
poing, le pied et la saisie peuvent utiliser les boutons principaux, les
boutons d'epaule ou les gachettes. Pause et Recommencer sont aussi
configurables separement.

Le stick gauche offre un deplacement analogique progressif et la croix
directionnelle reste disponible en meme temps. Les reglages sont sauvegardes
automatiquement et seront recharges au prochain lancement du jeu.

Le bouton **Reglages du stick** permet de choisir quel joueur utilise une
manette lorsqu'une seule est branchee, puis d'ajuster la zone morte et la
sensibilite. Un apercu en direct compare la position physique du stick avec le
mouvement reellement transmis au combattant.

## Animations et sauvegardes

Blender exporte directement les animations dans `01_JEU/default_attacks`.
Ce dossier contient les fichiers GLB ainsi que `attack_manifest.json` : les
animations et les reglages sont donc inclus dans les commits Git et sur GitHub.

Dans l'atelier du jeu, le bouton **SAUVEGARDER TOUT** cree aussi une copie datee
dans `05_SAUVEGARDES`. Ce dossier reste local et n'est pas envoye sur GitHub.
Le bouton **RESTAURER LA DERNIERE COPIE** permet de revenir a cette sauvegarde.

## Contenu du projet

- `01_JEU` : projet Godot, code et animations publiees.
- `02_ATELIER_ANIMATIONS` : atelier Blender et outils d'export.
- `03_SKINS_PERSONNAGES` : modeles `.glb` ou `.gltf` personnels.
- `04_SKINS_TERRAINS` : images de fond et revetements de sol des arenes.
- `05_SAUVEGARDES` : copies locales des animations, exclues de GitHub.

Pour ajouter un terrain, place une image `Nom.png` dans `04_SKINS_TERRAINS`.
Ajoute facultativement `Nom_sol.png` pour que le sol utilise un revetement
associe. Les formats PNG, JPG, JPEG et WebP sont acceptes.

Les skins personnels de personnages ne sont pas inclus dans le depot public.
Une arene d'exemple est fournie. Les credits des ressources tierces se trouvent
dans `01_JEU/THIRD_PARTY.md`.

## Creer la version Windows

1. Dans Godot, installe une fois les modeles d'exportation correspondant a la
   version 4.7.2. Cette installation ne demande pas les droits administrateur.
2. Double-clique sur `EXPORTER_WINDOWS.bat`.
3. La version jouable est creee dans le dossier `build`.

## Tests

Les tests automatiques sont executes a chaque envoi et chaque pull request sur
GitHub. Ils couvrent notamment les animations externes, les saisies, la garde,
les chutes, les combos, les echanges simultanes et le chargement du combat.

## Licence

Le code du projet est distribue sous licence MIT. Les ressources tierces gardent
leurs licences propres, detaillees dans `01_JEU/THIRD_PARTY.md`.
