# Page PixiJS minimale

Étape 1 de [`html5-migration.md`](html5-migration.md).

## Pourquoi

Cette étape prouve que toute la chaîne marche avant d'écrire la couche `h2d` : Haxe 4.3.7, les externs `pixi-haxe`, PixiJS 6.0.2, la lecture d'un atlas, le build web et le déploiement par la CI.

## Périmètre

- Une page web publiée sous `/pixi/`.
- La lecture d'un atlas TexturePacker (PNG + XML, format de `client/client/assetsWeb/*.xml`).
- La toolchain Haxe 4 dans son propre `mise.toml`, et son étape dans la CI.

## Règles

### La page affiche un sprite de l'atlas `assets1`

`{#html5.pixi-page::shows-atlas-sprite}`

La page `/pixi/` affiche le sprite `animalDuck` de `assets1` dans un canevas de 640 × 768 px, la taille du jeu Flash. Le sprite garde sa taille dans l'atlas, sans déformation.

### Un nom de sprite inconnu donne une erreur claire

`{#html5.pixi-page::unknown-sprite-fails}`

Si on demande à l'atlas un nom qui n'existe pas, la lecture échoue avec un message qui contient ce nom. Elle ne renvoie pas une texture vide.

### Un atlas qui ne charge pas donne une erreur visible

`{#html5.pixi-page::atlas-load-error-visible}`

Si l'image ou le XML de l'atlas ne charge pas, la page affiche un message d'erreur qui nomme le fichier. La page ne reste pas noire sans explication.

### Les sprites de l'atlas ne bavent pas

`{#html5::atlas-no-bleeding}` (règle de [`html5-migration.md`](html5-migration.md))

Les textures des atlas sont chargées sans mipmaps.

### La version Flash ne change pas

`{#html5::flash-stays-until-parity}` (règle de [`html5-migration.md`](html5-migration.md))

La page d'accueil du site sert toujours la version Ruffle. La CI construit encore le SWF avec Haxe 3.2.1 et réussit.

### Les dépendances sont fixées

`{#html5.pixi-page::pinned-dependencies}`

- `pixi-haxe` est installé depuis le fork Kadokadeo, à un commit fixe.
- PixiJS 6.0.2 est téléchargé par `tools/build-web.sh`, avec une vérification SHA-256, comme Ruffle.

## Critères d'acceptation

- Étant donné `assets1.xml`, quand on lit le sprite `animalDuck`, alors on obtient son rectangle exact (x, y, largeur, hauteur) tel qu'il est écrit dans le XML.
- Étant donné `assets1.xml`, quand on lit un nom qui n'existe pas, alors la lecture échoue avec un message qui contient ce nom.
- Étant donné un XML d'atlas vide (aucun `SubTexture`), quand on lit un nom, alors la lecture échoue de la même façon.
- Étant donné le site déployé, quand on ouvre `/pixi/`, alors le canard s'affiche, et aucune erreur n'apparaît dans la console.
- Étant donné le site déployé, quand on ouvre `/`, alors la version Ruffle se lance comme avant.
- Étant donné une image d'atlas absente, quand on ouvre `/pixi/`, alors la page affiche une erreur qui nomme `assets1.png`.

Les trois premiers critères sont des tests unitaires (Haxe compilé en JS, lancé par `node --test`, comme les tests de `web/`). Les trois derniers se vérifient dans un navigateur.

## Hors périmètre

- La couche `h2d` : elle commence à l'étape 2.
- Le son, les entrées et la sauvegarde.
- Les atlas autres que `assets1`, et les polices.
- Un lien vers `/pixi/` depuis la page d'accueil : la page reste cachée tant qu'elle ne sert qu'aux développeurs.
