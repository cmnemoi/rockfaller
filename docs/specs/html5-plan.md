# Plan d'implémentation : migration HTML5

Ce plan suit [`html5-migration.md`](html5-migration.md). L'étape 1 est détaillée commit par commit. Les étapes suivantes restent au niveau des lots : chacune aura son détail quand elle commencera.

Règle de chaque commit : le build Flash, le build JS et `mise run test` passent, avant et après.

## Organisation des fichiers

| Chemin | Contenu |
|---|---|
| `html5/mise.toml` | Haxe 4.3.7 et ses variables. Il remplace, dans ce dossier, le Haxe 3.2.1 du `mise.toml` racine. |
| `html5/install-deps.sh` | Les haxelibs du build JS, dans `html5/.haxelib/`. |
| `html5/src/` | Le code propre au build JS : point d'entrée de la page. Plus tard, la couche `h2d` (étape 2). |
| `client/mt/deepnight/slb/assets/TexturePackerXml.hx` | La lecture pure des atlas, partagée par les deux builds. |
| `tools/AtlasCheck.hx` | Ses tests, lancés par `--interp` en Haxe 3.2.1 et en Haxe 4.3.7. |
| `html5/index.html` | La page `/pixi/`. |

Le code du jeu (`client/client/src`) ne bouge pas : le build JS l'ajoutera à son chemin de sources à l'étape 4.

## Étape 1 : page PixiJS minimale

Spec : [`html5-first-pixi-page.md`](html5-first-pixi-page.md).

### Commit 1.1 : la lecture des atlas devient une fonction pure (Haxe 3)

Règles : `html5.atlas::one-reader-for-both-builds`, `html5.atlas::same-names-as-flash`, `html5.atlas::trimmed-sprite-keeps-frame`, `html5.pixi-page::unknown-sprite-fails`.

C'est l'étape « étendre » du Parallel Change. Tout se fait avec la toolchain actuelle (Haxe 3.2.1).

1. Tests rouges dans `tools/AtlasCheck.hx`, sur les vrais fichiers XML : les sept critères de lecture de la spec.
2. `TexturePackerXml.hx` : une fonction lit les découpes du XML (nom nettoyé, numéro d'image, rectangle, décalage, cadre), et une fonction cherche une découpe par nom et numéro d'image. Le code des règles de nommage est déplacé depuis `TexturePacker.parseXml`, sans changement.
3. `TexturePacker.parseXml` appelle la nouvelle fonction et garde le reste (création du `BLib`, animations).
4. Tâche `check:atlas` dans `mise.toml`, ajoutée à `mise run test` et à la CI.

Vérification :
- `mise run test` passe.
- Le build Flash compile.
- Dans Ruffle, le jeu va jusqu'au niveau 3, où le grappin utilise les noms à dossier de `taupinotron`.

### Commit 1.2 : toolchain Haxe 4 et mêmes tests

- `html5/mise.toml` fixe Haxe 4.3.7. Il redéfinit `HAXE_STD_PATH` et `HAXELIB_PATH`. Sinon, ces variables héritées du `mise.toml` racine pointent vers Haxe 3.2.1.
- `html5/install-deps.sh` installe le fork `pixi-haxe` au commit `57a718ce5239c62d99fb788529c51770eecf2106` (`haxelib git pixijs ...`), puis sa dépendance `perf.js`.
- Tâche `html5:check:atlas` : `tools/AtlasCheck.hx` tourne en Haxe 4.3.7 avec `--interp`.
- `html5/src/Main.hx` ne fait rien. `html5/build.hxml` le compile en `dist/web/pixi/main.js`.
- CI : cache de `html5/.haxelib`, installation, tests Haxe 4 et build JS.

Vérification : la CI est verte, et le site déployé ne change pas.

Risques :
- `mise-action` installe-t-il les deux versions de Haxe ? Si non, on ajoute une étape `mise install` dans `html5/`.
- `haxelib` de Haxe 4.3.7 a besoin d'une Neko compilée pour la machine : Neko 2.1 n'existe pas pour arm64. Confirmé : `html5/mise.toml` fixe Neko 2.4.1.
- `haxe.xml.Fast` est obsolète en Haxe 4. Résolu au commit 1.1 : `TexturePackerXml` utilise l'API `Xml` de base, qui existe dans les deux versions.

### Commit 1.3 : PixiJS dans le site

Règle : `html5.pixi-page::pinned-dependencies`.

- `tools/build-web.sh` télécharge le paquet npm `pixi.js@6.0.2` (`https://registry.npmjs.org/pixi.js/-/pixi.js-6.0.2.tgz`), vérifie son SHA-256, et copie `dist/browser/pixi.min.js` dans `dist/web/pixi/`.
- Le chemin exact du fichier dans le paquet est à vérifier au moment du commit.

Vérification : la CI est verte, et `dist/web/pixi/pixi.min.js` existe.

### Commit 1.4 : la page affiche le canard

Règles : `html5.pixi-page::shows-atlas-sprite`, `html5::atlas-no-bleeding`, `html5.pixi-page::atlas-load-error-visible`, `html5::flash-stays-until-parity`.

- `html5/index.html` charge `pixi.min.js`, puis `main.js`.
- `Main.hx` crée une application de 640 × 768 px. Il charge `assets1.png` sans mipmaps et `assets1.xml`. Il lit les découpes avec `TexturePackerXml`, puis affiche `animalDuck` à sa place dans son cadre.
- Si un fichier ne charge pas, la page affiche un texte qui nomme ce fichier.
- `tools/build-web.sh` copie la page, `main.js`, `assets1.png` et `assets1.xml` dans `dist/web/pixi/`.

Vérification dans Chrome, en local (`mise run serve`), puis sur le site déployé :

- `/pixi/` affiche le canard, et la console ne montre aucune erreur ;
- le canard réduit de moitié ne montre aucun pixel voisin ;
- `/pixi/` sans `assets1.png` affiche l'erreur ;
- `/` lance toujours la version Ruffle.

## Étapes suivantes (lots)

### Étape 2 : mesure, puis la SpriteLib sur PixiJS

Spec : [`html5-spritelib-on-pixi.md`](html5-spritelib-on-pixi.md). Inventaire : [`html5-inventory.md`](html5-inventory.md) (fait).

Méthode Mikado : le but est que la page joue `gripAnim` avec les vrais `BLib` et `HSprite`. Le compilateur Haxe 4 vers JS donne les prérequis un par un. Chaque prérequis devient un commit, dans l'ordre des feuilles vers le but.

1. Parallel Change de `BLib` : sa partie Flash passe sous `#if flash`. Le SWF doit rester identique.
2. Couche `h2d`, une classe à la fois, chacune avec ses tests `--interp` : `h3d.mat.Texture`, `h2d.Tile`, `h2d.Sprite`, `h2d.Drawable` et `h2d.Bitmap`, la scène et son rendu. Puis les petites dépendances que le compilateur demande (`hxd`, `h3d.Vector`…).
3. Tests de la SpriteLib avec `--interp` : groupes, erreurs, suite des images de `gripAnim`, pivot.
4. La page joue `gripAnim`. Test Playwright dans le Chrome installé (`mise run test:site`, après `mise run web`).

### Étape 3 : reste de la couche `h2d`

- Une classe par commit, dans l'ordre de l'inventaire : `Text` et `Font`, `Interactive`, `Layers`, `SpriteBatch` et `HSpriteBE`, `Graphics`, `BlendMode`, puis le reste.
- Questions à trancher : `Drawable.color` plus grand que 1, et le lissage par sprite (voir la spec de l'étape 2).

### Étape 4 : le vrai client en Haxe 4

- Le build JS ajoute `client/client/src` et `client/mt` à son chemin de sources.
- Corrections pour Haxe 4, un fichier à la fois. Chaque correction compile aussi en Haxe 3.2.1.
- Pour chaque usage de `flash.*` : Parallel Change (étendre, migrer, contracter).
- Son : il démarre au premier clic (`html5::sound-starts-on-first-click`).
- Chargement : barre de progression simple (`html5::simple-loading-screen`).
- Premier écran réel (l'accueil) : script de captures de parité, et calibrage du seuil N (`html5::parity`).

### Étape 5 : parité, puis bascule

- Migration de la progression : décodeur AMF limité aux types que le jeu écrit (`html5::progress-survives-migration`).
- Raccourci de debug « gagner le niveau », dans les builds de debug seulement.
- Parité vérifiée (`html5::parity`) : 180 niveaux par le raccourci, échantillon joué à la main, captures, toucher.
- La page actuelle reçoit un interrupteur Ruffle/PixiJS. PixiJS devient la valeur par défaut.
- On supprime le build Flash, Ruffle et le code `#if flash`.
