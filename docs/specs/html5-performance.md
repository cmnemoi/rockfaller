# Performances de la version PixiJS

Analyse du 28 novembre 2026, sur le commit `ff186cd`. Partie de l'étape 4 de [`html5-migration.md`](html5-migration.md).

## En bref

Dans Chrome, la version PixiJS dessine **9 à 12 images par seconde** sur un Apple M5. Sans ses filtres de couleur, elle en dessine 30, le plafond de la mesure. Firefox n'est pas mesuré de façon fiable (voir « Questions ouvertes »). Les téléphones modestes sont une cible, et Chrome est leur navigateur le plus courant : ce coût reste donc le premier problème. Le CPU n'y est pour rien : il attend 90 à 97 % du temps. Le GPU est saturé par environ **600 à 760 changements de cible de rendu par image**. Chaque sprite coloré passe par son propre `ColorMatrixFilter`, c'est-à-dire un rendu dans une texture intermédiaire.

Le fork Heaps n'a pas ce coût : sa matrice de couleur est un paramètre du shader, appliqué pendant le dessin. C'est ce qu'il faut refaire.

Classement des problèmes, du plus grave au moins grave :

| # | Problème | Effet mesuré | Correction | Coût |
|---|---|---|---|---|
| 1 | Un `ColorMatrixFilter` par sprite coloré | 9 à 12 images/s au lieu de 30 ; 585 à 763 appels GPU par image au lieu de 5 à 9 | Teinte native pour les couleurs qui multiplient ; shader de couleur par drawable pour les autres | Moyen |
| 2 | `alphaMap` en masque PixiJS, shader compilé au premier usage | Le jeu gèle **378 ms** au projecteur du tutoriel | Masque dans le même shader ; shaders compilés pendant le chargement | Moyen |
| 3 | Rendu à chaque image de l'écran, alors que le jeu avance 30 fois par seconde | 1 image sur 2 identique à 60 Hz, 3 sur 4 à 120 Hz (déduit du code) | Ne dessiner qu'après un pas du jeu | Faible |
| 4 | Environ 1 Mo d'objets jetés par image | 52,6 Mo alloués en 5 s ; ramasse-miettes sur mobile | Réutiliser les commandes, les matrices et les couleurs | Moyen |
| 5 | Sons décodés d'avance, dont les deux musiques | 209 Mo de PCM en mémoire | Lire les musiques en flux (`<audio>`) | Faible |
| 6 | Textures envoyées au GPU au premier affichage ; ramasse-miettes de textures de PixiJS actif | Saccade au défilement de la carte (14,7 ms d'envoi, CPU ×4) | Envoi pendant le chargement ; ramasse-miettes en manuel, comme `NoTextureGC` | Faible |
| 7 | Gestionnaire d'interaction de PixiJS inutile | Une 2e boucle `requestAnimationFrame` ; test de 800 à 1300 sprites à chaque mouvement du pointeur | Retirer le module | Très faible |

## Méthode

### Machine et navigateur

- MacBook Pro, Apple M5, écran Retina 3024 × 1964.
- Chrome 158 piloté par Playwright, en headless. Le WebGL passe par ANGLE sur Metal, donc par le vrai GPU, pas par SwiftShader. La [leçon de Kadokadeo](https://github.com/eternaltwin/kadokadeo/blob/main/.opencode/skills/flash-port/references/testing.md) est respectée : SwiftShader fausse les mesures de performance.
- Version mesurée : le build release, `dist/web/pixi/game.js`, servi en local.
- Mesures refaites avec le CPU ralenti 4 fois (`Emulation.setCPUThrottlingRate`), pour approcher une machine modeste.

**Limite de la mesure :** dans cet environnement, une page vide reçoit 30 rappels `requestAnimationFrame` par seconde, en headless comme dans une fenêtre ouverte par Playwright. « 30 images par seconde » veut donc dire « au plafond », pas « au maximum de la machine ». Le cas 60 Hz ou 120 Hz n'a pas pu être mesuré : le point 3 vient du code.

### Ce que la sonde mesure

Un script injecté avant le chargement de la page compte, pour chaque image :

- le temps JavaScript de chaque rappel `requestAnimationFrame` ;
- le temps CPU de `PIXI.Renderer.render` ;
- les sprites PixiJS visibles, ceux qui ont un filtre et ceux qui ont un masque ;
- les appels WebGL `drawElements` et `drawArrays`, et les `bindFramebuffer` (changements de cible de rendu) ;
- les envois de textures (`texImage2D`, `texSubImage2D`), avec leur durée ;
- les programmes liés (`linkProgram`), avec leur durée.

Elle relève aussi un profil CPU (Profiler du protocole DevTools), les allocations (HeapProfiler, objets ramassés compris), la taille des sons décodés et les octets téléchargés.

### Écrans mesurés

1. **Tutoriel** : nouvelle partie, première bulle du niveau 1, 6 s.
2. **Carte** : niveau 5 débloqué par une sauvegarde injectée dans `localStorage`, fenêtre LOGIN fermée, 5 s.
3. **Défilement de la carte** : 8 glissés de 400 px.
4. **Fenêtre du niveau 5** : 4 s.
5. **Partie** : niveau 5 lancé, 6 s sans rien faire.
6. **Coups** : 12 clics sur les coins des groupes de la grille. Un combo ×2 et un score de 2275 confirment que les coups ont été joués.

Variantes de diagnostic, chacune sur le même parcours :

- **sans filtres** : la sonde retire les filtres juste avant chaque rendu. Les couleurs sont fausses, mais le coût sans filtres est mesuré ;
- **sans interaction** : la sonde détruit le gestionnaire d'interaction de PixiJS.

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

Sur 5 s du tutoriel, 52,6 Mo alloués, pour environ 49 images, soit environ 1 Mo par image :

| Fonction | Mo en 5 s |
|---|---|
| `RenderContext.colorMatrixOf` | 16,6 |
| `RenderContext.drawQuad` | 13,3 |
| `SpriteBatch.quadOf` | 9,4 |
| `PixiRenderer.showCommand` | 4,5 |

## Les problèmes

### 1. Un `ColorMatrixFilter` par sprite coloré

**Constat.** Sans les filtres, le jeu passe de 9 à 12 images/s au plafond de 30. Les appels GPU tombent de 585 à 763 par image à 5 à 9. Les changements de cible tombent de 576 à 756 à 0. Pendant ce temps, le CPU attend : 97 % d'inactivité dans le profil, avec les filtres comme sans. Le GPU est donc le goulot.

**Cause.** `RenderContext` produit une commande par tuile, avec la matrice de couleur du drawable (`html5/src/h2d/RenderContext.hx:93`). `PixiRenderer` montre chaque commande par un sprite PixiJS. Si la commande a une matrice, il pose sur ce sprite un `ColorMatrixFilter` (`html5/src/PixiRenderer.hx:47`). Un filtre PixiJS dessine le sprite dans une texture intermédiaire, puis la recopie à l'écran : deux changements de cible de rendu par sprite. Sur un GPU à tuiles comme ceux d'Apple et des mobiles, chaque changement de cible relit et réécrit l'image entière. 300 à 380 filtres par image coûtent environ 100 ms de GPU, même sur un M5.

Le fork Heaps n'a pas ce problème. Son `DrawableShader` reçoit la matrice en paramètre, et un `SpriteBatch` dessine toutes ses tuiles en un seul appel.

**Qui porte ces filtres.** Classement des sprites filtrés, sur une image de chaque écran :

| Écran | Teinte (multiplie seulement) | Mélange des canaux | D'où viennent-ils |
|---|---|---|---|
| Carte | 288 (dont 37 qui ne changent que l'alpha) | 0 | 257 lettres de polices vectorielles (canvas), 31 lettres de `benchNineFont.png` |
| Tutoriel | 78 | 300 | 300 particules de `fx.png` ; les lettres |
| Partie | 16 | 300 | 300 particules de `fx.png` ; les lettres |

- Les **textes** n'ont que des teintes : la couleur du texte multiplie le blanc des lettres.
- Les **300 particules** viennent d'un seul lot : `bmPartMagmaFX` (`client/client/src/process/Game.hx:252`), un `SpriteBatch` colorisé en orange magma par `getColorizeMatrixH2d`. Les 300 particules sont vivantes : ce n'est pas un réservoir mal libéré.

**Correction proposée, en deux temps.**

1. **Teinte native.** Une matrice qui multiplie seulement chaque canal, par un facteur entre 0 et 1, devient `sprite.tint` et `sprite.alpha`. PixiJS l'applique dans son shader de lot, sans texture intermédiaire. Cela couvre tous les filtres de la carte et des fenêtres, et toutes les lettres. Un essai sur la bulle du tutoriel donnait des pixels identiques à l'œil.
2. **Shader de couleur par drawable**, pour les matrices qui mélangent les canaux ou ajoutent une couleur. Un drawable coloré devient un seul `PIXI.Mesh` : toutes ses tuiles dans une géométrie, la matrice et le décalage en paramètres du shader. C'est le `DrawableShader` du fork. Les 300 particules de magma passent de 300 passes de filtre à un seul appel GPU. La matrice s'applique toujours à chaque pixel avant le mélange, comme dans le fork.

Une solution intermédiaire, un seul filtre posé sur un conteneur qui regroupe le lot, n'est pas retenue. Elle n'est juste qu'en mode de mélange `Normal` : avec `Add`, le résultat change.

**Gain attendu.** Les chiffres de la variante « sans filtres » : 5 à 9 appels GPU par image, plus un par drawable à mélange de canaux, et plus aucun changement de cible. Le jeu ne serait plus limité par le GPU.

### 2. Le masque `alphaMap` et le shader compilé au premier usage

**Constat.** À l'étape du projecteur du tutoriel, deux programmes sont liés, en 339 ms puis 31 ms. Le jeu gèle 378 ms.

**Cause.** `showAlphaMap` (`html5/src/PixiRenderer.hx:65`) rend l'`alphaMap` du fork par un masque de sprite PixiJS. Un masque de sprite est un filtre (`SpriteMaskFilter`). Son shader est compilé à la première image qui l'utilise, ici au milieu du tutoriel. Kadokadeo a noté le même piège, avec des gels de 10 à 80 ms ou plus ([pitfalls.md](https://github.com/eternaltwin/kadokadeo/blob/main/.opencode/skills/flash-port/references/pitfalls.md)). Ensuite, chaque image avec un masque paie aussi une passe de filtre, comme au point 1.

**Correction proposée.**

- Lire l'`alphaMap` dans le shader de couleur du point 1, comme un 2e échantillon de texture, comme le fait le fork. Le masque PixiJS disparaît.
- Compiler tous les shaders du jeu pendant la barre de chargement, en dessinant une fois chaque variante dans une petite `RenderTexture`. Kadokadeo le fait avec `Game.warmShaders`.
- Vérification : la sonde ne doit compter aucun programme lié pendant le jeu.

### 3. Une image dessinée à chaque rafraîchissement de l'écran

**Constat, déduit du code.** `Main.update` fait avancer le jeu par pas entiers de 1/30 s (`client/client/src/Main.hx:254`). Puis il dessine la scène à chaque rappel `requestAnimationFrame`, qu'un pas ait eu lieu ou non (`client/client/src/Main.hx:274`). Les particules, les processus et les tweens avancent par pas, sans facteur de temps : rien ne bouge entre deux pas.

**Effet.** À 60 Hz, une image sur deux est identique à la précédente. À 120 Hz, comme sur l'écran de ce MacBook, trois sur quatre. Ce travail est perdu : CPU, GPU et batterie. Flash dessinait à 30 images par seconde.

**Correction proposée.** Dans `Main.update`, dessiner seulement si au moins un pas a eu lieu. C'est un Parallel Change dans le code partagé : le build Flash ne change pas. Le canvas WebGL garde sa dernière image tant qu'on ne redessine pas.

**Hors périmètre.** À 144 Hz, les pas tombent toutes les 4 ou 5 images, donc le mouvement est un peu irrégulier. C'est déjà le cas aujourd'hui. Une interpolation entre les pas, comme dans Kadokadeo, changerait le rendu du jeu : la règle de parité de [`html5-migration.md`](html5-migration.md) l'exclut pour l'instant.

### 4. Environ 1 Mo de déchets par image

**Constat.** 52,6 Mo alloués en 5 s de tutoriel. Le ramasse-miettes ne prend que 0,2 à 0,3 % du temps sur le M5. Sur un téléphone, ses pauses se voient comme des saccades.

**Causes.**

- `colorMatrixOf` construit, pour chaque tuile colorée et à chaque image, cinq tableaux et une matrice de 20 nombres. Toutes les tuiles d'un même drawable ont pourtant la même couleur.
- `drawQuad` et `SpriteBatch.quadOf` créent un objet `DrawCommand` par tuile et par image.
- `showCommand` crée une `Matrix` par sprite et par image (`html5/src/PixiRenderer.hx:126`). PixiJS la décompose ensuite en position, échelle, inclinaison et rotation (`decompose`), puis la recompose : c'est le premier coût de PixiJS dans le profil.

**Correction proposée.** Calculer la couleur une fois par drawable et par image. Garder un réservoir de commandes dans `RenderContext`, réutilisé d'une image à l'autre. Réutiliser une seule `Matrix` de travail. Le maillage du point 1 supprime aussi une partie de ces objets, pour les lots.

### 5. Sons décodés d'avance

**Constat.** Le chargement décode les 81 sons : 208,7 Mo de PCM en mémoire. Les deux musiques, `Rockfaller_ingame.mp3` (4,2 Mo) et `Rockfaller_interface.mp3` (2,8 Mo), font les deux tiers des MP3. Elles pèsent donc sans doute les deux tiers de ce PCM : cette part est estimée, pas mesurée.

**Correction proposée.** Lire les deux musiques en flux par un élément `<audio>`, branché dans le contexte Web Audio (`MediaElementAudioSourceNode`) pour garder le volume et la sourdine de `Sfx`. Les bruitages, courts, restent décodés d'avance. C'est aussi ce que fait Flash : `SoundManager` télécharge les musiques à part, avec `Sfx.download`.

### 6. Textures envoyées au GPU au premier affichage

**Constat.** 130,5 Mo de textures partent au GPU pendant le démarrage et le premier écran. Les autres partent à leur premier affichage. Au défilement de la carte, 5 envois ont coûté 14,7 ms, et la plus longue image 16,2 ms (CPU ×4). Les mipmaps sont déjà coupés : le piège des atlas de 2048 px de Kadokadeo ne s'applique pas.

**Risque, non mesuré.** Le ramasse-miettes de textures de PixiJS est actif par défaut. Il retire du GPU une texture non dessinée depuis 3600 rendus, soit 2 min à 30 images/s, ou 30 s à 120 Hz. Revenir sur la carte après une longue partie renverrait alors les atlas, avec une saccade. Le build Flash définit `NoTextureGC` : le jeu veut garder ses textures.

**Correction proposée.** Passer `renderer.textureGC.mode` en manuel. Envoyer les atlas pendant la barre de chargement (`renderer.plugins.prepare`). Ce choix tient 243 Mo de textures au GPU dès le départ : à vérifier sur mobile.

### 7. Le gestionnaire d'interaction de PixiJS

**Constat.** Il y a deux rappels `requestAnimationFrame` par image : la boucle du jeu et le `Ticker` de PixiJS, lancé par son `InteractionManager`. À chaque mouvement du pointeur, ce gestionnaire teste les 800 à 1300 sprites (`recursiveFindHit` dans le profil du défilement). Le jeu n'en a pas besoin : `hxd.Stage` et `h2d.Scene` gèrent déjà les clics.

**Correction proposée.** Détruire `renderer.plugins.interaction` à la création du renderer (`html5/src/h3d/Engine.hx:52`). La variante « sans interaction » le fait : il ne reste qu'un rappel par image.

## Ce qui n'est pas un problème

- **Le JavaScript du jeu.** Même ralenti 4 fois, une image coûte en moyenne moins de 1,1 ms de JS, avec des pointes de 3 ms. Le budget est de 33 ms à 30 images/s.
- **Le nombre d'appels GPU sans filtres.** PixiJS regroupe les 800 à 1300 sprites en 5 à 9 appels.
- **Les shaders pendant les coups.** Aucun programme n'est lié pendant les coups ni les combos. Seul le projecteur du tutoriel en compile.
- **Le poids du téléchargement.** 27,4 Mo, contre 39 Mo pour le SWF.

## Ce que font les autres

Recherche du 28 novembre 2026. Il n'existe pas d'outil qui porte le code d'un jeu Flash vers PixiJS. Les approches se rangent en quatre familles.

- **Émuler le SWF.** [Ruffle](https://ruffle.rs) (notre référence de parité) et [AwayFL](https://libraries.io/npm/@awayfl%2Fpoki-player), financé par Poki, font tourner le SWF d'origine. Nitrome publie ainsi ses jeux sur Poki ([entretien](https://www.pocketgamer.biz/interview/73491/interview-poki-preserving-flash-games-nitrome/)). Ce n'est pas un portage : c'est ce que fait déjà la page Flash du site.
- **Réécrire l'API Flash sur WebGL.** [OpenFL](https://community.openfl.org/t/tips-to-increase-performance-html5/11984?page=2) garde `ColorTransform` dans ses shaders de base, pas dans des filtres, et regroupe les dessins automatiquement ([`OpenGLRenderer`](https://cdn.jsdelivr.net/npm/openfl@9.5.2/lib/openfl/display/OpenGLRenderer.d.ts)). C'est le même choix que le fork Heaps : **la couleur est un paramètre du shader**.
- **Exporter les animations.** [`@pixi/animate`](https://github.com/pixijs/animate) (v2 pour PixiJS 5 et 6), [pixi-mc](https://github.com/hocti/pixi-mc) et [FlashLib](https://www.npmjs.com/package/flashlib) exportent les clips d'Adobe Animate vers PixiJS. Sans objet ici : les images du jeu sont déjà des atlas.
- **Réécrire le jeu** dans un autre moteur, comme [Bubble Trouble vers Phaser](https://medium.com/poki/kreso-and-bubble-trouble-a-20-year-tale-6d8932d8de67). Hors sujet : le choix de la migration est de garder le code Haxe.

Côté PixiJS, le constat est le même partout :

- Le [guide de performance de PixiJS](https://pixijs.com/8.x/guides/concepts/performance-tips) dit que les filtres et les masques de sprite coûtent cher, et qu'il faut en limiter le nombre. Des forums constatent qu'un filtre par sprite casse le regroupement des dessins ([un exemple](https://html5gamedevs.com/topic/48173-performance-issues-with-filter-based-dye-system)).
- Pour colorer sans filtre, PixiJS 6 a des greffons : [pixi-heaven](https://github.com/pixijs/pixi-heaven) (branche v6, teinte claire et sombre dans le shader de lot, donc un `ColorTransform` Flash) et [pixi-batch-renderer](https://www.npmjs.com/package/pixi-batch-renderer) (attributs de lot sur mesure). [pixi-picture](https://github.com/pixijs/pixi-picture) couvre les modes de mélange de Flash.
- PixiJS 8 hérite la teinte d'un conteneur à ses enfants, et WebGPU y rend les ruptures de lot moins chères ([annonce de la v8](https://pixijs.com/blog/pixi-v8-launches)). Passer de PixiJS 6.0.2 à 8 changerait les externs `pixi-haxe` partagés avec Kadokadeo : ce n'est pas un levier à court terme.

**Ce que cela change au plan.** Le lot 1, la teinte native, est la pratique courante. Pour le lot 2, pixi-heaven ne suffit pas : il couvre « multiplier puis ajouter » par canal, mais pas le mélange des canaux de la colorisation du magma. Les écrans mesurés n'ont d'ailleurs aucune couleur de type « multiplier puis ajouter ». Le lot 2 reste donc un shader de couleur sur mesure, sur le modèle du `DrawableShader` du fork et des shaders de base d'OpenFL.

## Techniques connues, pour notre méthode

Notre méthode : un graphe de scène h2d qui produit des commandes de dessin, montrées par PixiJS 6 en WebGL, avec des téléphones modestes comme cible. Voici les techniques publiées qui s'y appliquent, rangées par problème. Les sources sont surtout des guides de fabricants de GPU, des documentations et des forums : les chiffres des forums restent anecdotiques.

### GPU : éviter les passes de rendu

- Sur un GPU à tuiles (Mali, Adreno, PowerVR, Apple), changer de framebuffer force le GPU à finir et à écrire la cible en cours, puis à recharger la suivante. Les guides d'Arm, de Samsung et de Mozilla disent de lier chaque framebuffer **une seule fois par image**, et de faire tous ses dessins avant d'en changer ([Arm, Vulkanised 2023](https://vulkan.org/user/pages/09.events/vulkanised-2023/vulkanised_2023_getting_started_on_mobile_and_best_practices_for_arm_gpus.pdf), [Samsung](https://developer.samsung.com/galaxy-gamedev/resources/articles/opengl.html), [Mozilla](https://wiki.mozilla.org/Platform/GFX/MobileGPUs), [Android](https://medium.com/androiddevelopers/efficient-render-passes-on-tile-based-rendering-hardware-621070158e40)). Nos 576 à 756 changements par image vont à l'opposé : cela confirme les problèmes 1 et 2.
- PixiJS le dit aussi : les filtres et les masques de sprite coûtent cher ([guide de performance](https://pixijs.com/8.x/guides/concepts/performance-tips)). Sur les forums, un filtre par sprite casse le regroupement ([exemple](https://html5gamedevs.com/topic/48173-performance-issues-with-filter-based-dye-system)).
- Heaps, l'origine de notre couche, donne la même règle : peu d'appels GPU, des tuiles d'un même atlas dans un `SpriteBatch` ou un `TileGroup`, et `engine.drawCalls` pour compter ([documentation Heaps](https://tobil4sk.github.io/heaps.io/documentation/drawing-tiles.html)).
- **Couleur sans filtre.** OpenFL garde `ColorTransform` dans ses shaders ([`OpenGLRenderer`](https://cdn.jsdelivr.net/npm/openfl@9.5.2/lib/openfl/display/OpenGLRenderer.d.ts)). Pour PixiJS 6 : [pixi-heaven](https://github.com/pixijs/pixi-heaven) (teinte claire et sombre dans le lot) et [pixi-batch-renderer](https://www.npmjs.com/package/pixi-batch-renderer) (attributs de lot sur mesure). `BatchPluginFactory` de PixiJS 6 permet aussi un shader de lot sur mesure ([forum](https://www.html5gamedevs.com/topic/44978-shader-performances/)), mais sans exemple officiel pour un attribut de couleur par sprite.

### GPU : le nombre de textures par lot

- PixiJS 6 regroupe les sprites tant que leurs textures tiennent dans les unités de texture du GPU (`SPRITE_MAX_TEXTURES`, au plus 32), et jusqu'à 4096 sprites par lot (`SPRITE_BATCH_SIZE`) ([réglages PixiJS](https://pixijs.download/release/docs/PIXI.settings.html)).
- **Nouveau point à mesurer.** Un téléphone modeste offre souvent 8 ou 16 unités de texture, contre 16 ou plus sur le M5. Nos écrans mélangent jusqu'à 8 atlas de 2048 px et les textures des polices : sur téléphone, les 5 à 9 appels mesurés ici pourraient se multiplier. La sonde peut le simuler en fixant `PIXI.settings.SPRITE_MAX_TEXTURES` à 8.

### Canvas et remplissage

- Un canvas opaque (`alpha: false`) évite au navigateur de le mélanger avec la page ([MDN, optimiser le canvas](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API/Tutorial/Optimizing_canvas)). Notre fond est noir et opaque : PixiJS 6 le permet avec `useContextAlpha: false`. Un vieux rapport dit que Safari sur iOS l'ignorait ([liste WebGL](https://groups.google.com/g/webgl-dev-list/c/h7WYgntLnvU)) : à vérifier.
- `preserveDrawingBuffer` doit rester à `false`, et l'anticrénelage coupé ([MDN, bonnes pratiques WebGL](https://developer.mozilla.org/docs/Web/API/WebGL_API/WebGL_best_practices), [Mozilla](https://bugzilla.mozilla.org/show_bug.cgi?id=912551)). Ce sont les valeurs par défaut de PixiJS 6 : rien à faire.
- Sur mobile, le remplissage des pixels est souvent la limite. Garder la résolution du canvas à 640 × 768, sans la multiplier par la densité de l'écran, protège les téléphones (voir « Netteté sur écran Retina »).

### Mesurer le GPU, pas seulement le CPU

- `EXT_disjoint_timer_query_webgl2` mesure le temps GPU d'un groupe de dessins ([Khronos](https://registry.khronos.org/webgl/extensions/EXT_disjoint_timer_query_webgl2/)). Son support varie selon le navigateur ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/EXT_disjoint_timer_query)) ; [webgl-profiler](https://github.com/figma/webgl-profiler) de Figma s'en sert. La sonde du lot 0 peut l'utiliser quand il est là : elle mesurerait le temps GPU au lieu de le déduire.

### Boucle de jeu

- Séparer la logique, à pas fixe, du rendu est la pratique courante. Sauter le rendu quand rien n'a changé figure parmi les options discutées au W3C ([WICG](https://discourse.wicg.io/t/proposal-allow-developers-to-indicate-their-ideal-frame-rate/4422)). Android rappelle que tourner en continu à 120 Hz chauffe et vide la batterie ([Android](https://developer.android.com/games/optimize/display-refresh-rate-change)). Cela confirme le problème 3.

### Ramasse-miettes JavaScript

- Le ramasse-miettes met le jeu en pause, et ses pauses se voient. La fréquence des pauses dépend du **débit d'allocation**, pas de la mémoire totale ([Facebook Instant Games](https://developers.facebook.com/documentation/games/build/game-performance), [DEV](https://dev.to/helloashish99/javascript-gc-pauses-allocation-rate-frontend-jank-3jig)). Conseils : pas de `new`, `{}` ni `[]` dans la boucle, des réservoirs pour les objets qui naissent et meurent souvent ([web.dev](https://web.dev/articles/speed-static-mem-pools), [Construct](https://www.construct.net/en/blogs/construct-official-blog-1/write-low-garbage-real-time-761)). Nos commandes de dessin et nos matrices sont exactement ce cas : cela confirme le problème 4.

### Textures

- Le greffon `prepare` de PixiJS envoie les textures au GPU à l'avance ([PixiJS v4 Gotchas](https://github.com/pixijs/pixijs/wiki/v4-Gotchas)). Décoder les images avec `createImageBitmap` devait éviter les saccades d'envoi, mais les résultats varient selon le navigateur ([Mozilla](https://bugzilla.mozilla.org/show_bug.cgi?id=1486454), [WebKit](https://bugs.webkit.org/show_bug.cgi?id=234920), [WebGL Fundamentals](https://webglfundamentals.org/webgl/lessons/webgl-qna-how-to-load-images-in-the-background-with-no-jank.html)). Pour nous : envoyer les atlas pendant la barre de chargement, et mesurer sur téléphone.

### Son

- `decodeAudioData` garde toute la piste en PCM ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/BaseAudioContext/decodeAudioData), [WebKit](https://www2.webkit.org/show_bug.cgi?id=189337)). Pour la musique, la pratique est de la lire en flux par `<audio>` et `MediaElementAudioSourceNode` ([W3C](https://lists.w3.org/Archives/Public/public-audio/2012OctDec/0784.html)).
- **Risque pour nous :** nos musiques bouclent. Une boucle en flux peut laisser un blanc au retour au début, et le flux a eu des soucis sous Safari ([forum Babylon.js](https://forum.babylonjs.com/t/importing-audioscenecomponent-causes-massive-increase-in-memory-usage/52410)). Il faut l'écouter avant de le retenir. Autre piste : ne décoder que la musique en cours, en libérant l'autre.

## Plan proposé

Un lot par problème, chacun avec ses tests d'abord. Chaque lot se mesure avec la sonde, avant et après.

0. **La sonde dans le dépôt.** `tools/perf.mjs` et une tâche `mise run perf`, hors CI. Le résultat se compare d'un commit à l'autre. Elle mesure aussi le temps GPU (`EXT_disjoint_timer_query_webgl2`, quand il est là) et simule un téléphone à 8 unités de texture.
1. **Teinte native** (problème 1, première moitié). Cela retire tous les filtres de la carte et des fenêtres.
2. **Shader de couleur et `alphaMap` par drawable** (problèmes 1 et 2). Cela retire les filtres restants et le masque.
3. **Shaders compilés au chargement** (problème 2).
4. **Réglages du renderer** (problèmes 7 et 6) : retirer le gestionnaire d'interaction, ramasse-miettes de textures en manuel, canvas opaque (`useContextAlpha: false`).
5. **Dessiner seulement après un pas du jeu** (problème 3).
6. **Moins d'allocations par image** (problème 4).
7. **Musiques en flux, après écoute des boucles ; textures envoyées au chargement** (problèmes 5 et 6).

Les lots 1 à 3 rendent le jeu fluide. Les lots 4 à 7 réduisent la charge, la mémoire et les saccades : les téléphones modestes étant visés, ils sont nécessaires aussi.

## Questions ouvertes

- **Firefox n'est pas mesuré de façon fiable.** Le Firefox de Playwright installé ici est trop vieux pour la sonde. Un comptage à la main dans la console a donné environ 93, puis 537 images par seconde : ce chiffre n'est pas retenu. Il faudra mesurer Firefox avec la sonde du lot 0. Les GPU de téléphone sont à tuiles, comme celui du M5 : le coût mesuré dans Chrome est le cas à viser.

- **Appareils visés : les téléphones modestes aussi.** Les lots 4 à 7 sont donc nécessaires, pas secondaires.
- **Netteté sur écran Retina.** Le canvas fait 640 × 768 pixels, puis le navigateur l'agrandit. Le passer à la résolution de l'écran rendrait l'image nette, mais multiplierait par 4 les pixels à remplir. C'est un choix de rendu, à trancher à part.
