# Plan : faire tourner Rockfaller en 2026

Mise à jour : 2026-11-17.

Ce document remplace la section « Plan de remise en route » de `AUDIT_CODEBASE.md`. Cet audit décrit l'état de février 2026.

## 1. État actuel

Mise à jour : 2026-11-19. Le projet vit dans son propre dépôt (`rockfaller`), séparé des archives de Motion-Twin.

Ce qui est vérifié :

- Le client Flash compile avec `tools/build-flash.sh client release`, après `tools/install-deps.sh`.
- Le jeu se joue dans Ruffle 0.6.0 sur les 180 niveaux extraits de la vidéo (`data/levels.json`). Testé à la main jusqu'au niveau 8.
- `tools/ProtocolCheck.hx` vérifie que les 180 niveaux passent `Common.VALIDATE_LEVEL`.

Bugs trouvés en jouant, et corrigés :

- `mt/Worker.hx` exécutait les tâches tout de suite : le verrou de `AssetManager.WorldBitmap` restait fermé, et la carte figeait après le niveau 1.
- `mt/Assets.hx` ne gardait pas l'image du chemin : tous les boutons de la carte étaient au même endroit.
- `arDeck` doit totaliser 500 (`Common.LENGTH_TOTAL_DECK`), sinon le bouton du niveau ne réagit pas.
- L'atlas `taupinotron` doit garder ses préfixes de dossier, sinon le grappin plante au niveau 3.
- `benchNineFont.png` et `birminghamFont.png` étaient vides : une partie du texte était invisible. `tools/fonts/rebuild_font_atlases.py` les redessine.

Ce qui manque :

- 22 niveaux à gélatine sont à vérifier : moins de cases trouvées que dans l'objectif (lot 7).
- `arGP` (eau, magma, motifs, geysers) n'est pas extrait.
- L'éditeur de niveaux ne compile pas (`air3`).

## 2. Comment construire et lancer

Prérequis : `mise` installé. `mise.toml` fixe Haxe 3.2.1, Neko 2.1.0, Java 8 et `HAXELIB_PATH`.

```bash
mise exec -- bash tools/install-deps.sh               # une seule fois
mise exec -- bash tools/build-flash.sh client release
mise exec -- haxe -cp . -cp src/com -main tools.ProtocolCheck --interp   # test
```

Pour lancer le jeu, Ruffle desktop doit lire le SWF dans son bac à sable macOS :

```bash
C=~/Library/Containers/rs.ruffle.ruffle/Data/tmp
mkdir -p "$C" && cp client/client/bin/flash/bin/rockFallerMobile.swf "$C/"
~/Downloads/ruffle/Ruffle.app/Contents/MacOS/ruffle "$C/rockFallerMobile.swf"
```

Si Ruffle ouvre un fichier dans `~/code`, il affiche « cannot open files of this type ». Ce n'est pas un problème de SWF. Si macOS refuse ensuite l'accès au conteneur (« Operation not permitted »), ouvrir le SWF depuis le menu File > Open de Ruffle.

### Pourquoi un script et pas `haxelib.json`

- `haxelib.json` décrit une bibliothèque à publier. Il ne déclare pas les dépendances d'une application.
- Le `haxelib 3.2.0-rc.3` de Haxe 3.2.1 installe seulement depuis un `.hxml`. `haxelib install haxelib.json` répond `No such Project`.
- Un `.hxml` ne peut pas fixer `h3d` sur un commit git.
- lix n'est pas utilisé : les outils OpenFL 3 et Lime 2 appellent `haxelib run` et `haxelib path` directement.

### Dépendances fixées (`tools/install-deps.sh`)

| Bibliothèque | Version | Remarque |
|---|---|---|
| `openfl` | 3.6.1 | |
| `lime` | 2.9.1 | |
| `hxsl` | 2.0.6 | Ancien hxsl, séparé de h3d. |
| `castle` | 1.6.1 | Installe aussi `format 3.8.0`. |
| `format` | 3.2.1 | Doit être la version courante. Avec 3.8.0, `hxsl` ne compile pas (`format.agal.C should be EnumValue`). |
| `h3d` | git `59f92055` | Fork `github.com/delahee/h3d`. Dernier commit avant janvier 2016. Le commit de 2020 ne compile pas avec Haxe 3.2.1. |

`build-flash.sh` applique aussi 3 patchs temporaires à `hxsl` et `h3d`, puis les retire à la fin du build.

## 3. Changements par rapport à l'original

Les changements sont classés par sujet. L'historique git suit le même découpage, après un premier commit qui importe le Rockfaller d'origine.

### Lot A : chaîne de build

| Fichier | Changement | Raison |
|---|---|---|
| `mise.toml` | Versions des outils et `HAXELIB_PATH`. | Build reproductible, dépôt de bibliothèques propre au projet. |
| `tools/install-deps.sh` | Nouveau. | Installe les versions fixées. |
| `tools/build-flash.sh` | Nouveau. | Vérifie les assets, applique les patchs, compile, décompresse `assets.swf`. |
| `.gitignore` | `bin/`, `.DS_Store`, `.haxelib/`. | Exclut les fichiers générés. |
| `client/client/application.xml` | `swf-version="11.2"`, `obfu9` commenté. | `obfu9` (obfuscateur de Motion-Twin) n'existe plus. |
| `client/levelEditor/application.xml` | Même changement, plus `format 3.2.1` et `assetsWeb`. | Même raison. |
| `client/client/include.xml` | `format 3.2.1`, `resourcesPath`. | `hxd.Res` doit savoir où sont les ressources. |
| `client/client/src/Main.hx`, `client/levelEditor/src/Main.hx` | `hxd.Res.initEmbed()`. | Les ressources sont intégrées au SWF. |

### Lot B : assets

| Fichier | Changement | Raison |
|---|---|---|
| `client/client/include.xml` | `sfx_low` et `sfxOgg` remplacés par `sfx`. | Seul `sfx/` existe dans l'archive. |
| `client/client/src/manager/SoundManager.hx` | Banque `sfx`, musiques intégrées en `standalone`. | Les musiques étaient téléchargées depuis le serveur. |
| `assets/*.ttf`, `client/client/assets/`, `assetsWeb/*.png`, `sfx/Rockfaller_*.mp3` | Nouveaux fichiers. | Fichiers référencés par le code mais absents de l'archive. |

### Lot C : serveur hors-ligne

| Fichier | Changement | Raison |
|---|---|---|
| `src/com/Protocol.hx` | Nouveau. Types du protocole et `offlineResponse()`. | Le module `Protocol` manquait. Il répond à la place du serveur. |
| `client/mt/` | Stubs des modules `mt.*` manquants. | Voir `STUB_PLAN.md`. `mt/net/Codec.hx` appelle `Protocol.offlineResponse()`. |
| `src/com/Common.hx` | Champ `?offline : Bool` dans `LevelInfo`. | Marque les niveaux synthétiques. |
| `Game.hx`, `UITop.hx`, `SpecialManager.hx` | Conditions `levelInfo.offline != true`. | Le code a des tutoriels codés en dur pour les niveaux 2 et 3, et du loot à partir du niveau 6. Sur un niveau synthétique, ces règles cassent la partie. |
| `client/levelEditor/src/DataManager.hx` | `DoGetLevelsForEditor` sans `()`. | Le constructeur n'a pas d'argument dans `Protocol.hx`. |
| `tools/ProtocolCheck.hx` | Nouveau test. | Vérifie le démarrage hors-ligne et le déblocage d'un niveau. |

### Lot D : exécution hors navigateur (les « correctifs Ruffle »)

Ces correctifs ne sont pas propres à Ruffle. Le jeu tournait dans une page web de Motion-Twin, avec un serveur et du JavaScript autour. Ces 4 correctifs retirent ces dépendances.

1. **`WebMain.hx` : `ExternalInterface.available`.**
   - Avant : le jeu appelle `ExternalInterface.addCallback("onFriendRequest", …)` sans condition.
   - Problème : hors d'une page web, `ExternalInterface` n'existe pas. L'appel lève une erreur au démarrage.
   - Correctif : le jeu enregistre le callback seulement si `ExternalInterface.available` est vrai.

2. **`ButtonLevel.hx` : `tex.bmp == null`.**
   - Avant : `SET_POS` lit les pixels de la texture `wayLevel`. Il cherche un pixel rouge (`0xFF0000`) qui marque la position horizontale de chaque bouton de niveau sur la carte.
   - Problème : h3d envoie l'image au GPU sans garder de `BitmapData`. `tex.bmp` vaut `null`, et le jeu plante sur la carte des niveaux.
   - Correctif : si `bmp` vaut `null`, le bouton est placé au milieu de la frame (`realWid * 0.5`).
   - Limite : la position est approximative. Les boutons ne suivent pas exactement le chemin dessiné. Il n'est pas vérifié si Flash Player avait le même problème.

3. **`PreloaderH2D.hx` : sprites du Taupinotron et de la langue.**
   - Avant : `getSLBTaupi()` et `getSLBLang()` téléchargent `taupinotron.xml` et `lang_<xx>.xml` depuis `INIT_CLIENT.urlImages`.
   - Problème : cette URL est vide hors-ligne. Le chargement échoue et le jeu réessaie 5 fois.
   - Correctif : le jeu charge `taupinotron.xml` intégré, et garde seulement `lang_en.xml`.
   - Limite : les textes dessinés dans les images restent en anglais, quelle que soit la langue.

4. **`SoundManager.hx` : musiques intégrées.**
   - Avant : les musiques du menu et du jeu sont téléchargées depuis `INIT_CLIENT.urlSounds`.
   - Problème : l'URL est vide, et il n'y a donc pas de musique.
   - Correctif : en `standalone`, le jeu utilise les MP3 intégrés. `initDownloads()` s'arrête si l'URL est vide.

### Lot E : documentation

`docs/AUDIT_CODEBASE.md`, `docs/STUB_PLAN.md`, `docs/PLAN.md`, `AGENTS.md`.

### Hors commit

- `.vscode/settings.json` pointe vers Haxe 4.3.7, alors que le projet utilise Haxe 3.2.1. Ce fichier est personnel. Je recommande de l'ajouter au `.gitignore`.
- `client/client/lang/client-translated.pot` est généré par GetText à chaque build `release`. Je recommande de l'ajouter au `.gitignore`.

## 4. Prochaines étapes

Chaque étape est un petit lot qui finit par un commit. Avant et après chaque lot : build, `ProtocolCheck`, et test dans Ruffle.

### Étape 1 : commiter l'existant

Fait : dépôt séparé `rockfaller`, avec l'original de Motion-Twin en premier commit, puis un commit par sujet. Seul le build du dernier commit est vérifié.

### Étape 2 : petites corrections de la chaîne de build

1. `build-flash.sh` supprime le SWF avant de compiler. Si le build échoue, il n'y a plus de SWF. Correctif : compiler vers un fichier temporaire, puis le renommer.
2. GetText réécrit `lang/client.pot` dans un autre ordre à chaque build `release`. Correctif : ignorer ce changement, ou trier la sortie.
3. `PreloaderH2D.hx` importe `TextureFlags` sans l'utiliser. Correctif : supprimer l'import.
4. Ajouter un script `tools/run-ruffle.sh` qui copie le SWF dans le bac à sable et lance Ruffle.

### Étape 3 : sauvegarder la progression

Fait, en ports & adapters :

- Domaine (`src/com/progress/`) : `Progress`, valeur immuable avec le niveau débloqué et les meilleurs scores, et la règle du serveur mobile d'origine (`MobileServer.SAVE_GAME`). `ProgressJson` est le format enregistré, versionné ; une donnée illisible donne une partie neuve.
- Port : `ProgressStore` (`load`, `save`). `Protocol` ne connaît que lui.
- Adaptateurs : `InMemoryProgressStore` (tests, et par défaut) et `SharedObjectProgressStore` (client Flash). Ruffle enregistre un `SharedObject` dans le `localStorage` du navigateur sur le web, et dans un fichier avec Ruffle desktop.
- Composition : `WebMain` branche `SharedObjectProgressStore` au démarrage.
- Test : `tools/ProgressCheck.hx` (10 cas). Test manuel dans Ruffle desktop : niveau 1 gagné, redémarrage, niveau 2 ouvert et meilleur score gardé.
- Pas sauvegardé : vies, or, pioches, butin et tutoriels déjà vus. Le faux serveur les remet à leur valeur fixe à chaque chargement.
- Plus tard : un adaptateur IndexedDB ou Eternaltwin implémentera `ProgressStore`.

### Étape 4 : retrouver les vrais niveaux

C'est l'étape la plus incertaine. Elle dépend de données qui ne sont pas dans le dépôt.

- Sources possibles :
  - un dump de l'API `/api/v15` (archives web, joueurs, anciens de Motion-Twin) ;
  - une sauvegarde de la base du serveur ;
  - l'APK ou l'IPA de Rockfaller mobile, qui contenait peut-être des niveaux embarqués (`MobileServer.hx`, `LevelDesign.MAX_LEVEL_CLIENT`).
  - une playlist YouTube des niveaux 1 à 180 (20 vidéos, en espagnol) : https://www.youtube.com/playlist?list=PLVHaVMlXRNl7CztZj_biaFGHSgDMpAZfT. C'est la piste choisie.
- Extraction depuis la playlist (`tools/levels/`), en lots :
  1. Fait : `download_videos.sh` télécharge les 20 vidéos en 720p dans `.cache/videos/` (2,8 Go). `segment_video.py` découpe une vidéo en tentatives de niveau et sauve l'image de départ de chaque niveau.
     - Un niveau commence quand la grille revient après au moins 2 s d'absence (écran de fin, carte, chargement), ou au début de la vidéo. Le popup « NIVEL N » n'est pas fiable : il manque dans la plupart des vidéos.
     - Un niveau est gagné quand la bannière « ¡ENHORABUENA! » s'affiche. Le numéro de niveau avance à chaque victoire.
     - L'écran « CARGANDO » garde le libellé « SCORE » : il est exclu par sa luminosité (environ 13, contre 33 ou plus pour une grille).
     - Résultat vérifié : 181 tentatives sur les 20 vidéos, les niveaux 1 à 180 sont tous gagnés une fois. La tentative en plus est un échec au niveau 180.
     - Test : `uv run tools/levels/test_segment_video.py` (vidéos 1 et 2, plus 2 images dans `fixtures/`).
  2. Fait : les images avec un tutoriel sont ignorées. Un tutoriel affiche une bulle blanche d'environ 36 000 px, alors que les pierres blanches ne dépassent pas 3 000 px. Seuls les niveaux 8 et 10 ont un tutoriel au départ. Le survol du curseur et l'indice de coup possible (halo bleu) restent dans les images : le lot 3 les traitera, car l'atlas contient une version survolée de chaque pierre (`crystalOver`, `rocOver`…).
  3. Fait : `classify_cells.py` reconnaît chaque case de la grille 9×10. Test : `uv run tools/levels/test_classify_cells.py` (7 tests sur les niveaux 1, 5, 8, 16, 17, 44 et 88 dans `fixtures/`).
     - Chaque case est comparée aux sprites de `assets1` réduits à l'échelle de la vidéo (48,8 / 124). Un sprite est candidat si l'écart moyen de couleur sous son masque reste sous 55 (environ 30 sur une pierre, 78 ou plus sur un trou). Parmi les candidats, la meilleure corrélation (`TM_CCOEFF_NORMED`) gagne. Sans candidat, la case est un trou.
     - Reconnu : les 5 pierres classiques, les trous, les blocs (3 états), la glace (2 états), les bulles, les bombes bonus et les bombes à retardement avec leur compte à rebours.
     - La glace fêlée filmée ne ressemble pas à `iceFront1`. Son état est lu à part : part de pixels sombres (fissures) au centre de la case, environ 0,12 si fêlée, 0 si intacte.
     - Le jeu dessine les bombes à retardement 1,5 fois plus grandes que leur sprite d'atlas. Le meilleur des 10 sprites donne le compte à rebours (49 bombes, de 3 à 9).
     - Une pierre survolée grossit et pâlit, et peut ressembler à de la glace, une bulle ou une bombe. Le curseur est repéré (tache blanche d'environ 110 px, 14×19). À moins de 110 px de lui, ces pièces ne sont gardées que si elles correspondent nettement ; sinon la case vaut `hovered`. Le lot 5 la remplira avec une pierre classique tirée au hasard.
     - Résultat sur les 181 départs : 30 cases `hovered`, presque toutes de vraies pierres survolées. Erreurs connues : 2 bulles perdues (niveaux 130 et 137), et peut-être 2 glaces survolées (niveau 33).
     - Pas traité ici : la gélatine et le mercure, qui marquent l'objectif (lot 4).
  4. Fait : `read_hud.py` lit les coups et l'objectif au départ, et les seuils des 3 étoiles à la fin. `classify_cells.find_goal_cells` trouve les cases de gélatine et de mercure. Tests : `uv run tools/levels/test_read_hud.py` et `test_classify_cells.py`.
     - Les polices bitmap de `assetsWeb` (`benchNineFont`, `birminghamFont`) sont vides dans cette archive. Les chiffres sont donc comparés à des glyphes découpés dans la vidéo et étiquetés une fois, par zone : `refs/digits/{moves,objective,count,stars}/<chiffre>_<n>.png`.
     - Coups : médaillon central. Un nombre décentré de plus de 2 px est rejeté (un chiffre est caché, par exemple par une particule au niveau 31).
     - Objectif : un grand nombre donne `TGScoring`. Sinon, chaque petit nombre est lu avec l'icône au-dessus, reconnue par sa couleur moyenne : gélatine (`TGGelatin`), mercure (`TGMercury`) ou pierres (`TGCollect`).
     - Seuils des étoiles (`arStepScore`) : des étoiles filantes passent sur les chiffres. `segment_video.py` enregistre donc la médiane des images de la moitié centrale du panneau de victoire (`*-stars.png`).
     - Gélatine et mercure sur la grille : couleur médiane des 4 coins de chaque case.
     - Résultat : coups et objectif lus sur 178 niveaux, seuils lus sur les 180 niveaux (échantillon de 18 vérifié à l'œil).
     - Limites connues : les niveaux 1 à 3 cachent les coups (tutoriel), et le niveau 1 cache aussi l'objectif. Le niveau 31 a ses coups illisibles au départ. Pour la gélatine, le nombre de cases trouvées égale l'objectif dans 27 niveaux sur 52 : la gélatine sous la glace ou sous une pierre survolée ne se voit pas. Le nombre affiché pour le mercure n'est pas un nombre de cases, donc pas de contrôle croisé.
  5. Fait : `build_levels.py` écrit `data/levels.json`, avec un `LevelInfo` par niveau (180 niveaux, 467 Ko). Test : `uv run tools/levels/test_build_levels.py`. Commande : `uv run tools/levels/build_levels.py` (environ 3 min).
     - Les enums sont écrits `["Constructeur", arguments…]`, par exemple `["TRHole", 12]`, pour `Type.createEnum` côté Haxe.
     - `arManualRocks` : seulement les pièces spéciales (trous, blocs, glace, bulles, bombes). Les pierres classiques et les cases `hovered` restent tirées au hasard depuis `arDeck`, comme dans le jeu.
     - Trous : la variante `hole0` à `hole15` est choisie d'après les côtés qui touchent une case jouable (bords irréguliers mesurés sur les sprites).
     - `arDeck` : nombre de chaque pierre classique sur la grille de départ. C'est une estimation : les vrais poids ne se voient pas.
     - Biome : couleur moyenne du mur gauche, comparée aux sprites `wall_*`, puis vote sur 3 niveaux voisins de chaque côté. Résultat : 1-15 classique, 16-35 glace, 36-55 magma, 56-75 eau, 76-95 civilisation, 96-120 centre de la Terre, 121-150 cauchemar, 151-180 limbes.
     - Non extrait : `arGP` et `arGrip` (vides). Ce sont des mécaniques (eau, magma, motifs, geysers, bombes) qui ne se voient pas sur l'image de départ.
     - Champ `review` : 29 niveaux à vérifier à la main. Niveaux 1, 2, 3 et 31 : coups illisibles (et objectif illisible au niveau 1). 25 niveaux à gélatine : moins de cases trouvées que dans l'objectif (gélatine sous la glace ou sous une pierre survolée).
  6. Fait : `Protocol.offlineLevels()` lit `data/levels.json`, intégré au SWF par `-resource levels.json@levels` (`client/client/include.xml`). Les enums sont recréés avec `Type.createEnum`. Les 10 niveaux synthétiques, le champ `offline` et ses 5 conditions ont disparu : `Common.hx`, `Game.hx`, `UITop.hx` et `SpecialManager.hx` sont revenus au code d'origine.
     - Corrections à la main dans `tools/levels/overrides.json`, chacune avec sa raison : niveaux 1, 2 et 3 (tutoriels, coups cachés) et niveau 31 (coups cachés par une particule).
     - Test : `haxe -cp . -cp src/com -D version2_1 -resource data/levels.json@levels -main tools.ProtocolCheck --interp`.
     - L'éditeur de niveaux n'intègre pas encore la ressource `levels` : il ne compile pas de toute façon (`air3`).
  7. En cours : corrections à la main dans `tools/levels/overrides.json`.
     - Fait : les 7 niveaux qui ne s'ouvraient pas (29, 35, 92 : gélatine sous la glace ; 124, 133, 138, 145 : ciment en halo gris autour de la glace ou des bombes). Positions lues sur l'image de départ ; leur nombre égale l'objectif.
     - Fait : le total d'un objectif de mercure ajoute les cases couvertes au départ (le haut de l'écran affiche ce qu'il reste, `ModuleGoal` : `num - arMerc.length`).
     - À faire : les 22 niveaux à gélatine incomplets, et `arGP`.
- Si une source existe : écrire un import vers `Array<LevelInfo>`, testé sur 2 ou 3 niveaux connus.
- Si aucune source n'existe : créer des niveaux avec l'éditeur (étape 5).
- Quand de vrais niveaux sont disponibles, retirer le champ `offline` et les conditions du lot C. Les tutoriels des niveaux 2 et 3 redeviennent alors corrects.

### Étape 5 : éditeur de niveaux

- Remplacer ou retirer la dépendance `air3`. Je vérifierai d'abord ce que l'éditeur utilise d'AIR (sans doute l'accès aux fichiers).
- Faire sauvegarder les niveaux dans un fichier JSON lu par `Protocol.offlineLevels()`.
- Critère de fin : un niveau créé dans l'éditeur est jouable dans le client.

### Étape 6 : documentation

- Écrire un `README.md` court : prérequis, 3 commandes, limites connues.
- Marquer `AUDIT_CODEBASE.md` comme historique.

### Étape 7 (optionnelle) : distribution

- Une page HTML avec Ruffle web et le SWF, pour jouer dans un navigateur.
- Le SWF fait 35 Mo. Il faudra peut-être compresser les assets.

## 5. Risques

| Risque | Effet | Parade |
|---|---|---|
| Les vrais niveaux restent introuvables. | Le jeu reste une démo de 10 niveaux. | L'éditeur (étape 5) permet de créer des niveaux. |
| `delahee/h3d` disparaît de GitHub. | `install-deps.sh` échoue. | Garder une copie du dépôt (fork ou archive). |
| Ruffle change son support de Stage3D. | Le jeu ne s'affiche plus. | Fixer la version de Ruffle testée (0.6.0). |
| Le placement approximatif des boutons (lot D, point 2) gêne. | Les boutons ne suivent pas le chemin de la carte. | Garder les pixels de `wayLevel` côté CPU pour lire le marqueur rouge. |
