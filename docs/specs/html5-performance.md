# Performances de la version PixiJS

Analyse du 28 novembre 2026, sur le commit `ff186cd`. Partie de l'étape 4 de [`html5-migration.md`](html5-migration.md).

## En bref

Dans Chrome, la version PixiJS dessine **9 à 12 images par seconde** sur un Apple M5. Sans ses filtres de couleur, elle en dessine 30, le plafond de la mesure. Dans Firefox, sur la même machine, elle dessine environ 93 images par seconde en partie, sur un écran à 120 Hz : le coût des filtres dépend beaucoup du navigateur. Les téléphones modestes sont une cible, et Chrome est leur navigateur le plus courant : ce coût reste donc le premier problème. Le CPU n'y est pour rien : il attend 90 à 97 % du temps. Le GPU est saturé par environ **600 à 760 changements de cible de rendu par image**. Chaque sprite coloré passe par son propre `ColorMatrixFilter`, c'est-à-dire un rendu dans une texture intermédiaire.

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

## Plan proposé

Un lot par problème, chacun avec ses tests d'abord. Chaque lot se mesure avec la sonde, avant et après.

0. **La sonde dans le dépôt.** `tools/perf.mjs` et une tâche `mise run perf`, hors CI. Le résultat se compare d'un commit à l'autre.
1. **Teinte native** (problème 1, première moitié). Cela retire tous les filtres de la carte et des fenêtres.
2. **Shader de couleur et `alphaMap` par drawable** (problèmes 1 et 2). Cela retire les filtres restants et le masque.
3. **Shaders compilés au chargement** (problème 2).
4. **Retirer le gestionnaire d'interaction ; ramasse-miettes de textures en manuel** (problèmes 7 et 6).
5. **Dessiner seulement après un pas du jeu** (problème 3).
6. **Moins d'allocations par image** (problème 4).
7. **Musiques en flux ; textures envoyées au chargement** (problèmes 5 et 6).

Les lots 1 à 3 rendent le jeu fluide. Les lots 4 à 7 réduisent la charge, la mémoire et les saccades : les téléphones modestes étant visés, ils sont nécessaires aussi.

## Questions ouvertes

- **Pourquoi Firefox est-il 8 fois plus rapide ?** Mesure à la main, dans la console : environ 93 images rendues par seconde en partie, sur l'écran à 120 Hz du MacBook. Le Firefox de Playwright installé ici est trop vieux pour la sonde. Cause probable, non vérifiée : Chrome passe par ANGLE sur Metal, où chaque changement de cible de rendu devient une passe de rendu Metal complète. Les GPU de téléphone ont la même architecture à tuiles : il faut s'attendre au coût de Chrome, pas à celui de Firefox. À 93 images/s, Firefox reste aussi sous les 120 Hz, et trois images sur quatre sont des doublons (problème 3).

  Pour compter les images rendues par seconde, coller ceci dans la console de la page du jeu. Le script peut être relancé : il garde la fonction d'origine.

  ```js
  (() => {
    const prototype = PIXI.Renderer.prototype;
    const render = prototype.originalRender ?? (prototype.originalRender = prototype.render);
    let renders = 0;
    prototype.render = function (...args) { renders++; return render.apply(this, args); };
    setTimeout(() => console.log('images rendues par seconde :', renders / 5), 5000);
  })();
  ```

- **Appareils visés : les téléphones modestes aussi.** Les lots 4 à 7 sont donc nécessaires, pas secondaires.
- **Netteté sur écran Retina.** Le canvas fait 640 × 768 pixels, puis le navigateur l'agrandit. Le passer à la résolution de l'écran rendrait l'image nette, mais multiplierait par 4 les pixels à remplir. C'est un choix de rendu, à trancher à part.
