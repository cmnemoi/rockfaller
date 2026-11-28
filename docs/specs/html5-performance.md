# Performances de la version PixiJS

Audit du 28 novembre 2026, sur le commit `ff186cd`. Partie de l'étape 4 de [`html5-migration.md`](html5-migration.md). Le plan qui en découle : [`html5-performance-plan.md`](html5-performance-plan.md).

## En bref

Dans Chrome, la version PixiJS dessine **9 à 12 images par seconde** sur un Apple M5. Sans ses filtres de couleur, elle atteint 30, le plafond de la mesure.

- Le CPU n'y est pour rien : il attend 90 à 97 % du temps.
- Le GPU est saturé par **576 à 756 changements de cible de rendu par image**. Chaque sprite coloré passe par son propre `ColorMatrixFilter`, c'est-à-dire un rendu dans une texture intermédiaire.
- Le fork Heaps n'a pas ce coût : sa matrice de couleur est un paramètre du shader. OpenFL fait le même choix. C'est ce qu'il faut refaire.

Les téléphones modestes sont une cible. Leurs GPU sont à tuiles, comme celui du M5, et Chrome y est le navigateur le plus courant : la mesure Chrome est donc le cas à viser.

| # | Problème | Effet mesuré | Correction | Coût |
|---|---|---|---|---|
| 1 | Un `ColorMatrixFilter` par sprite coloré | 9 à 12 images/s au lieu de 30 ; 585 à 763 appels GPU par image au lieu de 5 à 10 | Teinte native pour les couleurs qui multiplient ; matrice de couleur dans le shader de lot pour les autres | Moyen |
| 2 | Shader du masque compilé au premier usage | Le jeu gèle **378 ms** au projecteur du tutoriel | Compiler les shaders pendant le chargement | Faible |
| 3 | Rendu à chaque rafraîchissement de l'écran, alors que le jeu avance 30 fois par seconde | 1 image sur 2 identique à 60 Hz, 3 sur 4 à 120 Hz (déduit du code) | Appeler la boucle du jeu 30 fois par seconde, comme `ENTER_FRAME` | Faible |
| 4 | Environ 1 Mo d'objets jetés par image | 52,6 Mo alloués en 5 s | Réutiliser les commandes, les matrices et les couleurs | Moyen |
| 5 | Sons décodés d'avance, dont les deux musiques | 209 Mo de PCM en mémoire | Ne plus garder les musiques décodées | Moyen |
| 6 | Textures envoyées au GPU au premier affichage ; ramasse-miettes de textures de PixiJS actif | Saccade au défilement de la carte (14,7 ms d'envoi, CPU ×4) | Ramasse-miettes en manuel ; envoi pendant le chargement, selon la mémoire des téléphones | Faible |
| 7 | Réglages du renderer : gestionnaire d'interaction inutile, canvas transparent | Une 2e boucle `requestAnimationFrame` ; 800 à 1300 sprites testés à chaque mouvement du pointeur | Retirer le gestionnaire ; canvas opaque | Très faible |

## Méthode

### Machine et navigateur

- MacBook Pro, Apple M5, écran Retina 3024 × 1964. Le GPU offre 16 unités de texture et 16 attributs de sommet, en WebGL 2.
- Chrome 158 piloté par Playwright, en headless. Le WebGL passe par ANGLE sur Metal, donc par le vrai GPU, pas par SwiftShader. C'est la [leçon de Kadokadeo](https://github.com/eternaltwin/kadokadeo/blob/main/.opencode/skills/flash-port/references/testing.md) : SwiftShader fausse les mesures de performance.
- Version mesurée : le build release, `dist/web/pixi/game.js`, servi en local.
- Mesures refaites avec le CPU ralenti 4 fois (`Emulation.setCPUThrottlingRate`), pour approcher une machine modeste.

**Limites de la mesure.**

- Ici, une page vide reçoit 30 rappels `requestAnimationFrame` par seconde, en headless comme dans une fenêtre ouverte par Playwright. « 30 images par seconde » veut donc dire « au plafond », pas « au maximum de la machine ». Le cas 60 Hz ou 120 Hz n'a pas pu être mesuré : le problème 3 vient du code.
- Firefox n'est pas mesuré : le Firefox de Playwright installé ici est trop vieux. Un comptage à la main dans la console a donné 93, puis 537 images par seconde : ce chiffre n'est pas retenu.
- Aucun téléphone n'est mesuré.

### Ce que la sonde mesure

Un script injecté avant le chargement de la page compte, pour chaque image :

- le temps JavaScript de chaque rappel `requestAnimationFrame` ;
- le temps CPU de `PIXI.Renderer.render` ;
- les sprites PixiJS visibles, ceux qui ont un filtre et ceux qui ont un masque ;
- les appels WebGL `drawElements` et `drawArrays`, et les `bindFramebuffer` (changements de cible de rendu) ;
- les envois de textures (`texImage2D`, `texSubImage2D`), avec leur durée ;
- les programmes liés (`linkProgram`), avec leur durée.

Elle relève aussi un profil CPU, les allocations (HeapProfiler, objets ramassés compris), la taille des sons décodés et les octets téléchargés.

### Écrans mesurés

1. **Tutoriel** : nouvelle partie, première bulle du niveau 1, 6 s.
2. **Projecteur** : l'étape suivante du tutoriel, avec son `alphaMap`.
3. **Carte** : niveau 5 débloqué par une sauvegarde injectée dans `localStorage`, fenêtre LOGIN fermée, 5 s.
4. **Défilement de la carte** : 8 glissés de 400 px.
5. **Fenêtre du niveau 5** : 4 s.
6. **Partie** : niveau 5 lancé, 6 s sans rien faire.
7. **Coups** : 12 clics sur les coins des groupes de la grille. Un combo ×2 et un score de 2275 confirment que les coups ont été joués.

Variantes de diagnostic, sur le même parcours :

- **sans filtres** : la sonde retire les filtres juste avant chaque rendu. Les couleurs sont fausses, mais le coût sans filtres est mesuré ;
- **sans interaction** : la sonde détruit le gestionnaire d'interaction de PixiJS ;
- **4 ou 8 unités de texture** : la sonde fixe `PIXI.settings.SPRITE_MAX_TEXTURES` avant la création du renderer, comme sur un téléphone modeste.

## Résultats

### Images par seconde et travail du GPU

CPU à vitesse normale :

| Écran | Images rendues/s | Sprites | Sprites avec filtre | Appels GPU/image | Changements de cible/image |
|---|---|---|---|---|---|
| Tutoriel | 9,5 | 842 | 378 | 763 | 756 |
| Carte | 12,4 | 1228 | 288 | 585 | 576 |
| Fenêtre du niveau 5 | 12,5 | 1228 | 288 | 585 | 576 |
| Partie | 11,3 | 786 | 316 | 640 | 632 |
| Coups | — | 818 | 319 | 657 | 638 |

Même parcours, **sans filtres**, CPU ralenti 4 fois :

| Écran | Images rendues/s | Appels GPU/image | Changements de cible/image | JS par rappel (moyenne / p95 / max) |
|---|---|---|---|---|
| Tutoriel | 30,5 (plafond) | 5 | 0 | 0,76 / 2,3 / 2,9 ms |
| Carte | 30,6 (plafond) | 5 | 0 | 0,73 / 2,0 / 2,9 ms |
| Défilement de la carte | plafond | 7 | 0 | 1,06 / 2,9 / **16,2** ms |
| Fenêtre du niveau 5 | 30,5 (plafond) | 5 | 0 | 0,70 / 1,8 / 2,5 ms |
| Partie | 30,5 (plafond) | 5 | 0 | 0,65 / 1,9 / 2,9 ms |
| Coups | plafond | 9 | 0 | 1,09 / 3,0 / 8,5 ms |

Une fenêtre Chrome ouverte à l'écran donne les mêmes chiffres : 9,2 images/s avec les filtres, 30,3 sans.

Sans filtres, avec moins d'unités de texture (appels GPU par image, au plus) :

| Écran | 16 unités (M5) | 8 unités | 4 unités |
|---|---|---|---|
| Tutoriel | 5 | 6 | 7 |
| Carte | 5 | 5 | 8 |
| Défilement de la carte | 7 | 7 | 10 |
| Fenêtre du niveau 5 | 5 | 5 | 8 |
| Partie | 5 | 6 | 6 |
| Coups | 9 | 10 | 10 |

Une image affiche 11 à 13 textures différentes : les atlas et les textures des polices.

### Projecteur du tutoriel

- 2 programmes liés au premier affichage : 339 ms, puis 31 ms. L'image la plus longue dure 378 ms.
- Ensuite, 1 sprite masqué par image.

### Démarrage

| Mesure | Valeur |
|---|---|
| Octets téléchargés avant le jeu | 27,4 Mo (le SWF Flash pèse 39 Mo) |
| Dont images / sons / `game.js` / `pixi.min.js` | 13 Mo / 10 Mo / 2,8 Mo / 0,4 Mo |
| Sons décodés en mémoire | 208,7 Mo de PCM, pour 81 sons |
| Textures envoyées au GPU au démarrage et au premier écran | 130,5 Mo |
| Textures au total, si toutes envoyées | 242,8 Mo (38 images, dont 8 atlas de 2048 × 2048) |
| Programmes liés pendant le chargement | 6 ou 7 |

### Allocations

Sur 5 s du tutoriel, 52,6 Mo alloués, pour environ 49 images rendues, soit environ 1 Mo par image :

| Fonction | Mo en 5 s |
|---|---|
| `RenderContext.colorMatrixOf` | 16,6 |
| `RenderContext.drawQuad` | 13,3 |
| `SpriteBatch.quadOf` | 9,4 |
| `PixiRenderer.showCommand` | 4,5 |

## Les problèmes

### 1. Un `ColorMatrixFilter` par sprite coloré

**Constat.** Sans les filtres, le jeu passe de 9 à 12 images/s au plafond de 30. Les appels GPU tombent de 585 à 763 par image à 5 à 9. Les changements de cible tombent de 576 à 756 à 0. Le CPU attend, avec les filtres comme sans : le GPU est le goulot.

**Cause.** `RenderContext` produit une commande par tuile, avec la matrice de couleur du drawable (`html5/src/h2d/RenderContext.hx:93`). `PixiRenderer` montre chaque commande par un sprite PixiJS. Si la commande a une matrice, il pose sur ce sprite un `ColorMatrixFilter` (`html5/src/PixiRenderer.hx:47`). Un filtre PixiJS dessine le sprite dans une texture intermédiaire, puis la recopie à l'écran : deux changements de cible de rendu par sprite. Sur un GPU à tuiles, chaque changement de cible écrit puis relit l'image entière. 300 à 380 filtres par image coûtent environ 100 ms par image, même sur un M5.

Nuance de la sonde : le temps GPU mesuré par requête (`EXT_disjoint_timer_query_webgl2`) n'est que de 8 à 11 ms par image. Le reste se passe sans doute dans le processus GPU de Chrome, où ANGLE encode une passe Metal par changement de cible. C'est une hypothèse, pas une mesure. La correction est la même : plus de changement de cible.

**Qui porte ces filtres.** Classement des sprites filtrés, sur une image de chaque écran :

| Écran | Teinte (multiplie seulement) | Mélange des canaux | D'où viennent-ils |
|---|---|---|---|
| Carte | 288 (dont 37 qui ne changent que l'alpha) | 0 | 257 lettres de polices vectorielles, 31 lettres de `benchNineFont.png` |
| Tutoriel | 78 | 300 | 300 particules de `fx.png` ; les lettres |
| Partie | 16 | 300 | 300 particules de `fx.png` ; les lettres |

- Les **textes** n'ont que des teintes : la couleur du texte multiplie le blanc des lettres.
- Les **300 particules** viennent d'un seul lot : `bmPartMagmaFX` (`client/client/src/process/Game.hx:252`), un `SpriteBatch` colorisé en orange magma par `getColorizeMatrixH2d`. Elles sont vivantes : ce n'est pas un réservoir mal libéré.
- Aucun écran mesuré n'a de couleur « multiplier puis ajouter ».

**Correction.**

1. **Teinte native.** Une matrice qui multiplie seulement chaque canal, par un facteur entre 0 et 1, devient `sprite.tint` et `sprite.alpha`. PixiJS l'applique dans son shader de lot. Cela couvre tous les filtres de la carte et des fenêtres, et toutes les lettres. Un essai sur la bulle du tutoriel donnait des pixels identiques à l'œil.
2. **Matrice de couleur dans le shader de lot**, pour les autres matrices. Un greffon de lot PixiJS (`BatchPluginFactory`) reçoit la matrice et le décalage de chaque sprite en attributs de sommet. Son shader applique la matrice à chaque pixel, avant le mélange, comme le `DrawableShader` du fork. Les 300 particules passent de 300 passes de filtre à un seul appel GPU.

   Repli, si le greffon bute sur PixiJS 6.0.2 : un `PIXI.Mesh` par drawable coloré, avec la matrice en paramètre du shader. Il demande de regrouper les commandes par drawable.

   Écartés : un filtre sur un conteneur qui regroupe le lot (faux en mode `Add`) ; [pixi-heaven](https://github.com/pixijs/pixi-heaven) (il ne sait pas mélanger les canaux, comme la colorisation du magma).

**Gain attendu.** Les chiffres de la variante « sans filtres » : 5 à 10 appels GPU par image, et plus aucun changement de cible hors du projecteur.

### 2. Le shader du masque, compilé au premier usage

**Constat.** Au projecteur du tutoriel, deux programmes sont liés, en 339 ms puis 31 ms : le jeu gèle 378 ms. Ensuite, un seul sprite est masqué par image.

**Cause.** `showAlphaMap` (`html5/src/PixiRenderer.hx:65`) rend l'`alphaMap` du fork par un masque de sprite PixiJS, c'est-à-dire un filtre (`SpriteMaskFilter`). Son shader est compilé à la première image qui l'utilise. Kadokadeo a noté le même piège ([pitfalls.md](https://github.com/eternaltwin/kadokadeo/blob/main/.opencode/skills/flash-port/references/pitfalls.md)).

**Correction.** Compiler tous les shaders du jeu pendant la barre de chargement, en dessinant une fois chaque cas dans une petite `RenderTexture`, comme `Game.warmShaders` de Kadokadeo. Le masque reste : un seul sprite masqué coûte une passe par image, ce qui est acceptable. Lire l'`alphaMap` dans le shader de lot, comme le fork, devient utile seulement si le jeu masque beaucoup de sprites.

### 3. Une image dessinée à chaque rafraîchissement de l'écran

**Constat, déduit du code.** `Main.update` fait avancer le jeu par pas entiers de 1/30 s (`client/client/src/Main.hx:254`). Puis il dessine la scène à chaque rappel `requestAnimationFrame`, qu'un pas ait eu lieu ou non (`client/client/src/Main.hx:274`). Les particules, les processus et les tweens avancent par pas, sans facteur de temps : rien ne bouge entre deux pas.

**Effet.** À 60 Hz, une image sur deux est identique à la précédente. À 120 Hz, trois sur quatre. Ce travail est perdu : CPU, GPU et batterie. Flash appelait `ENTER_FRAME` 30 fois par seconde, la cadence de la scène.

**Correction.** `hxd.System.setLoop` appelle la boucle du jeu au plus 30 fois par seconde, comme `ENTER_FRAME`. Le changement reste dans la couche : le code partagé ne bouge pas. Le canvas WebGL garde sa dernière image entre deux appels.

**Hors périmètre.** À 144 Hz, les appels tombent toutes les 4 ou 5 images, donc le mouvement est un peu irrégulier. C'est déjà le cas aujourd'hui. Une interpolation entre les pas changerait le rendu du jeu : la règle de parité de [`html5-migration.md`](html5-migration.md) l'exclut.

### 4. Environ 1 Mo de déchets par image

**Constat.** 52,6 Mo alloués en 5 s de tutoriel. Le ramasse-miettes ne prend que 0,2 à 0,3 % du temps sur le M5. La fréquence de ses pauses suit le débit d'allocation : sur un téléphone, elles se voient comme des saccades.

**Causes.**

- `colorMatrixOf` construit, pour chaque tuile colorée et à chaque image, cinq tableaux et une matrice de 20 nombres. Toutes les tuiles d'un même drawable ont pourtant la même couleur de drawable.
- `drawQuad` et `SpriteBatch.quadOf` créent un objet `DrawCommand` par tuile et par image.
- `showCommand` crée une `Matrix` par sprite et par image (`html5/src/PixiRenderer.hx:126`), et un `Rectangle` à chaque changement de découpe.

**Correction.** Calculer la couleur du drawable une fois par image. Garder un réservoir de commandes dans `RenderContext`. Réutiliser une `Matrix` et des `Rectangle` de travail.

### 5. Sons décodés d'avance

**Constat.** Le chargement décode les 81 sons : 208,7 Mo de PCM en mémoire. Les musiques passent par la banque de sons (`SBANK.Rockfaller_interface()`), donc par ces sons décodés. Elles font les deux tiers des MP3 (7 Mo sur 10), donc sans doute les deux tiers du PCM : cette part est estimée.

**Correction, à choisir.**

- **A. Musiques en flux** : un élément `<audio>` branché dans le contexte Web Audio (`MediaElementAudioSourceNode`), pour garder le volume et la sourdine de `Sfx`. C'est la pratique courante ([W3C](https://lists.w3.org/Archives/Public/public-audio/2012OctDec/0784.html)). Risques : un blanc possible au retour au début de la boucle, et des soucis passés sous Safari ([forum Babylon.js](https://forum.babylonjs.com/t/importing-audioscenecomponent-causes-massive-increase-in-memory-usage/52410)).
- **B. Une seule musique décodée à la fois** : la musique est décodée quand elle commence, et l'autre est libérée. La boucle reste parfaite, mais il reste environ 100 Mo pour la plus longue musique, et un temps de décodage au changement d'écran.

### 6. Textures envoyées au GPU au premier affichage

**Constat.** 130,5 Mo de textures partent au GPU pendant le démarrage et le premier écran. Les autres partent à leur premier affichage. Au défilement de la carte, 5 envois ont coûté 14,7 ms, et la plus longue image 16,2 ms (CPU ×4). Les mipmaps sont déjà coupés.

**Risque, non mesuré.** Le ramasse-miettes de textures de PixiJS est actif par défaut. Il retire du GPU une texture non dessinée depuis 3600 rendus : 2 min à 30 images/s. Revenir sur la carte après une longue partie renverrait les atlas, avec une saccade. Le build Flash définit `NoTextureGC` : le jeu veut garder ses textures.

**Correction.** Ramasse-miettes de textures en manuel. Envoyer les atlas pendant la barre de chargement (greffon `prepare`) tiendrait 243 Mo de textures au GPU dès le départ : à décider après une mesure sur téléphone.

### 7. Réglages du renderer

**Constat.**

- Il y a deux rappels `requestAnimationFrame` par image : la boucle du jeu, et le `Ticker` de PixiJS lancé par son `InteractionManager`. À chaque mouvement du pointeur, ce gestionnaire teste les 800 à 1300 sprites (`recursiveFindHit` dans le profil). Le jeu n'en a pas besoin : `hxd.Stage` et `h2d.Scene` gèrent les clics.
- Le canvas est transparent (`useContextAlpha` à `true` par défaut), alors que le fond du jeu est noir et opaque. Un canvas opaque évite au navigateur de le mélanger avec la page ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Optimizing_canvas)).

**Correction.** Détruire `renderer.plugins.interaction`, et créer le renderer avec `useContextAlpha: false` (`html5/src/h3d/Engine.hx:52`). La variante « sans interaction » le confirme : il ne reste qu'un rappel par image.

## Ce qui n'est pas un problème

- **Le JavaScript du jeu.** Même ralenti 4 fois, une image coûte en moyenne moins de 1,1 ms de JS, avec des pointes de 3 ms. Le budget est de 33 ms à 30 images/s.
- **Le nombre d'appels GPU sans filtres.** PixiJS regroupe les 800 à 1300 sprites en 5 à 9 appels.
- **Les unités de texture des téléphones.** Même limité à 4 unités de texture, le jeu reste à 10 appels GPU par image au plus.
- **Les shaders pendant les coups.** Aucun programme n'est lié pendant les coups ni les combos.
- **Le poids du téléchargement.** 27,4 Mo, contre 39 Mo pour le SWF.
- **`preserveDrawingBuffer` et l'anticrénelage.** Ils sont coupés par défaut dans PixiJS 6, comme le recommandent les guides ([MDN](https://developer.mozilla.org/docs/Web/API/WebGL_API/WebGL_best_practices)).

## État de l'art

Recherche du 28 novembre 2026. Les sources sont surtout des guides de fabricants de GPU, des documentations et des forums : les chiffres des forums restent anecdotiques.

### Les façons de porter du Flash

Il n'existe pas d'outil qui porte le code d'un jeu Flash vers PixiJS.

- **Émuler le SWF** : [Ruffle](https://ruffle.rs), notre référence de parité, et [AwayFL](https://libraries.io/npm/@awayfl%2Fpoki-player), financé par Poki pour les jeux de Nitrome ([entretien](https://www.pocketgamer.biz/interview/73491/interview-poki-preserving-flash-games-nitrome/)). C'est ce que fait déjà la page Flash du site.
- **Réécrire l'API Flash sur WebGL** : [OpenFL](https://community.openfl.org/t/tips-to-increase-performance-html5/11984?page=2) applique `ColorTransform` dans ses shaders de base, pas dans des filtres ([`OpenGLRenderer`](https://cdn.jsdelivr.net/npm/openfl@9.5.2/lib/openfl/display/OpenGLRenderer.d.ts)). Même choix que le fork Heaps.
- **Exporter les animations** d'Adobe Animate : [`@pixi/animate`](https://github.com/pixijs/animate), [pixi-mc](https://github.com/hocti/pixi-mc), [FlashLib](https://www.npmjs.com/package/flashlib). Sans objet : nos images sont déjà des atlas.
- **Réécrire le jeu** dans un autre moteur, comme [Bubble Trouble vers Phaser](https://medium.com/poki/kreso-and-bubble-trouble-a-20-year-tale-6d8932d8de67). Hors sujet : la migration garde le code Haxe.

### Les techniques, par problème

**Passes de rendu (problèmes 1 et 2).**

- Sur un GPU à tuiles (Mali, Adreno, PowerVR, Apple), changer de framebuffer force le GPU à finir et à écrire la cible en cours. Il faut lier chaque framebuffer une seule fois par image ([Arm](https://vulkan.org/user/pages/09.events/vulkanised-2023/vulkanised_2023_getting_started_on_mobile_and_best_practices_for_arm_gpus.pdf), [Samsung](https://developer.samsung.com/galaxy-gamedev/resources/articles/opengl.html), [Mozilla](https://wiki.mozilla.org/Platform/GFX/MobileGPUs), [Android](https://medium.com/androiddevelopers/efficient-render-passes-on-tile-based-rendering-hardware-621070158e40)).
- Les filtres et les masques de sprite coûtent cher ([guide PixiJS](https://pixijs.com/8.x/guides/concepts/performance-tips)) ; un filtre par sprite casse le regroupement ([forum](https://html5gamedevs.com/topic/48173-performance-issues-with-filter-based-dye-system)).
- Heaps donne la même règle : peu d'appels GPU, des tuiles d'un même atlas en lot ([Heaps](https://tobil4sk.github.io/heaps.io/documentation/drawing-tiles.html)).
- Pour colorer sans filtre dans PixiJS 6 : un greffon de lot sur mesure (`BatchPluginFactory`, [forum](https://www.html5gamedevs.com/topic/44978-shader-performances/)), [pixi-batch-renderer](https://www.npmjs.com/package/pixi-batch-renderer), ou [pixi-heaven](https://github.com/pixijs/pixi-heaven) pour la teinte claire et sombre. Aucun exemple officiel d'attribut de couleur par sprite n'a été trouvé.
- PixiJS 8 rend les ruptures de lot moins chères avec WebGPU ([annonce](https://pixijs.com/blog/pixi-v8-launches)). Y passer changerait les externs `pixi-haxe` partagés avec Kadokadeo : pas à court terme.

**Unités de texture.** PixiJS 6 regroupe les sprites tant que leurs textures tiennent dans les unités du GPU, et jusqu'à 4096 sprites par lot ([réglages](https://pixijs.download/release/docs/PIXI.settings.html)). Mesuré ici : sans risque pour nous.

**Boucle (problème 3).** Séparer la logique à pas fixe du rendu est la pratique courante ; sauter les rendus inutiles est discuté au W3C ([WICG](https://discourse.wicg.io/t/proposal-allow-developers-to-indicate-their-ideal-frame-rate/4422)). Tourner en continu à 120 Hz chauffe et vide la batterie ([Android](https://developer.android.com/games/optimize/display-refresh-rate-change)).

**Ramasse-miettes (problème 4).** La fréquence des pauses suit le débit d'allocation ([DEV](https://dev.to/helloashish99/javascript-gc-pauses-allocation-rate-frontend-jank-3jig)). Pas de `new`, `{}` ni `[]` dans la boucle ; des réservoirs pour les objets qui naissent et meurent souvent ([Facebook Instant Games](https://developers.facebook.com/documentation/games/build/game-performance), [web.dev](https://web.dev/articles/speed-static-mem-pools), [Construct](https://www.construct.net/en/blogs/construct-official-blog-1/write-low-garbage-real-time-761)).

**Son (problème 5).** `decodeAudioData` garde toute la piste en PCM ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/BaseAudioContext/decodeAudioData), [WebKit](https://www2.webkit.org/show_bug.cgi?id=189337)) ; la musique se lit plutôt en flux ([W3C](https://lists.w3.org/Archives/Public/public-audio/2012OctDec/0784.html)).

**Textures (problème 6).** Le greffon `prepare` envoie les textures à l'avance ([PixiJS v4 Gotchas](https://github.com/pixijs/pixijs/wiki/v4-Gotchas)). `createImageBitmap` devait éviter les saccades d'envoi, avec des résultats variables selon le navigateur ([Mozilla](https://bugzilla.mozilla.org/show_bug.cgi?id=1486454), [WebKit](https://bugs.webkit.org/show_bug.cgi?id=234920), [WebGL Fundamentals](https://webglfundamentals.org/webgl/lessons/webgl-qna-how-to-load-images-in-the-background-with-no-jank.html)).

**Réglages (problème 7).** Canvas opaque ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Optimizing_canvas)) ; un vieux rapport dit que Safari sur iOS l'ignorait ([liste WebGL](https://groups.google.com/g/webgl-dev-list/c/h7WYgntLnvU)).

**Mesure.** `EXT_disjoint_timer_query_webgl2` mesure le temps GPU ([Khronos](https://registry.khronos.org/webgl/extensions/EXT_disjoint_timer_query_webgl2/), [MDN](https://developer.mozilla.org/en-US/docs/Web/API/EXT_disjoint_timer_query), [webgl-profiler de Figma](https://github.com/figma/webgl-profiler)). Il est disponible dans le Chrome de cette machine.

## Dérive constatée

Les règles `html5.boot::*` et `html5.assets::*` sont citées par les tests (`tools/BootCheck.hx`, `tools/AssetCheck.hx`) et par le code, mais aucun fichier de spec ne les définit. Le lot des textures du plan crée cette spec.

## Suivi

Chiffres de `mise run perf`, sur cette machine, pour garder la trace de chaque lot du plan.

### Point de départ (lot 0)

Commit du lot 0, CPU ×1, temps GPU par requête. Démarrage : 27,4 Mo téléchargés, 208,7 Mo de sons décodés, 7 programmes liés.

| Écran | Images/s | Plus longue (ms) | Appels GPU | Changements de cible | Sprites (filtrés, masqués) | Rappels/image | GPU moyen (ms) | Programmes | Envois | Ko alloués/image |
|---|---|---|---|---|---|---|---|---|---|---|
| Tutoriel | 9,2 | 119 | 803 | 796 | 862 (398, 0) | 2 | 11,3 | 0 | 0 | 1090 |
| Projecteur | 10,0 | 381 | 803 | 796 | 862 (398, 1) | 2 | 10,5 | 2 | 3 | 1145 |
| Carte | 12,4 | 94 | 583 | 574 | 1227 (287, 0) | 2 | 8,4 | 0 | 0 | 1027 |
| Défilement de la carte | 12,3 | 106 | 585 | 574 | 1227 (287, 0) | 2 | 8,6 | 0 | 8 | 1049 |
| Fenêtre du niveau 5 | 12,2 | 93 | 583 | 574 | 1227 (287, 0) | 2 | 8,5 | 0 | 0 | 1018 |
| Partie | 11,3 | 101 | 648 | 640 | 790 (320, 0) | 2 | 9,0 | 0 | 0 | 968 |
| Coups | 11,3 | 107 | 664 | 646 | 809 (323, 0) | 2 | 9,1 | 0 | 0 | 1001 |

### Lot 1 : teinte native

CPU ×1, sans temps GPU. Ce jour-là, une page vide recevait 60 rappels `requestAnimationFrame` par seconde : le plafond de la mesure est 60, et non plus 30.

| Écran | Images/s | Plus longue (ms) | Appels GPU | Changements de cible | Sprites (filtrés, masqués) | Ko alloués/image |
|---|---|---|---|---|---|---|
| Tutoriel | 12,3 | 96 | 605 | 600 | 862 (300, 0) | 1035 |
| Projecteur | 12,0 | 328 | 611 | 602 | 862 (300, 1) | 1096 |
| Carte | **61,0** | 38 | **5** | **0** | 1227 (0, 0) | 965 |
| Défilement de la carte | **60,9** | 47 | 7 | 0 | 1227 (0, 0) | 993 |
| Fenêtre du niveau 5 | **61,2** | 24 | 6 | 0 | 1330 (0, 0) | 1076 |
| Partie | 12,3 | 99 | 606 | 600 | 790 (300, 0) | 957 |
| Coups | 12,5 | 97 | 617 | 600 | 804 (300, 0) | 985 |

Les menus sont au plafond. Le tutoriel et la partie attendent le lot 2 : les 300 particules de magma gardent leur filtre.

### Lot 2 : la matrice de couleur dans le lot

CPU ×1, plafond de 60.

| Écran | Images/s | Plus longue (ms) | Appels GPU | Changements de cible | Sprites (filtrés, masqués) | Ko alloués/image |
|---|---|---|---|---|---|---|
| Tutoriel | **61,0** | 44 | 6 | **0** | 862 (0, 0) | 921 |
| Projecteur | **61,2** | 43 | 12 | 2 (le masque) | 862 (0, 1) | 939 |
| Carte | 61,2 | 42 | 5 | 0 | 1227 (0, 0) | 968 |
| Fenêtre du niveau 5 | 61,2 | 31 | 6 | 0 | 1330 (0, 0) | 1070 |
| Partie | **60,8** | 43 | 7 | **0** | 790 (0, 0) | 845 |
| Coups | **60,6** | 49 | 18 | **0** | 814 (0, 0) | 867 |
| Défilement de la carte | 60,8 | 52 | 7 | 0 | 1227 (0, 0) | 992 |

Tous les écrans sont au plafond. Le greffon de lot a suffi : le repli par `Mesh` n'a pas servi. Bug corrigé en passant : un drawable coloré en `Add` était mélangé en `Normal` par le filtre.

## Questions ouvertes

- **Quels téléphones ?** Il faut au moins un téléphone Android modeste, et si possible un iPhone. Le compteur `?perf` du plan permet de mesurer sur l'appareil.
- **Mémoire des textures sur téléphone.** 243 Mo de textures si tout est envoyé. Si c'est trop, il faudra des atlas à demi-résolution ou des textures compressées. Les textures compressées demandent PixiJS 6.1 ou plus.
- **Musiques** : flux (A) ou une seule décodée (B) ? Le choix se fait à l'écoute de la boucle.
- **Netteté sur écran Retina.** Le canvas fait 640 × 768 pixels, puis le navigateur l'agrandit. Le passer à la résolution de l'écran rendrait l'image nette, mais multiplierait par 4 les pixels à remplir. C'est un choix de rendu, à trancher à part.
