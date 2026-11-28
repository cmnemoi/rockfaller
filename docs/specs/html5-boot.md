# Démarrage du jeu en JS : progression et ressources

Partie de l'étape 4 de [`html5-migration.md`](html5-migration.md). Ces règles existaient dans le code et les tests (`tools/BootCheck.hx`, `tools/AssetCheck.hx`, `html5/test/game.spec.mjs`) sans spec : l'audit [`html5-performance.md`](html5-performance.md) a relevé cette dérive. Cette spec les écrit telles que les tests les vérifient.

## Pourquoi

Le build Flash embarque ses images, ses textes et ses sons dans le SWF, et les lit de façon synchrone. Le navigateur les télécharge, et décode images et sons de façon asynchrone. Le jeu, lui, ne change pas : il lit toujours ses ressources de façon synchrone. Le build JS les charge donc toutes avant de lancer le jeu.

## Règles

### La progression vit dans `localStorage`

`{#html5.boot::progress-in-local-storage}`

La progression est le JSON que `ProgressJson` écrit, la même chaîne que le build Flash garde dans son `SharedObject`. Le build JS la garde dans `localStorage`, sous la clé `rockfaller.progress`. Sans progression enregistrée, une nouvelle partie commence. Si le stockage est bloqué ou plein, le jeu continue sans enregistrer, comme le build Flash.

### Tout est chargé avant le jeu

`{#html5.boot::everything-preloaded}`

`GameMain` charge, avec une barre de progression, toutes les ressources que `AssetManifest` liste à la compilation : les images et leurs textes (`assetsWeb`), les polices, et les 81 sons (`sfx`). Une image est connue par son chemin dans `assetsWeb` (`design.png`, `worlds/worldMagma.png`). Seules `levels.png` et `levels2.png` gardent aussi leurs pixels en mémoire : `ButtonLevel` y lit les marques rouges de la carte, et garder ceux d'un atlas de 2048 px coûte 16 Mo. Puis le jeu démarre sur son premier écran, sans erreur JavaScript.

### Une ressource se lit comme en Flash, une fois chargée

`{#html5.assets::preloaded-before-use}`

`mt.Assets`, `openfl.Assets` et `hxd.Res` lisent les ressources chargées (`AssetStore`) : une image donne sa tuile, un texte se lit en texte ou en octets (UTF-8 gardé), une police se trouve par son nom de fichier. Une ressource qui n'a pas été chargée fait échouer la lecture, avec un message qui nomme son chemin.

### Les pixels se lisent comme en Flash

`{#html5.assets::pixels-like-flash}`

Pour une image qui garde ses pixels, `getPixel` rend la couleur sans l'alpha, comme le `BitmapData.getPixel` de Flash.

### Une tuile de couleur

`{#html5.assets::color-tile}`

`Tile.fromColor(couleur, largeur, hauteur)` donne une tuile de cette taille, sans décalage, sur une texture de cette couleur, comme le fork.

## Critères d'acceptation

Compilés en JS, lancés par Node (`BootCheck`, `AssetCheck`) :

- Étant donné le niveau 1 gagné avec 4800 points et enregistré, quand la progression est relue, alors le niveau 2 est débloqué et le meilleur score du niveau 1 vaut 4800.
- Étant donné un stockage vide, alors une nouvelle partie commence au niveau 1.
- Étant donné un stockage bloqué, alors une nouvelle partie commence, et l'enregistrer n'échoue pas.
- Étant donné le manifeste, alors il liste `design.png` et `worlds/worldMagma.png` par leur chemin, et `worlds/worldMagma.meta.json`.
- Étant donné le manifeste, alors seules `levels.png` et `levels2.png` gardent leurs pixels.
- Étant donné le manifeste, alors il liste les 81 sons par nom de fichier, dont `Rockfaller_WIN.mp3`.
- Étant donné `Tile.fromColor(0xFF000000, 640, 768)`, alors la tuile fait 640 × 768, sans décalage, sur une texture noire opaque.
- Étant donné `design.png` chargée, alors `mt.Assets.getTile` en donne une tuile de 1024 × 512 ; `platypus.png`, non chargée, échoue en nommant `platypus.png`.
- Étant donné une image de 2 × 1 pixels qui garde ses pixels, rouge puis bleu à moitié transparent, alors `getPixel` lit `0xFF0000` puis `0x0000FF`.
- Étant donné `data/loot.json` chargé, alors il se lit en texte et en octets, accents gardés ; un texte non chargé échoue en nommant son chemin.
- Étant donné `assets/BenchNine-Regular.ttf` chargée, alors `openfl.Assets.getFont` donne la famille `BenchNine`.

Playwright (`game.spec.mjs`) :

- Étant donné la page du jeu, alors elle charge ses ressources, puis démarre sans erreur JavaScript.

## À venir

Le lot 8 du plan [`html5-performance-plan.md`](html5-performance-plan.md) ajoutera ici l'envoi des textures au GPU pendant le chargement (`html5.boot::textures-sent-while-loading`), selon la mesure sur téléphone.
