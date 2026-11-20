# BeFree

Jeu d'évasion en vue subjective (Godot 4.4, mobile). Tu es Théo, condamné à tort. Tu as une cellule, un garde obèse nommé Gaston, une matraque à éviter... et une cuillère cachée dans un gâteau.

## Le jeu

- **Cinématique d'intro** qui raconte l'histoire.
- **Vue à la première personne** avec tes mains animées (poses : manger, creuser, fouiller le gâteau, se couvrir).
- **Routine de prison** : petit-déj, déjeuner, dîner, toilettes obligatoires, inspections, extinction des feux. Rater une corvée = coup de matraque.
- **Gaston** : lit son journal, mange des beignets, fait la sieste, surveille. Tu creuses quand il ne regarde pas.
- **Cellule** : lit, toilettes, lavabo, table, tabouret, étagère, fenêtre grillagée, poster (qui cache le mur), plateau-repas, gâteau.
- **Évasion** : trouve la cuillère dans le gâteau, tire le poster, maintiens le doigt sur le trou pour creuser jusqu'à 100 %.
- 3 coups de matraque = cachot à vie.

Tout est généré par le code : modèles 3D à partir de primitives, textures procédurales, animations. Aucun asset externe.

## Contrôles (tactile)

- Glisser : regarder autour de soi
- Toucher un objet : s'en servir
- Maintenir sur le trou : creuser
- Bouton en bas à droite : sortir / ranger la cuillère
- Bouton « Temps x1 / x4 » : accélérer l'horloge

## Build

L'APK est construit automatiquement par GitHub Actions (`.github/workflows/android.yml`) à chaque push sur `main`, puis publié dans la release **latest** et en artefact du workflow.

En local : ouvrir le projet avec Godot 4.4, installer les export templates Android, puis *Projet > Exporter > Android*.

## Structure

| Fichier | Rôle |
|---|---|
| `scripts/game.gd` | état global, horloge, emploi du temps |
| `scripts/main.gd` | règles du jeu, interactions |
| `scripts/cell.gd` | cellule, mobilier, lumières |
| `scripts/guard.gd` | Gaston et ses comportements |
| `scripts/hands.gd` | mains en vue subjective |
| `scripts/player.gd` | caméra et entrées tactiles |
| `scripts/hud.gd` | interface |
| `scripts/cinematic.gd` | intro et fin |
| `scripts/tex.gd`, `scripts/bld.gd` | textures procédurales, outils de modélisation |
