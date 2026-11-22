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

## `Layers`

La `h2d.Layers` du fork ne touche pas au GPU : elle range ses enfants par calque dans la liste de `Sprite`. Le build JS l'utilise telle quelle, par le chemin de sources. Ses tests fixent l'ordre de dessin réel, à travers la scène de la couche.

### Règle

#### Les enfants se dessinent par calque

`{#html5.h2d.layers::drawn-by-layer}`

Un calque plus haut se dessine par-dessus un calque plus bas, quel que soit l'ordre d'ajout. `over` et `under` déplacent un enfant en haut ou en bas de son calque, sans le faire changer de calque. `ysort` dessine un calque du haut vers le bas de l'écran. Retirer un enfant garde les calques à leur place.

### Critères d'acceptation (`--interp`)

- Étant donné un enfant au calque 2 puis un enfant au calque 0, quand la scène se dessine, alors le calque 0 est dessiné d'abord.
- Étant donné deux enfants au calque 0 et un au calque 1, quand le premier passe `over`, alors il est dessiné après l'autre enfant du calque 0, mais avant le calque 1.
- Étant donné un enfant au calque 0 et deux au calque 1, quand le dernier passe `under`, alors il est dessiné avant l'autre enfant du calque 1, mais après le calque 0.
- Étant donné un enfant retiré du calque 0, quand un nouvel enfant y est ajouté, alors il est encore dessiné sous le calque 1.
- Étant donné deux enfants d'un calque en y = 50 puis y = 10, quand on appelle `ysort`, alors celui en y = 10 est dessiné d'abord.

## `Font` et `Text`

`h2d.Font` et la mise en page de `h2d.Text` (`_initGlyphs`) ne touchent pas au GPU : le build JS les prend dans le fork, tels quels. La couche remplace `TileGroup`, qui dessine les glyphes, et donne à `Drawable` l'état que le fork garde dans son shader (alpha, `color`, `colorAdd`, `colorMatrix`).

Le jeu utilise `textColor` (65 fois), `maxWidth` (55), `textAlign` (32), `letterSpacing` (9) et `lineSpacing` (3). Il n'utilise ni `dropShadow` ni `rangeMin` / `rangeMax`.

### Règle

#### Un texte se met en page comme dans le fork

`{#html5.h2d.text::layout-like-fork}`

Les glyphes se suivent de leur largeur plus l'espacement des lettres. Un retour à la ligne descend d'une hauteur de ligne plus l'interligne, et ne dessine rien. Un mot qui dépasse `maxWidth` passe à la ligne suivante, et l'espace qui le précède disparaît. L'alignement à droite ou centré se calcule dans `maxWidth`. `textColor` colore les glyphes. Le texte partage son shader avec ses glyphes, comme dans le fork : changer l'alpha du texte change celui des glyphes.

### Critères d'acceptation (compilés en JS, lancés par Node)

Police de test : A fait 6 px de large, B 7, l'espace 3, é 6. Les lignes font 10 px.

- Étant donné « AB », quand la scène se dessine, alors B est à x = 7 (6 px de A, plus 1 px d'espacement).
- Étant donné « A\nB », quand la scène se dessine, alors B est en (0, 10), et le retour à la ligne ne dessine rien.
- Étant donné « AB » aligné à droite dans 30 px, quand la scène se dessine, alors A est à x = 15.
- Étant donné « AB » centré dans 30 px, quand la scène se dessine, alors A est à x = 7 (`(30 − 15) >> 1`).
- Étant donné « A AB » dans 12 px, quand la scène se dessine, alors « AB » passe à la ligne, et l'espace disparaît.
- Étant donné « é », quand la scène se dessine, alors il est dessiné avec son propre glyphe.
- Étant donné un texte rouge, quand la scène se dessine, alors ses glyphes ne gardent que le rouge.
- Étant donné un texte à l'alpha 0,5, quand la scène se dessine, alors ses glyphes sont dessinés à l'alpha 0,5.

#### Une police se construit comme avec le `FontBuilder` du fork

`{#html5.h2d.text::font-built-like-fork}`

Le `FontBuilder` du fork dessine chaque caractère avec un `TextField` Flash. Celui de la couche le dessine avec Canvas 2D, et garde les mêmes règles : largeur d'un glyphe = largeur mesurée arrondie au-dessus, hauteur de ligne = plus grande hauteur de glyphe + 1, même rangement des glyphes dans la texture. La police doit être chargée par le navigateur (`FontBuilder.load`, avec l'API `FontFace`). Sinon, `getFont` échoue et nomme la police, au lieu de dessiner avec une police de secours.

`document.fonts.check()` ne suffit pas : il répond « oui » pour une famille qu'il ne connaît pas. La couche cherche la famille dans `document.fonts`, avec le statut `loaded`.

Les métriques de Canvas 2D peuvent différer d'un pixel de celles de Flash. La parité par captures (étape 4) mesurera cet écart.

### Critères d'acceptation (Playwright)

- Étant donné BenchNine chargée en 44 px, quand on construit la police, alors la largeur du glyphe « A » vaut la largeur mesurée par Canvas 2D, arrondie au-dessus, et la hauteur de ligne vaut la hauteur de la police + 1.
- Étant donné la police construite, quand on demande « é », alors il a son propre glyphe.
- Étant donné le titre « Rockfaller Journey : été », quand la page se dessine, alors plus de 100 pixels de sa zone sont allumés sur le fond noir.
- Étant donné une police jamais chargée, quand on la construit, alors l'erreur contient son nom.

Note sur les tests de pixels : depuis l'écran, `extract.pixels()` de PixiJS 6 rend l'image retournée verticalement. Les tests lisent l'écran avec `extract.canvas()`. Le premier test de pixel (le canard, au milieu de l'écran) passait par chance.

## `Interactive`

Le jeu utilise `onClick` (15 fois), `onRelease` (7), `onOut` (8), `onOver` (6), `onPush` (6), `backgroundColor` (4), `cursor` et `propagateEvents` (1 fois chacun). Il appelle lui-même `checkEvents()` sur sa scène, dans `Process.updateAll`.

### Règles

#### Les événements suivent la scène du fork

`{#html5.h2d.interactive::events-like-fork}`

Le code d'événements de la `Scene` et de l'`Interactive` du fork est repris tel quel : file d'événements vidée par `checkEvents()`, interactive du dessus servi d'abord, `propagateEvents`, entrée et sortie, appui et relâchement, parents invisibles ignorés.

La scène du fork met tout l'arbre dans l'espace normalisé du GPU (−1 à 1, y vers le haut), et son test de clic y travaille, avec une correction d'aspect. La couche reste en pixels : le test de clic convertit les matrices vers cet espace avant le calcul du fork. Une comparaison sur 40 000 cas tirés au hasard montre que les deux calculs coïncident sans rotation, avec une rotation à échelle uniforme, et avec les deux axes retournés. Ils diffèrent dans deux cas, qui sont des quirks du fork, gardés :

- un `Interactive` retourné sur un seul axe ne reçoit jamais de clic (son test d'orientation rejette les matrices de déterminant négatif) ;
- un `Interactive` tourné et mis à l'échelle de façon non uniforme a une zone de clic déformée.

Comme dans le fork, un événement arrivé avant le premier `checkEvents()` est ignoré. Un appui, une sortie, puis un relâchement dehors ne font pas de clic.

#### Le fond d'un `Interactive` est un rectangle de sa couleur

`{#html5.h2d.interactive::background-color}`

Avec `backgroundColor`, l'`Interactive` dessine un rectangle de sa taille, de cette couleur et de cet alpha (`0xAARRGGBB`).

#### Le pointeur vient du canevas

`{#html5.h2d.interactive::pointer-from-canvas}`

`hxd.Stage` écoute les événements « pointer » du canevas : souris et toucher passent par le même chemin. Les positions sont en pixels du jeu, même quand la page affiche le canevas à une autre taille. Le curseur suit celui de l'`Interactive` survolé.

### Critères d'acceptation

Compilés en JS, lancés par Node :

- Étant donné un `Interactive` de 50 × 30 en (100, 100), quand on clique en (110, 120), alors il reçoit `push`, `release`, puis `click` en (10, 20).
- Étant donné le pointeur qui entre puis sort, alors il reçoit `over` puis `out`.
- Étant donné un appui, une sortie, puis un relâchement dehors, alors il n'y a pas de clic.
- Étant donné deux `Interactive` superposés, quand on clique, alors seul celui du dessus reçoit le clic. Avec `propagateEvents` sur celui du dessus, celui du dessous le reçoit aussi.
- Étant donné un parent invisible, quand on clique, alors l'`Interactive` ne reçoit rien.
- Étant donné un `Interactive` retourné sur un axe (`scaleX = -1`), quand on clique dans sa zone, alors il ne reçoit rien (quirk du fork).
- Étant donné un `Interactive` tourné d'un quart de tour, quand on clique en (90, 110), alors il reçoit le clic en (10, 10).
- Étant donné `backgroundColor = 0x80FF0000`, quand la scène se dessine, alors un rectangle rouge de 50 × 30, à l'alpha 0x80, est dessiné en (100, 100).

Playwright :

- Étant donné la page, quand on clique sur le canard avec la souris, alors son `Interactive` reçoit le clic. Un clic à côté ne le touche pas.
- Étant donné le canevas affiché à la moitié de sa taille, quand on clique sur le canard, alors le clic l'atteint.
- Étant donné la souris sur le canard, alors le curseur devient une main.
- Étant donné un écran tactile, quand on touche le canard, alors son `Interactive` reçoit le clic.

## `Graphics`

Le jeu n'utilise `h2d.Graphics` qu'à un endroit : l'écran noir des transitions (`ProcessManager`), un rectangle plein sur toute la scène, dont l'alpha est animé. `mt.gx.h2d.Proto` et `mt.deepnight.hui` l'utilisent aussi, mais le code du jeu ne les atteint pas.

### Règle

#### Les rectangles pleins se dessinent dans leur couleur

`{#html5.h2d.graphics::filled-rectangles}`

Entre `beginFill(couleur, alpha)` et `endFill()`, `drawRect` ajoute un rectangle de cette couleur et de cet alpha. Comme dans le fork, l'octet du haut de la couleur n'est pas l'alpha. Un `drawRect` hors d'un remplissage ne dessine rien. `clear()` retire les rectangles. L'alpha du `Graphics` s'ajoute à celui du remplissage.

Les lignes, les cercles et les polygones du fork ne sont pas portés : un appel échoue à la compilation.

### Critères d'acceptation (compilés en JS, lancés par Node)

- Étant donné l'écran noir de `ProcessManager`, quand la scène se dessine, alors un rectangle noir opaque de 640 × 768 est dessiné en (0, 0).
- Étant donné l'écran noir à l'alpha 0,5, alors il est dessiné à moitié transparent.
- Étant donné un remplissage rouge puis un remplissage bleu à l'alpha 0,5, alors chaque rectangle garde sa couleur.
- Étant donné un `drawRect` sans `beginFill`, alors rien n'est dessiné.
- Étant donné `clear()`, alors rien n'est dessiné.
