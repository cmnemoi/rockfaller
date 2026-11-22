# Page PixiJS minimale

Étape 1 de [`html5-migration.md`](html5-migration.md).

## Pourquoi

Cette étape prouve que toute la chaîne marche avant d'écrire la couche `h2d` : Haxe 4.3.7, les externs `pixi-haxe`, PixiJS 6.0.2, la lecture d'un atlas, le build web et le déploiement par la CI.

Elle fait aussi le premier Parallel Change réel. La lecture des atlas TexturePacker sort de `TexturePacker.parseXml` et devient une fonction pure, partagée par les deux builds.

## Périmètre

- La lecture des découpes d'un atlas TexturePacker (XML de `client/client/assetsWeb/*.xml`), sans image et sans moteur d'affichage.
- Une page web publiée sous `/pixi/`, qui affiche un sprite avec cette lecture.
- La toolchain Haxe 4 dans son propre `mise.toml`, et son étape dans la CI.

## Règles

### Les deux builds lisent les atlas avec le même code

`{#html5.atlas::one-reader-for-both-builds}`

`TexturePacker.parseXml` (build Flash) et la page PixiJS appellent la même fonction pure pour lire le XML. Cette fonction compile en Haxe 3.2.1 et en Haxe 4.3.7. Ses tests passent avec les deux compilateurs.

### Les noms des sprites ne changent pas

`{#html5.atlas::same-names-as-flash}`

La lecture donne les mêmes noms et les mêmes numéros d'image qu'aujourd'hui dans le build Flash. Les règles actuelles restent identiques, quirks compris :

- L'extension (`.png`, `.gif`, `.jpg`, `.jpeg`) est enlevée.
- Avec les dossiers en préfixe, `/` devient `_`. Sans cette option, le dossier est enlevé.
- Les chiffres à la fin du nom, puis les `_` à la fin, sont enlevés. Les sprites qui suivent avec le même nom deviennent les images d'une animation : `gripAnim/0000`, `gripAnim/0001`… donnent `gripAnim` images 0, 1…
- Seuls les `_` sont enlevés après les chiffres : `mudPartSmall-24` donne `mudPartSmall-`. C'est un quirk de l'original, on le garde.
- Deux découpes identiques (même rectangle, même cadre) partagent le même numéro d'image.

### Un sprite rogné garde sa place dans son cadre

`{#html5.atlas::trimmed-sprite-keeps-frame}`

TexturePacker enlève les bords transparents de la plupart des sprites (225 sur 246 dans `assets1`). La lecture garde le rectangle découpé et sa position dans le cadre d'origine.

### Un nom de sprite inconnu donne une erreur claire

`{#html5.pixi-page::unknown-sprite-fails}`

Si on demande un nom qui n'existe pas dans l'atlas, la recherche échoue avec un message qui contient ce nom. Elle ne renvoie pas une texture vide. C'est déjà le comportement de `BLib.getTile` (`Unknown group <nom>#<image>!`).

### La page affiche un sprite de l'atlas `assets1`

`{#html5.pixi-page::shows-atlas-sprite}`

La page `/pixi/` affiche le sprite `animalDuck` de `assets1` dans un canevas de 640 × 768 px, la taille du jeu Flash. Le sprite est dessiné à sa place dans son cadre de 98 × 98 px, sans déformation.

Depuis l'étape 2, le canard passe par la SpriteLib (`HSprite`) et la couche `h2d` : voir [`html5-spritelib-on-pixi.md`](html5-spritelib-on-pixi.md).

### Un atlas qui ne charge pas donne une erreur visible

`{#html5.pixi-page::atlas-load-error-visible}`

Si l'image ou le XML de l'atlas ne charge pas, la page affiche un message d'erreur qui nomme le fichier. La page ne reste pas noire sans explication.

### Les sprites de l'atlas ne bavent pas

`{#html5::atlas-no-bleeding}` (règle de [`html5-migration.md`](html5-migration.md))

Les textures des atlas sont chargées sans mipmaps. Dans PixiJS 6, une texture de 2048 × 2048 px a des mipmaps par défaut.

### La version Flash ne change pas

`{#html5::flash-stays-until-parity}` (règle de [`html5-migration.md`](html5-migration.md))

La page d'accueil du site sert toujours la version Ruffle. La CI construit encore le SWF avec Haxe 3.2.1 et réussit.

### Les dépendances sont fixées

`{#html5.pixi-page::pinned-dependencies}`

- `pixi-haxe` est installé depuis le fork Kadokadeo, à un commit fixe.
- PixiJS 6.0.2 est téléchargé par `tools/build-web.sh`, avec une vérification SHA-256, comme Ruffle.

## Critères d'acceptation

Lecture de l'atlas (tests en Haxe, lancés par `haxe --interp` en 3.2.1 et en 4.3.7) :

- Étant donné `assets1.xml`, quand on lit `animalDuck`, alors on obtient le rectangle (418, 1821, 61 × 67), le décalage (-20, -16) et le cadre 98 × 98.
- Étant donné `taupinotron.xml` avec les dossiers en préfixe, quand on lit les découpes, alors `gripAnim/0000`, `gripAnim/0001`… donnent `gripAnim` images 0, 1…
- Étant donné `taupinotron.xml` sans les dossiers en préfixe, quand on lit les découpes, alors `gripAnim/0000` perd tout son nom : le dossier part, puis le numéro. Le nom obtenu est vide, et c'est pour cela que le jeu plantait au niveau 3.
- Étant donné `taupinotron.xml`, quand on cherche `gripAnim/0001`, alors on le trouve aussi par son nom brut.
- Étant donné `fx.xml`, quand on lit `mudPartSmall-24`, alors le nom obtenu est `mudPartSmall-`.
- Étant donné deux découpes identiques, quand on les lit, alors elles ont le même numéro d'image.
- Étant donné `assets1.xml`, quand on cherche un nom qui n'existe pas, alors la recherche échoue avec un message qui contient ce nom.
- Étant donné un XML d'atlas sans `SubTexture`, quand on cherche un nom, alors la recherche échoue de la même façon.

Page (vérifiée dans un navigateur) :

- Étant donné le site déployé, quand on ouvre `/pixi/`, alors le canard s'affiche, et aucune erreur n'apparaît dans la console.
- Étant donné le canard affiché à la moitié de sa taille, quand on regarde ses bords, alors aucun pixel d'un sprite voisin n'apparaît.
- Étant donné une image d'atlas absente, quand on ouvre `/pixi/`, alors la page affiche une erreur qui nomme `assets1.png`.
- Étant donné le site déployé, quand on ouvre `/`, alors la version Ruffle se lance comme avant.

## Hors périmètre

- La couche `h2d` : elle commence à l'étape 2.
- Le son, les entrées et la sauvegarde.
- Les atlas autres que `assets1`, et les polices.
- Un XML d'atlas mal formé : les fichiers sont dans le dépôt et générés par TexturePacker, pas fournis par un utilisateur.
- Les écrans haute densité (`devicePixelRatio` > 1) : le canevas reste à 640 × 768 px, avec le même flou que Ruffle, jusqu'à la bascule.
- Un lien vers `/pixi/` depuis la page d'accueil : la page reste cachée tant qu'elle ne sert qu'aux développeurs.
