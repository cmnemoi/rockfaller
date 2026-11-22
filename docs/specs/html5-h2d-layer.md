# Le reste de la couche `h2d`

Étape 3 de [`html5-migration.md`](html5-migration.md). Elle suit [`html5-spritelib-on-pixi.md`](html5-spritelib-on-pixi.md) : même méthode (Mikado depuis le compilateur, géométrie du fork gardée telle quelle, commandes de dessin vérifiées avec `--interp`, PixiJS vérifié avec Playwright).

Chaque classe a sa section. Une section s'écrit quand la classe commence, pas avant.

## Pourquoi

Le jeu utilise 17 types `h2d` ([`html5-inventory.md`](html5-inventory.md)). L'étape 2 en a couvert 6. Sans les autres, aucun écran du jeu ne peut tourner en JS.

## Ordre

1. `SpriteBatch` et `HSpriteBE` : 17 fichiers. Les éléments sont déjà en place, il manque le dessin.
2. Couleur et modes de fusion des `Drawable`.
3. `Layers`.
4. `Font` et `Text` : le plus gros morceau (173 usages).
5. `Interactive` : les clics et les touchers.
6. `Graphics`, puis le reste de l'inventaire.

## Mesures qui fixent le périmètre

Mesuré le 2026-11-22 dans `client/client/src` :

- `HSprite.colorize` n'est jamais appelé. Une couleur plus grande que 1 n'est donc pas un besoin.
- `colorMatrix` sert 2 fois (survol d'un monde dans `ButtonWorld`, effet de magma dans `Game`). `color` avec `colorAdd` sert 1 fois (silhouettes des butins dans `Collection`).
- `Main` met `Drawable.DEFAULT_FILTER = true` : tout est lissé. Seuls 4 endroits mettent `filter = false`.
- Modes de fusion : `Add` 41 fois, `Multiply` 3, `SoftOverlay` 4, `None` 2, `Normal` 3, `Overlay` 1.

## `SpriteBatch` et `HSpriteBE`

### Règles

#### Un élément se dessine à travers le batch

`{#html5.h2d.batch::element-drawn-through-batch}`

Comme dans `pushElemSRT` du fork : la matrice d'un élément est faite de son inclinaison, de son échelle, de sa rotation, puis de sa position. Le batch applique ensuite sa propre matrice. Le coin de la tuile est le point `(dx, dy)` de l'élément.

#### Les éléments se dessinent dans l'ordre de la liste

`{#html5.h2d.batch::elements-in-list-order}`

L'ordre est celui de la liste du fork, triée par priorité. Une priorité plus haute est plus loin : elle se dessine d'abord. Un élément invisible ne se dessine pas.

#### L'alpha d'un élément se combine avec celui du batch

`{#html5.h2d.batch::element-alpha-times-batch-alpha}`

Comme dans le shader du fork : alpha dessiné = alpha de l'élément × alpha du batch.

#### Un batch statique garde ses positions jusqu'à `invalidate()`

`{#html5.h2d.batch::static-until-invalidate}`

Après `optimizeForStatic(true)`, le batch calcule ses éléments au premier dessin, puis les garde. Un élément déplacé ne bouge à l'écran qu'après `invalidate()`. Le batch lui-même peut bouger : ses éléments le suivent. Le jeu compte sur ce comportement (`Wall`, `UITop`, `Levels`).

#### Un batch trop grand ne dessine rien

`{#html5.h2d.batch::too-many-elements-draws-nothing}`

Au-delà de 4 096 éléments, le fork ne dessine rien en release, et lève une erreur en debug. La couche fait la même chose.

#### Un `HSpriteBE` animé montre son image courante

`{#html5.slb::batch-sprite-shows-its-frame}`

Un `HSpriteBE` qui joue une animation dans un batch se dessine avec la découpe de son image courante, pivot compris, comme un `HSprite`.

### Critères d'acceptation (`--interp`)

- Étant donné un batch vide, quand la scène se dessine, alors le batch ne dessine rien.
- Étant donné un batch en (100, 50) et un élément en (10, 20) avec une tuile décalée de (-4, -6), quand la scène se dessine, alors le coin est en (106, 64).
- Étant donné un élément tourné d'un quart de tour avec une échelle de 2, dans un batch d'échelle 3, quand la scène se dessine, alors la matrice est celle du fork composée avec celle du batch.
- Étant donné un élément d'échelle 2 tourné de 0,5 dans un batch tourné de 0,3, quand la scène se dessine, alors `a = 2 cos 0,8` et `b = 2 sin 0,8` : les rotations s'additionnent. Avec un batch seulement mis à l'échelle, une composition transposée passerait inaperçue.
- Étant donné un élément de priorité 0 puis un élément de priorité 5, quand la scène se dessine, alors celui de priorité 5 se dessine d'abord.
- Étant donné un élément invisible, quand la scène se dessine, alors il n'est pas dessiné.
- Étant donné un élément d'alpha 0,5 dans un batch d'alpha 0,5, quand la scène se dessine, alors l'alpha dessiné vaut 0,25.
- Étant donné un batch statique déjà dessiné, quand un élément bouge, alors il est dessiné à son ancienne place. Après `invalidate()`, il est dessiné à la nouvelle.
- Étant donné un batch statique déjà dessiné, quand le batch bouge, alors ses éléments le suivent.
- Étant donné 4 097 éléments, quand la scène se dessine, alors le batch ne dessine rien.
- Étant donné un `HSpriteBE` qui joue `gripAnim`, quand l'animation passe à l'image k, alors la découpe dessinée est celle de l'image k.

### Hors périmètre

- `hasRotationScale = false` : le jeu ne le met jamais.
- La couleur des éléments (`BatchElement.color`) : elle va avec la couleur des `Drawable` (section suivante).

## Couleur et modes de fusion

### Règles

#### Un mode de fusion donne les facteurs GPU du fork

`{#html5.h2d.color::blend-mode-like-fork}`

Chaque mode du fork est une paire de facteurs de mélange GPU (`Drawable.setupShader`). PixiJS utilise la même paire :

| Mode du fork | Facteurs du fork | Mode PixiJS |
|---|---|---|
| `Normal` | `SrcAlpha` (ou `One` si prémultiplié), `OneMinusSrcAlpha` | `NORMAL` |
| `Add` | `SrcAlpha` (ou `One`), `One` | `ADD` |
| `Multiply` | `DstColor`, `OneMinusSrcAlpha` | `MULTIPLY` |
| `None` | `One`, `Zero` | `NONE` |
| `Screen` | `One`, `OneMinusSrcColor` | `SCREEN` |
| `Erase` | `Zero`, `OneMinusSrcAlpha` | `ERASE` |
| `SoftAdd` | `OneMinusDstColor`, `One` | mode ajouté (id 100) |
| `SoftOverlay` | `DstColor`, `One` | mode ajouté (id 101) |

Les éléments d'un batch prennent le mode du batch.

À vérifier à la parité (étape 4) : PixiJS travaille en alpha prémultiplié. Pour `Multiply` et `SoftOverlay` avec un alpha plus petit que 1, le résultat peut différer du Flash.

#### La couleur suit le shader du fork

`{#html5.h2d.color::color-like-fork-shader}`

Le shader du fork transforme la couleur d'un pixel dans cet ordre : couleur de l'élément (batch), alpha, `colorMatrix` (vecteur ligne : `sortie_j = Σ entrée_i × M_ij`, comme `h3d.Vector.transform`), `color`, puis `colorAdd`. Tout est linéaire : la couche en fait une seule matrice 5 × 4, appliquée par le `ColorMatrixFilter` de PixiJS, qui travaille comme le fork sur des couleurs non prémultipliées, avec des décalages de 0 à 1.

Sans couleur, la commande n'a pas de matrice : le sprite n'a pas de filtre, et l'alpha passe par `sprite.alpha`.

Piège connu (Kadokadeo) : le premier filtre utilisé compile un shader et fige le jeu de 10 à 80 ms. À traiter quand les écrans du jeu tourneront (étape 4) : préparer les filtres au démarrage.

### Critères d'acceptation

- (`--interp`) Étant donné un `Drawable` sans mode, quand la scène se dessine, alors il est dessiné en `Normal`. En `Add`, il est dessiné en `Add`.
- (`--interp`) Étant donné un batch en `SoftOverlay`, quand la scène se dessine, alors ses éléments sont dessinés en `SoftOverlay`.
- (`--interp`) Étant donné un `Drawable` sans couleur, quand la scène se dessine, alors la commande n'a pas de matrice, et garde son alpha.
- (`--interp`) Étant donné `color = new Vector()` (noir) et `colorAdd = fromColor(0x00483929)` (silhouettes de `Collection`), quand la scène se dessine, alors la matrice donne le brun 0x483929 et garde l'alpha de l'image.
- (`--interp`) Étant donné `getColorizeMatrixH2d(0xECB96C, 0.5, 0.5)` (survol de `ButtonWorld`), quand la scène se dessine, alors la matrice a les lignes du filtre Flash `getColorizeFilter(0xECB96C, 0.5, 0.5)`.
- (`--interp`) Étant donné un alpha de 0,5 et `colorAdd` d'alpha 0,25, quand la scène se dessine, alors l'alpha sorti vaut `0,5 a + 0,25` : l'alpha passe avant l'ajout.
- (`--interp`) Étant donné un élément de batch de couleur (0,5 ; 1 ; 1), quand la scène se dessine, alors son rouge est divisé par deux.
- (Playwright) Étant donné le canard en noir avec du rouge pur ajouté, quand il est dessiné, alors le pixel de son centre vaut exactement (255, 0, 0). Des décalages lus de 0 à 255 donneraient presque du noir.
- (Playwright) Étant donné le canard sur fond noir, quand il passe en `SoftOverlay`, alors le pixel de son centre devient noir (`noir × (1 + source) = noir`), alors qu'il était jaune en `Normal`. Ce test lit le pixel rendu par le GPU : il prouve que le mode ajouté est bien utilisé.
