# Migration de Flash vers HTML5 (Haxe 4 + PixiJS)

Spec « design-first » : l'architecture est décidée, cette spec fixe les contraintes et le comportement à garder.

Décidé le 2026-11-22.

## Pourquoi

Le jeu tourne aujourd'hui dans Ruffle, un émulateur Flash. Ruffle peut avoir des écarts avec le vrai lecteur Flash, et le build Flash dépend de Haxe 3.2.1 et d'OpenFL 3.6.1, deux outils abandonnés.

Les projets Eternaltwin utilisent PixiJS. Une version Haxe 4 + PixiJS est plus durable, et l'équipe Eternaltwin peut la maintenir avec ses outils habituels.

## Périmètre

- Le client du jeu (`client/client`) et la partie de `client/mt` qu'il utilise.
- Le build web et le déploiement par la CI.

## Contraintes

- **Le code reste en Haxe.** Pas de réécriture en TypeScript.
- **Le code du jeu garde l'API `h2d`.** Une couche `h2d` écrite au-dessus de PixiJS remplace Heaps (option B). Le jeu utilise environ 10 classes : `Text`, `SpriteBatch`, `Sprite`, `Interactive`, `Bitmap`, `Font`, `Layers`, `Tile`, `Graphics`, `BlendMode`.
- **Le passage à Heaps moderne reste possible (option A).** Il consiste à remplacer la couche `h2d` par la vraie bibliothèque Heaps. On le fait seulement si PixiJS pose un problème que la couche ne peut pas résoudre (performances de `SpriteBatch`, filtres).
- **Une API manquante va dans la couche commune, jamais dans le code du jeu.** C'est la règle de Kadokadeo pour `arkadeo`.
- **Pile technique de Kadokadeo :**
  - Haxe 4.3.7.
  - Les externs du fork [`pixi-haxe`](https://gitlab.com/eternaltwin/kadokadeo/pixi-haxe), fixés par commit. Le projet `pixi-haxe` d'origine est abandonné. Le fork ajoute les modes de fusion et le curseur, dont `h2d.BlendMode` et `h2d.Interactive` ont besoin.
  - PixiJS 6.0.2 : c'est la version que Kadokadeo utilise avec ces externs.
- **Les deux builds coexistent.** La toolchain Haxe 4 vit dans son propre `mise.toml`, dans un sous-dossier. Le build Flash (Haxe 3.2.1) ne change pas.
- **Un seul dossier de sources.** Une correction pour Haxe 4 doit aussi compiler en Haxe 3.2.1. Si c'est impossible, on utilise `#if js`.
- **Pas de CDN.** Comme pour Ruffle, `tools/build-web.sh` télécharge PixiJS à une version fixe et vérifie son SHA-256.

## Méthode : Branch by Abstraction et Parallel Change

La migration se fait sur `main`, sans branche longue, avec deux techniques.

**Branch by Abstraction** pour le moteur d'affichage. L'abstraction existe déjà : c'est l'API `h2d`. Deux implémentations vivent côte à côte :

- le fork `h3d` (Heaps 2015), dans le build Flash ;
- la couche `h2d` sur PixiJS, dans le build JS.

Le chemin de sources (`-cp`) de chaque build choisit l'implémentation. Il n'y a pas d'interface à écrire. L'option A est une troisième implémentation derrière la même abstraction. À la parité, on supprime l'implémentation Flash (étape 5).

**Parallel Change** (étendre, migrer, contracter) pour chaque usage direct de `flash.*` : son, stockage, événements, préchargeur.

1. **Étendre :** on ajoute un point d'entrée qui marche dans les deux builds (par exemple une classe de stockage avec `#if flash` et `#if js`).
2. **Migrer :** on passe les appelants sur ce point d'entrée, un par un. Le build Flash reste vert à chaque commit.
3. **Contracter :** quand plus personne n'appelle `flash.*` directement, on supprime l'ancien chemin. Le code `#if flash` disparaît à l'étape 5.

À chaque commit, les deux builds compilent et les tests passent.

## Règles

### La version Flash reste en ligne jusqu'à la parité

`{#html5::flash-stays-until-parity}`

La version Ruffle reste à l'adresse actuelle. La version PixiJS est publiée sous `/pixi/`. Elle remplace la version Ruffle seulement quand les 180 niveaux sont jouables dans les deux versions.

### La progression des joueurs ne se perd pas

`{#html5::progress-survives-migration}`

Un joueur qui passe de la version Ruffle à la version PixiJS garde ses niveaux débloqués et ses meilleurs scores, dans le même navigateur.

Question ouverte : où Ruffle garde-t-il le stockage local du jeu, et la page PixiJS peut-elle le lire ? À vérifier avant l'étape 4.

### Chaque classe de la couche `h2d` se comporte comme dans Heaps

`{#html5::h2d-layer-matches-heaps}`

Pour une même scène, la version PixiJS affiche la même image que la version Ruffle : mêmes positions, mêmes tailles, mêmes couleurs, même ordre d'affichage. On le vérifie avec des captures côte à côte.

### Les atlas ne bavent pas

`{#html5::atlas-no-bleeding}`

Un sprite pris dans un atlas n'affiche aucun pixel de ses voisins, même réduit. Les atlas font 2048 × 2048 px. Sur une texture de cette taille, les mipmaps font baver les voisins (piège connu de Kadokadeo).

## Étapes

Chaque étape est publiable seule. Chaque étape a sa propre spec quand elle commence.

1. **Page PixiJS minimale** — [`html5-first-pixi-page.md`](html5-first-pixi-page.md).
2. **Grille d'un niveau.** `h2d.Tile`, `h2d.Bitmap` et `h2d.Sprite` sur PixiJS. La page affiche la grille d'un niveau de `data/levels.json`.
3. **Reste de la couche `h2d`.** `HSprite`, `h2d.Font`, `h2d.Text`, puis `Interactive`, `Layers`, `SpriteBatch`, `Graphics`. Une classe par commit, chacune avec un test.
4. **Le vrai client en Haxe 4.** Un fichier à la fois. On remplace les ~10 fichiers qui utilisent `flash.*` (son, stockage, événements, préchargeur). On migre la progression (`html5::progress-survives-migration`).
5. **Parité, puis bascule.** Les 180 niveaux se jouent dans la version PixiJS. Elle remplace la version Ruffle, et on supprime le build Flash.

## Ce qu'on reprend de Kadokadeo

Dépôt : [eternaltwin/kadokadeo](https://github.com/eternaltwin/kadokadeo), dossier `.opencode/skills/flash-port`.

- `references/pitfalls.md`, partie « Haxe and PixiJS ». À relire avant d'écrire du code d'affichage. Exemples :
  - Une méthode nommée `render()` remplace la méthode `render` de PixiJS, sans message d'erreur.
  - Le premier filtre utilisé compile un shader et fige le jeu de 10 à 80 ms. Il faut « chauffer » les filtres au démarrage.
  - `PIXI.Text` dépend des polices de l'ordinateur. Le jeu utilise déjà des polices bitmap, donc ce piège ne nous touche pas.
- `references/testing.md` : Chrome sans affichage, piloté par le protocole DevTools, avec de vrais événements. Captures de l'original dans Ruffle à côté du portage.
- La lecture des atlas TexturePacker de leur `mt.deepnight.slb.BLib`. Leurs sprites sont des `BSprite` ; nous utilisons des `HSprite`, donc on ne reprend que la lecture.
- Au fil du portage, on écrit un skill `h2d-to-pixi` qui garde nos propres pièges.

On ne reprend pas les skills `mt-to-haxe` (notre code est déjà en Haxe), `scale` (obsolète) ni `determinism` et les replays (Rockfaller n'en a pas).

## Hors périmètre

- L'éditeur de niveaux (`client/levelEditor`).
- Une version mobile native.
- PixiJS 7 ou 8 : il n'existe pas d'externs Haxe maintenus pour ces versions. On changera de version seulement si PixiJS 6 bloque.
- Les mécaniques de niveaux pas encore reconstruites (eau, magma, motifs, geysers). Elles suivent `docs/PLAN.md`, quel que soit le moteur.
