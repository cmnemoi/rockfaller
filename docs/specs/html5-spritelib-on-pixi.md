# La SpriteLib sur PixiJS

Étape 2 de [`html5-migration.md`](html5-migration.md). Elle remplace l'ancienne cible « grille d'un niveau » : l'inventaire ([`html5-inventory.md`](html5-inventory.md)) a montré que cette grille demande presque tout le jeu.

## Pourquoi

Le jeu dessine presque tout avec la SpriteLib : `BLib` (la bibliothèque de sprites d'un atlas), `HSprite` (un sprite animé) et `AnimManager` (ses animations). Si ce vrai code tourne sur PixiJS, la couche `h2d` a sa première preuve. Et rien n'est écrit pour être jeté.

## Périmètre

- Le Parallel Change de `BLib` : sa partie Flash passe sous `#if flash`.
- Les premières classes de la couche `h2d` sur PixiJS, celles dont `HSprite` a besoin : `h2d.Tile`, `h2d.Sprite`, `h2d.Drawable`, `h2d.Bitmap`, la scène et son rendu, et `h3d.mat.Texture`.
- La page `/pixi/` joue l'animation `gripAnim` de `taupinotron` avec les vrais `BLib`, `HSprite` et `AnimManager`.

## Contraintes

- `HSprite`, `AnimManager` et `SpritePivot` ne changent pas. La couche `h2d` s'adapte à eux, pas l'inverse.
- La couche reproduit le modèle de rendu de Heaps : à chaque image, la scène parcourt l'arbre et appelle `draw(ctx)` sur chaque objet. `HSprite.draw` appelle `drawTile(ctx, tile)`, et la couche montre cette tuile avec PixiJS.
- `h2d.Tile` ne dépend pas de PixiJS : il tient un `h3d.mat.Texture`, comme dans Heaps. Seule la `Texture` tient la texture PixiJS. Le lien avec PixiJS est sous `#if js`. La logique de la couche (tuiles, arbre, `HSprite`) se teste donc avec `--interp`.
- Le build JS définit `h3d`, comme le build Flash : `BLib` et `HSprite` prennent leur chemin Heaps.

## Règles

### `BLib` compile sans Flash

`{#html5.slb::blib-without-flash}`

`BLib` compile pour JS. Sa partie Flash (`BitmapData`, `BSprite`, `flash.geom`, `flash.display`) n'existe que dans le build Flash. Dans le build Flash, `BLib` ne change pas.

### Le build Flash reste identique

`{#html5.slb::flash-build-unchanged}`

Le SWF construit avant et après le Parallel Change de `BLib` est identique, octet pour octet. Si le build n'est pas déterministe, on compare le code compilé de `BLib`, à la place.

### Les images d'un groupe et ses animations restent celles de Flash

`{#html5.slb::same-groups-and-anims}`

À partir du même atlas, `BLib` donne les mêmes groupes, les mêmes images (rectangle, cadre d'origine) et les mêmes animations dans les deux builds. Un groupe ou une image inconnus donnent la même erreur qu'aujourd'hui.

### Une animation avance comme dans Flash

`{#html5.slb::anim-steps-like-flash}`

`AnimManager` ne change pas, donc la suite des images ne change pas, quirks compris. Exemple : le compteur doit dépasser 1 strictement avant de passer à l'image suivante, donc la première image dure plus longtemps. Les tests fixent la suite des images de `gripAnim` pour une suite de mises à jour, et le retour à la première image après la dernière.

### Une tuile se dessine à sa place, pivot compris

`{#html5.h2d::tile-drawn-at-its-place}`

Une tuile se dessine à la position de son objet, décalée de `dx` et `dy`. Pour un sprite rogné, centré par `setCenterRatio(0.5, 0.5)`, le centre du cadre d'origine tombe sur la position du sprite. Exemple avec `animalDuck` (découpe 61 × 67, décalage (-20, -16), cadre 98 × 98) placé en (100, 100) : `dx = -(98 × 0.5 - 20) = -29` et `dy = -(98 × 0.5 - 16) = -33`. Le coin de la découpe est donc en (71, 67).

### Les positions se composent dans l'arbre

`{#html5.h2d::positions-compose}`

Un objet enfant se dessine à la position de son parent plus la sienne, échelle et rotation du parent comprises. Un objet retiré de l'arbre n'est plus dessiné. Les enfants se dessinent dans l'ordre de la liste, le dernier par-dessus.

### Un sprite retourné garde son pivot

`{#html5.h2d::flip-keeps-pivot}`

Avec `scaleX = -1`, le sprite se dessine en miroir autour de sa position : la découpe passe de l'autre côté du pivot, comme dans Heaps.

### La page joue `gripAnim`

`{#html5.slb::page-plays-grip-anim}`

La page `/pixi/` joue en boucle l'animation `gripAnim` de `taupinotron` (dossiers en préfixe), centrée dans le canevas, à 30 mises à jour par seconde comme le jeu. Elle montre aussi `animalDuck` avec `HSprite`, centré par son pivot, à gauche du grappin. Une image compte pour 100 ms au plus : un onglet caché ne fait pas avancer l'animation en accéléré au retour.

## Critères d'acceptation

Tests `--interp` en Haxe 4.3.7, avec la couche `h2d` (le build Flash est protégé par la comparaison des SWF) :

- Étant donné `taupinotron.xml` lu par `TexturePacker.parseXml`, quand on lit le groupe `gripAnim`, alors il a les images et l'animation données par `TexturePackerXml`.
- Étant donné un `BLib`, quand on demande `getFrameData("inconnu")`, alors on obtient `null`. Quand un `HSprite` prend ce groupe, alors il lève `Unknown frame: inconnu(0)`.
- Étant donné un `HSprite` qui joue `gripAnim` en boucle, quand on fait N mises à jour, alors l'image courante suit la suite fixée par le test, et elle revient à 0 après la dernière image.
- Étant donné `animalDuck` centré en (100, 100), quand on demande sa tuile, alors `dx = -29` et `dy = -33`.
- Étant donné une tuile, quand on la clone puis qu'on change la copie, alors l'originale ne change pas.

Tests Playwright dans le Chrome installé (`mise run test:site`, build de debug de la page) :

- Étant donné la page chargée, quand on compare chaque commande de dessin au sprite PixiJS qui la montre, alors la découpe, la matrice et l'alpha sont les mêmes, dans le même ordre.
- Étant donné le canard tourné, retourné (`scaleX = -1.5`) et à moitié transparent, quand on fait la même comparaison, alors elle tient encore. Sans rotation, les axes `b` et `c` valent 0 et une inversion passerait inaperçue.
- Étant donné la page, quand l'animation est sur l'image k, alors PixiJS montre la découpe de l'image k.
- Étant donné le grappin retiré de la scène, quand la scène se redessine, alors PixiJS ne montre plus que le canard.

La composition des positions (parent, échelle, retournement) est vérifiée sur les commandes, avec `--interp`. Le test Chrome vérifie que PixiJS recopie les commandes sans erreur.

Vérification du build Flash :

- Étant donné le SWF avant et après le Parallel Change de `BLib`, quand on les compare, alors ils sont identiques (ou le code compilé de `BLib` l'est, si le build n'est pas déterministe).

## Hors périmètre

- `h2d.Text`, `h2d.Font`, `h2d.Interactive`, `h2d.Layers`, `h2d.SpriteBatch` et `HSpriteBE` : étape 3.
- `Drawable.color` plus grand que 1 (par exemple, `colorize` avec une échelle de 2). La teinte de PixiJS ne peut que foncer une image, pas l'éclaircir. Question pour l'étape 3 : filtre de couleur, ou autre solution ?
- `Drawable.filter` (lissage par sprite). PixiJS règle le lissage par texture, et tous les sprites d'un atlas partagent la même texture. Question pour l'étape 3.
- Le script de captures de parité et le calibrage du seuil N : ils arrivent avec le premier écran réel du jeu en JS (l'accueil, étape 4).
- Les parties Flash de `BLib` (`BSprite`, `initBdGroups`, `parseAttachPoints`…) en JS : seul le préchargeur Flash les utilise.
