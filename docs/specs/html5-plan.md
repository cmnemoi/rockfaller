# Plan d'implémentation : migration HTML5

Ce plan suit [`html5-migration.md`](html5-migration.md). L'étape 1 est détaillée commit par commit. Les étapes suivantes restent au niveau des lots : chacune aura son détail quand elle commencera.

Règle de chaque commit : le build Flash, le build JS et `mise run test` passent, avant et après.

## Organisation des fichiers

| Chemin | Contenu |
|---|---|
| `html5/mise.toml` | Haxe 4.3.7 et ses variables. Il remplace, dans ce dossier, le Haxe 3.2.1 du `mise.toml` racine. |
| `html5/install-deps.sh` | Les haxelibs du build JS, dans `html5/.haxelib/`. |
| `html5/src/` | Le code propre au build JS : point d'entrée, lecture des atlas. Plus tard, la couche `h2d` (étape 2). |
| `html5/test/` | Les tests du build JS. |
| `html5/index.html` | La page `/pixi/`. |

Le code du jeu (`client/client/src`) ne bouge pas : le build JS l'ajoutera à son chemin de sources à l'étape 4.

## Étape 1 : page PixiJS minimale

Spec : [`html5-first-pixi-page.md`](html5-first-pixi-page.md).

### Commit 1.1 : toolchain Haxe 4 et build JS vide

- `html5/mise.toml` fixe Haxe 4.3.7. Il redéfinit `HAXE_STD_PATH` et `HAXELIB_PATH`. Sinon, ces variables héritées du `mise.toml` racine pointent vers Haxe 3.2.1.
- `html5/install-deps.sh` installe le fork `pixi-haxe` au commit `57a718ce5239c62d99fb788529c51770eecf2106` (`haxelib git pixijs ...`), puis sa dépendance `perf.js`.
- `html5/src/Main.hx` ne fait rien. `html5/build.hxml` le compile en `dist/web/pixi/main.js`.
- `mise.toml` racine : tâches `html5:install` et `html5:build`, lancées dans `html5/`.
- CI : cache de `html5/.haxelib`, puis installation et build.

Vérification : la CI est verte, et le site déployé ne change pas.

Risque : `mise-action` installe-t-il les deux versions de Haxe ? Si non, on ajoute une étape `mise install` dans `html5/`.

### Commit 1.2 : lecture d'un atlas (test d'abord)

Règles : `html5.pixi-page::unknown-sprite-fails`, et le rectangle exact de `animalDuck`.

1. Test rouge `html5/test/AtlasTest.hx` :
   - `animalDuck` donne le rectangle écrit dans `assets1.xml` ;
   - un nom inconnu échoue avec un message qui contient ce nom ;
   - un atlas sans `SubTexture` échoue de la même façon.
2. Code : `html5/src/Atlas.hx` lit le XML TexturePacker et renvoie le rectangle d'un nom. Il ne dépend pas de PixiJS, donc on le teste sans navigateur.
3. Le test tourne avec `haxe ... --interp`, comme `check:protocol`. Tâche `html5:test`, ajoutée à `mise run test` et à la CI.

`--interp` suffit pour du code sans navigateur, et il suit la pratique du dépôt.

### Commit 1.3 : PixiJS dans le site

Règle : `html5.pixi-page::pinned-dependencies`.

- `tools/build-web.sh` télécharge le paquet npm `pixi.js@6.0.2` (`https://registry.npmjs.org/pixi.js/-/pixi.js-6.0.2.tgz`), vérifie son SHA-256, et copie `dist/browser/pixi.min.js` dans `dist/web/pixi/`.
- Le chemin exact du fichier dans le paquet est à vérifier au moment du commit.

Vérification : la CI est verte, et `dist/web/pixi/pixi.min.js` existe.

### Commit 1.4 : la page affiche le canard

Règles : `html5.pixi-page::shows-atlas-sprite`, `html5::atlas-no-bleeding`, `html5.pixi-page::atlas-load-error-visible`, `html5::flash-stays-until-parity`.

- `html5/index.html` charge `pixi.min.js`, puis `main.js`.
- `Main.hx` crée une application de 640 × 768 px. Il charge `assets1.png` sans mipmaps et `assets1.xml`. Ensuite, il affiche `animalDuck` à sa taille.
- Si un fichier ne charge pas, la page affiche un texte qui nomme ce fichier.
- `tools/build-web.sh` copie la page, `main.js`, `assets1.png` et `assets1.xml` dans `dist/web/pixi/`.

Vérification dans Chrome, en local (`mise run serve`), puis sur le site déployé :

- `/pixi/` affiche le canard, et la console ne montre aucune erreur ;
- `/pixi/` sans `assets1.png` affiche l'erreur ;
- `/` lance toujours la version Ruffle.

## Étapes suivantes (lots)

### Étape 2 : mesure, puis grille d'un niveau

- Essai d'une demi-journée : compiler `client/client/src` en Haxe 4 vers JS. On note les erreurs, groupées par cause, dans `docs/specs/html5-inventory.md`. On jette le code de l'essai et on commite seulement l'inventaire.
- `h2d.Tile`, `h2d.Bitmap`, `h2d.Sprite` dans `html5/src/h2d/`, avec les mêmes signatures que celles que le jeu appelle dans le fork `h3d`.
- La page affiche la grille du niveau 1 de `data/levels.json`.
- Premier script de captures de parité (`html5::parity`) : Chrome sans affichage ouvre `/` et `/pixi/`, et compare les images d'un écran fixe.

### Étape 3 : reste de la couche `h2d`

- Une classe par commit, dans l'ordre de l'inventaire. Liste attendue : `HSprite` et `HSpriteBE`, `Font`, `Text`, `Interactive`, `Layers`, `SpriteBatch`, `Graphics`, `BlendMode`.
- L'inventaire dit ce que le jeu utilise de `SpriteBatch`, de `BlendMode` et des filtres. Ce sont les seuls points qui peuvent nous faire passer à l'option A.

### Étape 4 : le vrai client en Haxe 4

- Le build JS ajoute `client/client/src` et `client/mt` à son chemin de sources.
- Corrections pour Haxe 4, un fichier à la fois. Chaque correction compile aussi en Haxe 3.2.1.
- Pour chaque usage de `flash.*` : Parallel Change (étendre, migrer, contracter).
- Son : il démarre au premier clic (`html5::sound-starts-on-first-click`).
- Chargement : barre de progression simple (`html5::simple-loading-screen`).

### Étape 5 : parité, puis bascule

- Migration de la progression : décodeur AMF limité aux types que le jeu écrit (`html5::progress-survives-migration`).
- Parité vérifiée (`html5::parity`) : 180 niveaux, captures, toucher.
- La page actuelle reçoit un interrupteur Ruffle/PixiJS. PixiJS devient la valeur par défaut.
- On supprime le build Flash, Ruffle et le code `#if flash`.
