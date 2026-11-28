# Plan d'implémentation : performances de la version PixiJS

Ce plan suit l'audit [`html5-performance.md`](html5-performance.md). Il corrige ses 7 problèmes en 9 lots, du plus rentable au plus incertain.

## Principes

- **Tester des comptes, pas des durées.** Les tests de budget comptent des choses exactes : changements de cible de rendu, appels GPU, sprites filtrés, programmes liés, rappels `requestAnimationFrame`. Ces comptes ne dépendent ni de la machine ni de SwiftShader : ils tiennent en CI. Les durées (images par seconde, millisecondes) se mesurent avec la sonde, à la main, et se notent dans l'audit.
- **Un filet de parité avant chaque changement de rendu.** Des tests au pixel décrivent le rendu actuel des couleurs. Ils passent avant le changement, et doivent passer après. Le rendu ne doit pas changer à l'œil.
- **Tests d'abord.** Un test de budget est rouge avant son lot, vert après. Un test de parité est vert avant et après.
- **La couche seulement.** Tout se passe dans `html5/src`, `html5/` et `tools/`. Le code partagé du jeu ne change pas, donc le SWF non plus. Si un lot doit y toucher, c'est un Parallel Change, et le SWF reste identique octet pour octet.
- **Mesurer avant et après chaque lot**, avec la sonde, et noter les chiffres dans une section « Suivi » de l'audit.
- Chaque commit passe `mise run test` et `mise run test:site`, puis part sur `main`.

## Où vivent les règles

| Spec | Règles |
|---|---|
| `html5-performance-budgets.md` (créée au lot 0) | Les budgets observables : compteur, passes de rendu, programmes, boucle, déchets, mémoire du son, envois de textures |
| [`html5-h2d-layer.md`](html5-h2d-layer.md), section « Couleur et modes de fusion » | Comment la couleur est dessinée : teinte native, matrice dans le lot |
| [`html5-h2d-layer.md`](html5-h2d-layer.md), nouvelles sections | Shaders prêts, réglages du renderer, cadence de la boucle |
| [`html5-sound.md`](html5-sound.md) | Les musiques non gardées décodées |
| [`html5-boot.md`](html5-boot.md) (créée en avance) | Les règles `html5.boot::*` et `html5.assets::*` déjà citées par le code, et l'envoi des textures |

Chaque lot écrit ses règles dans la spec **avant** ses tests.

## Fichiers

| Chemin | Rôle |
|---|---|
| `html5/perf-meter.js` | Les compteurs (WebGL, PixiJS, `requestAnimationFrame`) et l'affichage `?perf`. Inactif sans `?perf` dans l'adresse. |
| `tools/perf.mjs` | La sonde : parcours Playwright, mesures, profil CPU, allocations. |
| `html5/test/perf-budget.spec.mjs` | Les tests de budget, sur la vraie page du jeu. |
| `html5/src/Demo.hx` | La page de démo gagne un banc de couleurs pour les tests de parité. |
| `html5/src/PixiRenderer.hx` | Teinte native, greffon de couleur. |
| `html5/src/ColorMatrixBatch.hx` | Le greffon de lot PixiJS : matrice de couleur par sprite. |
| `html5/src/h3d/Engine.hx` | Réglages du renderer, shaders préparés. |
| `html5/src/hxd/System.hx` | Cadence de la boucle. |
| `html5/src/h2d/RenderContext.hx`, `SpriteBatch.hx`, `TileGroup.hx` | Moins de déchets. |
| `html5/src/mt/audio/` | Les musiques. |
| `html5/src/GameMain.hx` | Préparation des textures. |

## Lot 0 : la sonde et le compteur — taille S

**But.** Mesurer pareil partout : en CI, sur cette machine et sur un téléphone.

Règles (`html5-performance-budgets.md`) :

- `html5.perf::meter-off-by-default` : sans `?perf` dans l'adresse, le compteur ne s'installe pas et la page ne change pas. Avec `?perf`, il compte par image : appels GPU, changements de cible de rendu, sprites filtrés et masqués, programmes liés, envois de textures, rappels `requestAnimationFrame`, temps JS. Il affiche, deux fois par seconde, les images rendues par seconde et ces comptes. Il les expose dans `window.rockfallerPerf`.
- La spec liste aussi tous les budgets des lots 1 à 8, avec leur lot. Ils sont rouges, sauf ceux déjà tenus.

Tests d'abord (`perf-budget.spec.mjs`) :

- Sans `?perf`, la page n'a ni affichage, ni `window.rockfallerPerf`.
- Avec `?perf`, après 2 s, le compteur a vu des images, et des appels GPU dans chacune.

Changement :

- `html5/perf-meter.js`, chargé en premier par `game.html`. C'est le code d'instrumentation de la sonde de l'audit, sorti dans un fichier. Il pose ses crochets sur les prototypes WebGL et sur `PIXI.Renderer.prototype.render` avant la création du renderer.
- `tools/perf.mjs` : les parcours de l'audit (tutoriel, projecteur, carte, défilement, fenêtre de niveau, partie, coups). La sauvegarde « niveau 5 » est écrite dans le script. Options : CPU ralenti, nombre d'unités de texture, temps GPU par `EXT_disjoint_timer_query_webgl2`. Sortie : un JSON et un tableau Markdown, à coller dans l'audit.
- Tâche `mise run perf`, hors de `mise run test` et hors CI : elle mesure des durées.

Vérification : `mise run perf` redonne les chiffres de l'audit, à 10 % près. Sur un téléphone, `/pixi/game.html?perf` affiche les compteurs.

## Lot 1 : teinte native — taille S

**But.** Retirer les filtres des textes : tous ceux de la carte et des fenêtres.

Règles :

- `html5.h2d.color::multiplied-color-as-tint` (`html5-h2d-layer.md`) : une couleur qui multiplie seulement chaque canal, par un facteur entre 0 et 1, est dessinée par la teinte et l'alpha de PixiJS, sans filtre.
- `html5.perf::no-render-pass-on-menus` : sur la carte et sur la fenêtre de niveau, aucune image ne change de cible de rendu, et aucun sprite n'a de filtre.

Tests d'abord :

1. **Parité, verts avant et après** (Playwright, page de démo, banc de couleurs) :
   - un texte blanc de couleur `0x804020` se lit `(128, 64, 32)`, à 1 près ;
   - un sprite blanc de couleur `(0.5, 1, 1)` et d'alpha 0,5, sur fond noir, se lit `(64, 128, 128)`, à 1 près ;
   - une couleur qui ne change que l'alpha donne le même gris que l'alpha seul ;
   - un sprite d'alpha 0 ne laisse aucune trace.
2. **Budget, rouge** : `html5.perf::no-render-pass-on-menus`, sur la vraie page du jeu, avec la sauvegarde « niveau 5 ».

Changement : `PixiRenderer.showColor` reconnaît une matrice de teinte (pas de décalage, rien hors de la diagonale, diagonale entre 0 et 1). Il pose `tint` et `alpha`, et retire le filtre. Les autres matrices gardent le filtre jusqu'au lot 2.

Mesure attendue : carte et fenêtre de niveau au plafond (30 images/s), 5 à 10 appels GPU par image.

Risque : la teinte de PixiJS a 8 bits par canal. L'écart avec le filtre est au plus de 1/255 : les tests le tolèrent.

## Lot 2 : la matrice de couleur dans le lot — taille L

**But.** Retirer les derniers filtres de couleur : les 300 particules de magma, en partie et au tutoriel.

### 2a. Essai limité dans le temps

Une séance au plus, sur une branche jetable. Questions :

- `BatchPluginFactory.create` de PixiJS 6.0.2 accepte-t-il notre shader, notre classe de géométrie et notre taille de sommet ?
- La géométrie peut-elle porter 8 attributs (position, coordonnée de texture, numéro de texture, 4 lignes de matrice, décalage) ? C'est le minimum garanti par WebGL 1.
- `packInterleavedGeometry` peut-il écrire ces attributs depuis le sprite ?
- Le shader peut-il lire plusieurs textures comme le shader de lot de PixiJS (`%count%`, `%forloop%`) ?
- Un sprite colorisé a-t-il les mêmes pixels qu'avec le filtre ?

Si une réponse est non, le lot passe au **repli** : un `PIXI.Mesh` par drawable coloré, avec la matrice en paramètre du shader. Il faut alors regrouper les commandes par drawable, et garder l'ordre de dessin.

### 2b. Le greffon

Règles :

- `html5.h2d.color::color-matrix-in-batch` (`html5-h2d-layer.md`) : une matrice de couleur qui n'est pas une teinte s'applique à chaque pixel dans le shader de lot, avant le mélange, comme le `DrawableShader` du fork. Le shader lit la texture, enlève la prémultiplication, applique la matrice et le décalage, borne le résultat entre 0 et 1, puis prémultiplie.
- `html5.perf::no-render-pass-in-game` : au tutoriel, en partie et pendant les coups, aucune image ne change de cible de rendu, sauf pour le masque du projecteur (2 changements par sprite masqué). Une image fait au plus 15 appels GPU.

Tests d'abord :

1. **Parité, verts avant et après** (page de démo) :
   - la colorisation du magma (`getColorizeMatrixH2d(0xD24217, 1, 0)`) sur un pixel blanc, puis gris, sur fond noir ;
   - un `SpriteBatch` colorisé dont les éléments ont des alphas différents : chaque élément garde son alpha ;
   - un `SpriteBatch` colorisé en mode `Add` sur un fond gris ;
   - le test existant « noir plus rouge ajouté » reste vert.
2. **Budget, rouge** : `html5.perf::no-render-pass-in-game`.

Changement :

- `ColorMatrixBatch.hx` : le greffon, et une extern locale pour `BatchPluginFactory`, absente des externs `pixi-haxe`. Il est enregistré avant la création du renderer.
- `PixiRenderer` : un sprite à matrice prend `pluginName = "colorMatrix"` et porte sa matrice. `ColorMatrixFilter` disparaît.

Mesure attendue : tutoriel, partie et coups au plafond, 5 à 12 appels GPU par image.

Risques :

- Le greffon repose sur l'intérieur de PixiJS 6.0.2. Une mise à jour de PixiJS devra le revoir.
- La précision `mediump` des téléphones sur les nombres de la matrice : à vérifier au jalon A.
- Des sprites colorés intercalés entre des sprites normaux coupent les lots. Mesuré par les appels GPU.

## Lot 3 : shaders prêts avant de jouer — taille S

Règles :

- `html5.h2d::shaders-ready-before-play` (`html5-h2d-layer.md`) : pendant le chargement, le moteur dessine une fois chaque cas de rendu (lot normal, greffon de couleur, masque) dans une petite `RenderTexture`, puis la libère.
- `html5.perf::no-shader-while-playing` : après la première image du jeu, aucun programme n'est lié, jusqu'au projecteur du tutoriel compris.

Tests d'abord : budget rouge, `html5.perf::no-shader-while-playing` (aujourd'hui : 2 programmes, 378 ms).

Changement : `Engine.init` prépare les shaders avant `onReady`.

Mesure attendue : l'image la plus longue au projecteur passe de 378 ms à moins de 50 ms.

Décision prise : le masque PixiJS reste. Un seul sprite est masqué ; lire l'`alphaMap` dans le shader de lot n'en vaut pas la peine aujourd'hui.

## Lot 4 : réglages du renderer — taille S

Règles :

- `html5.h2d::renderer-settings` (`html5-h2d-layer.md`) : le renderer n'a pas de gestionnaire d'interaction PixiJS ; il garde ses textures, comme `NoTextureGC` (ramasse-miettes de textures en manuel) ; son canvas est opaque.
- `html5.perf::one-loop` : la page reçoit un seul rappel `requestAnimationFrame` par image.

Tests d'abord :

- Budget rouge : `html5.perf::one-loop`.
- `renderer.plugins.interaction` est absent ; `renderer.textureGC.mode` vaut `MANUAL` ; `gl.getContextAttributes().alpha` vaut `false`.
- Les tests existants du pointeur restent verts, dont « le curseur devient une main ».

Changement : `Engine.init` crée le renderer avec `useContextAlpha: false`, détruit `plugins.interaction` et passe `textureGC.mode` en manuel.

Risque : Safari sur iOS ignorait autrefois le canvas opaque. Sans effet visible, car notre fond est noir.

## Lot 5 : la boucle à 30 images par seconde — taille S

Règles :

- `html5.h2d::loop-at-stage-rate` (`html5-h2d-layer.md`) : `hxd.System.setLoop` appelle la boucle du jeu au plus 30 fois par seconde, comme `ENTER_FRAME` à la cadence de la scène Flash. Sur un écran plus lent que 30 Hz, il l'appelle à chaque image. Une petite tolérance absorbe l'irrégularité des horodatages de `requestAnimationFrame`.
- `html5.perf::no-identical-frame` : à 60 Hz comme à 120 Hz, le jeu rend 30 images par seconde, à 1 près.

Tests d'abord (Node, `H2dCheck`, horodatages simulés) :

- écran à 120 Hz et à 60 Hz : 29 à 30 appels en une seconde ; à 144 Hz, 28 à 30, car les appels tombent toutes les 4 ou 5 images ;
- écran à 30 Hz : 30 appels ; à 20 Hz : 20 appels, un par image ;
- horodatages irréguliers de ±1 ms à 120 Hz : toujours 30 appels, à 1 près ;
- le test existant « une image qui échoue n'arrête pas la boucle » reste vert.

Changement : `hxd.System.runLoop` lit l'horodatage de `requestAnimationFrame`, et n'appelle la boucle que si l'intervalle est atteint. La vitesse du jeu ne change pas : `Main.update` compte déjà les pas avec `hxd.Timer.tmod`.

Mesure attendue, sur un écran à 120 Hz (compteur `?perf`) : 30 images rendues par seconde au lieu de 120, donc environ 4 fois moins de travail CPU et GPU par seconde.

Risque : l'irrégularité à 144 Hz, déjà présente aujourd'hui (voir l'audit).

## Lot 6 : moins de déchets par image — taille M

Fait après le lot 2, car il change les données que lit le greffon.

Règles :

- `html5.perf::little-garbage-per-frame` : une image rendue alloue au plus 100 Ko en moyenne, au tutoriel, sur la carte et en partie. Aujourd'hui : environ 1 070 Ko.
- `html5.h2d::commands-reused` (`html5-h2d-layer.md`) : `RenderContext` réutilise ses commandes d'une image à l'autre ; la couleur d'un drawable est calculée une fois par image, et chaque tuile ne garde que son multiplicateur (couleur de sommet et alpha).

Tests d'abord :

- Node : deux rendus de la même scène donnent les mêmes objets de commande ; toute la suite `H2dCheck` reste verte.
- Le budget d'allocation se mesure avec la sonde (HeapProfiler), pas en CI : l'échantillonnage du tas varie d'une exécution à l'autre.

Changement :

- `RenderContext` : un réservoir de commandes ; `colorMatrixOf` se coupe en deux, la couleur du drawable une fois, le multiplicateur par tuile.
- `SpriteBatch` et `TileGroup` : un tableau de quads réutilisé.
- `PixiRenderer` : une `Matrix` de travail, et la découpe copiée dans le `Rectangle` existant.
- Le greffon de couleur combine la couleur du drawable et le multiplicateur de la tuile en écrivant ses sommets, sans allouer.

Risque : une commande réutilisée alors qu'elle est encore lue. Les tests d'ordre de dessin et de rendu la détectent.

### Lot 6b, en option : les nombres des commandes dans des tableaux typés

Fait au lot 6 : environ 270 Ko par image au lieu de 950. Le reste vient de V8, qui met en boîte chaque nombre flottant écrit dans un champ d'objet. Ranger les nombres des commandes dans un tableau typé par image (`Float64Array`) le supprimerait, mais change l'API des commandes, que lisent `PixiRenderer` et les tests. À faire seulement si le jalon A montre des saccades de ramasse-miettes sur téléphone.

## Jalon A : mesure sur téléphone

Après les lots 0 à 5, et si possible le 6. Sur au moins un téléphone Android modeste, et un iPhone si possible, dans Chrome et dans Safari : `/pixi/game.html?perf`.

À noter dans l'audit, pour la carte, la partie et les coups : images rendues par seconde, image la plus longue, appels GPU. Noter aussi un plantage ou un rechargement de l'onglet, qui signale un manque de mémoire.

Ce jalon décide du lot 8 : envoyer toutes les textures, ou monde par monde, ou réduire les textures.

## Lot 7 : les musiques — taille M

Décision d'abord, avec toi, à l'écoute :

- **A. En flux** : `<audio>` et `MediaElementAudioSourceNode`. Les musiques ne prennent plus que quelques Mo ; il reste 63 Mo de bruitages. Risques : un blanc à la boucle, Safari.
- **B. Une seule décodée** : la musique est décodée quand elle commence, et l'autre est libérée. La boucle reste parfaite, mais il reste jusqu'à 143 Mo (80 Mo de musique de partie et 63 Mo de bruitages).
- **En plus de A ou B** : décoder les bruitages à 24 kHz divise leur taille par deux.

Un essai de A sur une branche jetable : les deux musiques en boucle, dans Chrome, Firefox et Safari, à comparer à l'oreille avec la version Flash.

Règles :

- `html5.sound::music-not-kept-decoded` (`html5-sound.md`) : selon le choix, en flux, ou une seule musique décodée à la fois.
- `html5.perf::sound-memory` : au démarrage, au plus 65 Mo de sons décodés avec A, ou 145 Mo avec B (moitié moins pour les bruitages à 24 kHz). Aujourd'hui : 209 Mo, dont 146 Mo de musiques.

Tests d'abord :

- Node (`SoundCheck`, faux moteur) : une musique se joue, boucle, change de volume, se coupe et s'arrête comme avec `Sfx` ; lancée avant le premier clic, elle s'entend après le clic, là où elle en est.
- Playwright : le test « la musique lancée avant le premier clic s'entend » s'adapte au nouveau chemin, et reste vert.
- La mémoire des sons se mesure avec la sonde.

Changement : `GameMain` ne décode plus les deux musiques au chargement ; `mt.audio` gagne le chemin choisi.

## Lot 8 : les textures — taille S à M

Selon le jalon A.

Règles :

- `html5-boot.md` existe déjà (créée en avance) : la règle s'y ajoute.
- `html5.boot::textures-sent-while-loading` : les textures sont envoyées au GPU pendant la barre de chargement. C'est toutes, ou celles du monde en cours, selon le jalon A.
- `html5.perf::no-upload-while-playing` : aucun envoi de texture pendant le défilement de la carte ni pendant une partie.

Tests d'abord : budget rouge, `html5.perf::no-upload-while-playing` (aujourd'hui : 5 à 11 envois pendant le défilement).

Changement : `GameMain` passe les textures au greffon `prepare` de PixiJS, une par image, pour ne pas geler la barre de chargement.

## Jalon B : bilan

Refaire `mise run perf` et la mesure sur téléphone. Mettre à jour l'audit : chaque problème est réglé, ou laissé de côté avec sa raison.

## Ordre et dépendances

```
0 ──► 1 ──► 2 ──► 3          (le rendu devient fluide)
0 ──► 4, 5                   (indépendants, peu coûteux)
2 ──► 6                      (le greffon lit les nouvelles données)
0..5 ──► jalon A ──► 7, 8 ──► jalon B
```

Ordre conseillé : 0, 1, 2, 3, 4, 5, 6, jalon A, 7, 8, jalon B. Les lots 1 à 3 rendent le jeu fluide dans Chrome. Les lots 4 à 6 divisent la charge pour les téléphones et la batterie. Les lots 7 et 8 réduisent la mémoire.

## Décisions à prendre

| Décision | Quand | Qui |
|---|---|---|
| Greffon de lot, ou repli par `Mesh` | Fin de l'essai 2a | Le résultat de l'essai |
| Musiques en flux (A) ou une seule décodée (B) | Lot 7, à l'écoute | Toi |
| Textures : toutes au chargement, par monde, ou réduites | Jalon A | Toi, sur les chiffres du téléphone |
| Atlas à demi-résolution ou textures compressées (PixiJS 6.1 ou plus) | Jalon A, si la mémoire manque | Toi |

## Hors périmètre

- L'interpolation entre les pas : elle changerait le rendu (règle de parité).
- Le passage à PixiJS 8 : il changerait les externs partagés avec Kadokadeo.
- La résolution du canvas sur écran Retina : un choix de rendu, à part.
- La mesure de Firefox par Playwright : son Firefox installé est trop vieux. Le compteur `?perf` permet de le mesurer à la main.
