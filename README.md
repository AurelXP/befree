# BeFree

Jeu d'évasion en vue subjective (Godot 4.4, GL Compatibility, mobile paysage). Tu es Théo, condamné à tort. Tu as une cellule, un garde obèse nommé Gaston, une matraque à éviter... et une cuillère cachée dans un gâteau.

**APK Android (dernier build)** : https://github.com/AurelXP/befree/releases/download/latest/befree.apk
(construit automatiquement par GitHub Actions à chaque push sur `main`, APK debug signé avec une clé debug jetable.)

---

## ÉTAT DU PROJET (à lire en premier si tu reprends le code)

Dernière mise à jour : 2026-11-20. Le jeu est **jouable de bout en bout** dans les tests automatisés (`tools/test_play.gd`, `tools/test_input.gd`). Il n'a **jamais été testé sur un vrai téléphone** : seulement des captures en rendu logiciel (llvmpipe) et des tests headless/xvfb.

### Ce que fait le jeu
- **Cinématique d'intro** (4 plans), puis **déplacement libre à la Roblox** : joystick flottant à gauche (zone gauche de l'écran), glisser à droite pour regarder, bouton **Saut**, bouton **Action** contextuel (change de libellé selon l'objet le plus proche), bouton secondaire « Remettre le poster ».
- **Prison immense** (60 × 66 m) : bloc cellulaire (cellule + couloir + bureau du garde), **cour** (panier de basket, bancs, banc de muscu, lampadaires, arbres, tour de guet), **jardin** clôturé (4 parterres), **cantine** (comptoir, 4 tables, cuistot), mur d'enceinte. Ciel et soleil suivent l'heure.
- **PNJ** : Marco (dealer, boutique), Vieux Jo (jardinier, indices), Gros Rémi (cuistot), 6 détenus qui se promènent (dialogues).
- **Économie** : argent (départ 10 €). Gagner : arroser un parterre (+6 €, 1x/jour/parterre), pièces qui traînent (+2 €, réapparaissent chaque jour). Dépenser chez Marco : pelle de poche 60 € (creuse x2,2), chaussettes 30 € (bruit x0,4), pot-de-vin 45 € (efface un coup), café 8 € (vitesse 60 s).
- **Routine** (`Game.SCHEDULE`, 1 jour = 12 min réelles à x1) : repas à la cantine (prendre le plateau au comptoir puis manger à une table), toilettes obligatoires **dans la cellule**, inspections (en cellule, poster remis, cuillère rangée), **couvre-feu** (porte de cellule et grille de sortie fermées dès que le joueur est dedans ; s'il est dehors il a 16 s pour rentrer). Rater une corvée ou violer le couvre-feu = Gaston te poursuit et te frappe, puis te ramène en cellule (poster remis, cuillère rangée, tunnel −25 %, amende 5 €). 3 coups = cachot.
- **Gaston** (garde obèse, matraque) : patrouille dans toute la prison via un graphe A* (`World.NODES/EDGES`), s'arrête pour lire / manger un beignet, poste fixe pendant repas / toilettes / inspection, dort à son bureau la nuit. **Vision réelle** (cône + raycast, `Guard.can_see`) et ouïe. Visible en rouge sur la **minicarte**.
- **Évasion** : le gâteau de Léa (cantine, déjeuner) contient une cuillère → en cellule tirer le poster, sortir la cuillère, maintenir **Action** sur le trou pour creuser (le garde te voit / t'entend, le trou visible à travers les barreaux le trahit si le poster est tiré). 100 % = fin.
- Sons synthétisés (`sfx.gd`), textures et modèles 100 % procéduraux.
- **CI** : APK construit à chaque push sur `main` (voir plus bas).

### Reste à faire (par priorité)
1. **Tester sur un vrai appareil Android** : fluidité (GL Compatibility ; ~10 lumières Omni + monde étendu → réduire/ajouter du culling si < 30 fps), lisibilité de l'interface sur petit écran, sensibilité du regard (`TouchControls.LOOK_SENS`), zone du joystick (moitié gauche), vitesse (`Player.WALK_SPEED`). Vérifier que les touchers multiples (joystick + regard + bouton) marchent : `touch_controls.gd` lit `InputEventScreenTouch/Drag` ; la souris émulée depuis le tactile (`device == -1`) est ignorée.
2. **Gameplay** : plus de jobs (cantine : débarrasser, cour : trier), objets cachés à fouiller (matelas, étagère), quêtes de Vieux Jo, rivalités entre détenus, fouilles surprises, plusieurs fins, sauvegarde de progression (`ConfigFile`), difficulté croissante (inspection plus fréquente, garde plus rapide).
3. **PNJ** : ils ne collisionnent pas avec le joueur ni entre eux (ils se promènent en ligne droite entre des points) ; ajouter navigation/évitement, assise à la cantine, bagarres.
4. **Audio** : pas du garde et des PNJ (pas de signal d'étape), voix, vraie musique d'ambiance (.ogg libres de droits), bus audio. Les modules audio vorbis/ogg sont retirés du template allégé (voir CI) : à réactiver dans `template.yml` si on ajoute des fichiers .ogg.
5. **Qualité visuelle** : vrais modèles glTF (Gaston, PNJ, mains) — le module gltf est retiré du template allégé, mais l'import se fait à l'export donc ça reste possible —, normal maps, ombres douces, post-traitement, textures plus fines, animations d'assise.
6. **Équilibrage** : `game.gd` (`DIG_RATE`, `MINUTES_PER_SEC`, fenêtres de la routine), `main.gd` (taux de suspicion dans `_update_suspicion`, `CURFEW_TIME`, prix `PRICES`).
7. **Release Play Store** : le workflow signe avec une clé de test jetable. Ajouter un vrai keystore (secrets GitHub), un AAB, des icônes adaptatives (`export_presets.cfg` > `launcher_icons/*`).
8. **Localisation** : tout le texte est en français, codé en dur.

### Taille de l'APK
- Moteur officiel Godot 4.4.1 release arm64 : **~25,6 Mo** (c'est presque tout le moteur ; le jeu lui-même pèse ~1 Mo car tout est procédural).
- `.github/workflows/template.yml` (lancement manuel) compile un **template Android allégé** (optimisation de taille, `disable_advanced_gui`, text server avancé et ~25 modules retirés) et le publie dans la release `templates`. `android.yml` l'utilise automatiquement s'il existe. Si le build du jeu casse après coup, c'est qu'un module retiré est nécessaire : le réactiver dans `template.yml` (ligne `module_*_enabled=no`) et relancer le workflow. Pour revenir au template officiel : supprimer la release `templates`.
- Autres leviers : ne garder que arm64 (déjà fait), pas d'assets externes (déjà fait).

### Pièges connus
- Le `Control` racine du HUD doit rester en `MOUSE_FILTER_IGNORE`, sinon il avale les touchers. `TouchControls` écoute en `_input` et ignore les zones listées dans `Hud.touch.blockers` (boutons, dialogues, menus) : **tout nouveau bouton/panneau d'interface doit y être ajouté**.
- `Game` est un autoload : un script lancé avec `godot -s` ne le voit pas par son nom, utiliser `root.get_node("Game")`.
- Interactions : un objet est interactif s'il a un `Bld.hit(parent, id, taille, pos, rayon)` (groupe `interact`, meta `id` et `radius`) ; `Main._update_near` choisit le plus proche à portée ; ajouter l'action dans `Main._label_for` et `Main._on_action_down`. Les hits des PNJ sont enfants du PNJ (`npc_marco`, `npc_jo`, `npc_cook`, `npc_chat`).
- Collisions : `Bld.collide = true` rend solides les boîtes épaisses ; `Bld.block(..., layer)` ajoute un bloc invisible (couche 1 = bloque corps ET vue du garde, couche 4 = bloque seulement les corps : barreaux, clôtures, portes). Le joueur (couche 8) masque 1|4 ; la vue du garde (raycast) masque 1.
- Soleil : `World.sun` n'éclaire que la couche 2 ; tout mesh extérieur / acteur doit être marqué par `World.mark(node)` (sinon il reste sombre dehors).
- Le garde se déplace par script (pas de physique) le long de `World.NODES` ; garder les chemins entre nœuds libres d'obstacles.
- `Bld.quad(parent, Vector2, ...)` prend un `Vector2`. Après un nouveau `class_name`, relancer `godot --headless --import`.
- L'écran est en mode d'étirement `expand` : la mise en page du HUD se recalcule dans `Hud._layout()`.

---

## Le jeu

- **Contrôles (tactile)** : joystick flottant (moitié gauche) = marcher ; glisser (moitié droite) = regarder ; **Saut** ; **Action** (bas droite, contextuel : toilettes, plateau, manger, arroser, parler, creuser en maintenant...) ; **Sortir/Ranger la cuillère** ; **Temps x1/x4**. Au clavier (tests) : ZQSD/WASD/flèches + espace.
- **Boucle** : explore, gagne de l'argent, mange aux heures dites, récupère la cuillère dans le gâteau au déjeuner, rentre en cellule avant l'inspection/le couvre-feu, creuse quand Gaston est loin ou endormi.

## Développer

```bash
# Godot 4.4.1 (stable) requis
godot --headless --import                     # importe le projet
godot --headless -s tools/test_play.gd        # test automatisé de bout en bout (affiche OK/FAIL)
# test des entrées réelles (joystick, regard, saut), nécessite un affichage :
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/test_input.gd
# captures d'écran (rendu logiciel) -> /tmp/befree_shots/*.png
mkdir -p /tmp/befree_shots
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/screenshots.gd
# captures de la carte seule : tools/world_shots.gd (w_*.png)
```

Export local : Godot 4.4 > Projet > Exporter > Android (templates d'export + SDK Android requis). En CI, voir `.github/workflows/android.yml`.

## Structure

| Fichier | Rôle |
|---|---|
| `project.godot`, `export_presets.cfg` | config du projet et export Android |
| `scenes/Main.tscn` | scène unique (un seul nœud avec `main.gd`) |
| `scripts/game.gd` | autoload : état global, horloge, emploi du temps, argent, objets |
| `scripts/main.gd` | règles du jeu : interactions de proximité, cantine, jardin, boutique, couvre-feu, suspicion, punitions |
| `scripts/world.gd` | prison entière : cour, jardin, cantine, PNJ, pièces, graphe A*, soleil/ciel |
| `scripts/cell.gd` | cellule, couloir, mobilier, trou/poster, portes, lumières |
| `scripts/guard.gd` | Gaston : modèle, patrouille A*, vision, poursuite |
| `scripts/npc.gd` | PNJ (détenus, cuistot, dealer, jardinier) |
| `scripts/player.gd` | corps du joueur (CharacterBody3D), caméra, saut |
| `scripts/touch_controls.gd` | joystick flottant + regard multi-touch |
| `scripts/hands.gd` | mains en vue subjective |
| `scripts/hud.gd`, `scripts/minimap.gd` | interface, dialogues, minicarte (mise en page adaptative) |
| `scripts/cinematic.gd` | intro et scène de fin |
| `scripts/sfx.gd` | effets sonores synthétisés |
| `scripts/tex.gd`, `scripts/bld.gd` | textures procédurales, outils de modélisation/collision |
| `tools/` | tests (`test_play`, `test_input`) et captures (`screenshots`, `world_shots`) |
| `.github/workflows/` | `android.yml` (APK), `template.yml` (moteur allégé, manuel) |
