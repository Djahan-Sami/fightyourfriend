# Ragdoll Brawl

Prototype de jeu de combat 3D réalisé avec Godot. Les attaques, les poses et
leurs réglages peuvent être modifiés dans l'atelier Blender fourni avec le jeu.

## Lancer le jeu

1. Installe [Godot 4.7.2](https://godotengine.org/download/windows/).
2. Double-clique sur `LANCER_LE_JEU.bat`.
3. Si Godot n'est pas détecté, copie `CONFIG_LOCAL.bat.example` sous le nom
   `CONFIG_LOCAL.bat`, puis indique le chemin de Godot dedans.

Blender est facultatif pour jouer. Pour modifier les animations, installe
Blender 5.2, renseigne également son chemin dans `CONFIG_LOCAL.bat`, puis ouvre
`ANIMER_LES_COUPS.bat`.

## Contenu du projet

- `01_JEU` : projet Godot et animations de combat de base.
- `02_ATELIER_ANIMATIONS` : atelier Blender et outils d'export.
- `03_SKINS_PERSONNAGES` : emplacement des modèles `.glb` ou `.gltf`.
- `04_SKINS_TERRAINS` : arrière-plans et revêtements de sol des arènes.
- `05_SAUVEGARDES` : sauvegardes locales, exclues de GitHub.

Une nouvelle installation copie automatiquement les animations fournies vers
les données locales du jeu. Des modifications déjà présentes sur l'ordinateur
ne sont jamais remplacées.

## Exemples inclus

- Une arène de toit composée d'une image de fond et de son revêtement de sol.

Aucun skin de personnage n'est inclus. Les modèles, photographies, essais de
génération 3D et sauvegardes privées ne font pas partie du dépôt. Voir
`01_JEU/THIRD_PARTY.md` pour les crédits des ressources tierces incluses ou
étudiées.
