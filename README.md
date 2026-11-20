# BeFree

Jeu d'évasion en vue subjective (Godot 4.4, GL Compatibility, mobile paysage). Tu es Théo, condamné à tort. Tu as une cellule, un garde obèse nommé Gaston, une matraque à éviter... et une cuillère cachée dans un gâteau.

**APK Android (dernier build)** : https://github.com/AurelXP/befree/releases/download/latest/befree.apk
(construit automatiquement par GitHub Actions à chaque push sur `main`, APK debug signé avec une clé debug jetable.)

---

## ÉTAT DU PROJET (à lire en premier si tu reprends le code)

Dernière mise à jour : 2026-11-20. Le jeu est **jouable de bout en bout** dans un test automatisé (`tools/test_play.gd`) : intro → routine → gâteau/cuillère → poster → creusage → coups de matraque → fin. Il n'a **jamais été testé sur un vrai téléphone** : seules des captures en rendu logiciel (llvmpipe) et des tests headless ont été faites.

### Déjà fait
- Cinématique d'intro (4 plans, sous-titres machine à écrire, bouton « Passer »), scène de fin.
- Cellule 3D complète : murs de briques, sol carrelé, barreaux + porte qui pivote, lit, toilettes, lavabo + miroir, table + tabouret, étagère, seau, comptage des jours sur le mur, fenêtre grillagée (lumière jour/nuit), poster (cache le trou), trou qui grandit + gravats + poussière, plateau-repas, gâteau avec cuillère cachée. Couloir avec bureau du garde (lampe, beignets, journal), casiers, cellules.
- Gaston : modèle procédural obèse (ventre qui respire, casquette, moustache, matraque), états lecture / beignet / sieste / surveillance / avertissement, marche, s'assoit, attaque à la matraque (entre dans la cellule, frappe, ressort).
- Mains en vue subjective (doigts articulés, manches orange) avec poses : idle, manger, creuser, fouiller le gâteau, pisser, se couvrir ; la cuillère apparaît dans la main.
- Routine (voir `Game.SCHEDULE`) : petit-déj 08:00, inspection 09:30, toilettes 10:30, déjeuner 12:30 (gâteau jour 1), toilettes 15:30, inspection 17:00, dîner 18:30, nuit 21:30–05:30. Une corvée (repas / toilettes) ratée = coup de matraque.
- Suspicion (vue + bruit selon l'état de Gaston), 3 coups = cachot (game over), tunnel 0–100 %, punition = poster remis, cuillère rangée, tunnel abîmé de 25 %.
- Sons générés par code (`sfx.gd`) : ambiance (bourdonnement + gouttes), cloche de phase, mastication, chasse d'eau, grattement du creusage (boucle), cuillère qui tinte, coup de matraque, alarme, jingles trouvaille/victoire.
- Textures 100 % procédurales (`tex.gd`), modèles 100 % en primitives (`bld.gd`), aucun asset externe.
- Build Android CI + release « latest ».

### Reste à faire (par priorité)
1. **Tester sur un vrai appareil Android** : performances (GL Compatibility, lumières Omni nombreuses → réduire si < 30 fps), taille de l'UI (la HUD se replace via `Hud._layout()` selon la taille du viewport ; vérifier la lisibilité des tailles de police sur petit écran), orientation paysage forcée (`window/handheld/orientation=0` dans `project.godot`, à vérifier), gestes tactiles (`player.gd` utilise la souris ; `emulate_touch_from_mouse` n'est pas nécessaire car Android envoie des events tactiles → vérifier que `InputEventScreenTouch/Drag` sont bien convertis ; sinon activer `input_devices/pointing/emulate_mouse_from_touch=true`, qui est la valeur par défaut).
2. **Audio** : les effets sont des synthèses simples. À améliorer : pas du garde (pas de signal d'étape dans `guard.gd` pour l'instant), clés/serrure de la porte, voix/grognements de Gaston, vraie musique d'ambiance et de cinématique (fichiers .ogg libres de droits), mixage par bus audio.
3. **Contenu / gameplay** : plus d'objets cachés à fouiller (matelas, étagère), plusieurs jours avec variantes, codétenu, pièges (garde qui vérifie l'étagère), événements aléatoires, fin alternative, sauvegarde de progression (`FileAccess` / `ConfigFile`).
4. **Qualité visuelle** : vrais modèles (glTF) pour Gaston et les mains à la place des primitives, normal maps, ombres douces, post-traitement (vignettage, grain), animation des doigts plus fine, textures du trou en meilleure résolution (elles sont pixelisées de près).
5. **Équilibrage** : constantes dans `game.gd` (`DIG_RATE`, `MINUTES_PER_SEC`) et dans `main.gd::_update_suspicion`. Un jour dure 12 min réelles à vitesse x1 (`MINUTES_PER_SEC = 2` ; 1440 min de jeu / 2 = 12 min).
6. **Signature de release** : le workflow produit un APK *debug*. Pour le Play Store : ajouter un keystore release dans les secrets GitHub, passer à `--export-release` et à un AAB.
7. **Icône Android** : l'icône est `icon.svg`; fournir `launcher_icons/main_192x192` et les adaptatives dans `export_presets.cfg`.
8. **Localisation** : tout le texte est en français, codé en dur.

### Pièges connus
- Le `Control` racine du HUD doit rester en `MOUSE_FILTER_IGNORE`, sinon il avale tous les touchers et la caméra ne bouge plus (bug corrigé le 2026-11-20 ; `tools/test_input.gd` le vérifie avec de vrais événements).
- `Game` est un autoload : un script lancé avec `godot -s` ne le voit pas par son nom, utiliser `root.get_node("Game")` (voir `tools/test_play.gd`).
- Les `StaticBody3D` d'interaction (couche 2) sont créés par `Bld.hit()` avec un meta `id` ; `Player.hit_id()` les lit par raycast. Ajouter un objet cliquable = `Bld.hit(...)` + un cas dans `Main._on_tap`.
- `cell.gd` : `Cell.STATIONS` définit les points de vue de caméra ; `Player.go_to()` anime les transitions.
- Les `Bld.quad(parent, Vector2, ...)` prennent un `Vector2` (pas Vector3).
- Après avoir ajouté un script avec `class_name`, relancer `godot --headless --import` pour régénérer le cache de classes.

---

## Le jeu

- **Contrôles (tactile)** : glisser = regarder autour ; boutons « Aller à » (côté droit) = se déplacer (Grille, Lit, Table, Toilettes, Mur, Fenêtre) ; toucher un objet = s'en servir (la caméra s'y rend toute seule) ; maintenir sur le trou = creuser ; bouton bas droite = sortir/ranger la cuillère ; « Temps x1/x4 » = accélérer l'horloge.
- **Boucle** : observe Gaston, mange et va aux toilettes aux heures dites, récupère la cuillère dans le gâteau au déjeuner du jour 1, tire le poster, sors la cuillère, maintiens sur le trou pour creuser quand Gaston lit, mange ou dort. Pendant les inspections, remets le poster et range la cuillère.

## Développer

```bash
# Godot 4.4.1 (stable) requis
godot --headless --import                     # importe le projet
godot --headless -s tools/test_play.gd        # test automatisé de bout en bout (affiche l'état)
# test des entrées (glisser, bouton de navigation), nécessite un affichage :
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/test_input.gd
# captures d'écran (rendu logiciel) -> /tmp/befree_shots/*.png
mkdir -p /tmp/befree_shots
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/screenshots.gd
```

Export local : Godot 4.4 > Projet > Exporter > Android (templates d'export + SDK Android requis). En CI, voir `.github/workflows/android.yml`.

## Structure

| Fichier | Rôle |
|---|---|
| `project.godot`, `export_presets.cfg` | config du projet et export Android |
| `scenes/Main.tscn` | scène unique (un seul nœud avec `main.gd`) |
| `scripts/game.gd` | autoload : état global, horloge, emploi du temps |
| `scripts/main.gd` | règles du jeu, interactions, suspicion, punitions |
| `scripts/cell.gd` | cellule, mobilier, lumières, trou, plateau |
| `scripts/guard.gd` | Gaston : modèle, comportements, attaque |
| `scripts/hands.gd` | mains en vue subjective |
| `scripts/player.gd` | caméra, points de vue, entrées tactiles |
| `scripts/hud.gd` | interface, menus, sous-titres (mise en page adaptative) |
| `scripts/sfx.gd` | effets sonores synthétisés |
| `scripts/cinematic.gd` | intro et scène de fin |
| `scripts/tex.gd`, `scripts/bld.gd` | textures procédurales, outils de modélisation |
| `tools/` | scripts de test et de capture d'écran |
