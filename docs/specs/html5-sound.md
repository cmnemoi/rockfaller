# Le son en JS

Partie de l'étape 4 de [`html5-migration.md`](html5-migration.md). Trouvé par la méthode Mikado sur le vrai client : `SoundManager` utilise `mt.flash.Sfx`, qui repose sur `flash.media.Sound`.

## Pourquoi

Le jeu joue ses 81 sons (MP3) avec `mt.flash.Sfx` : `play` 43 fois, `isPlaying` 31, `stop` 9, `setVolume` 6. Le build JS n'a pas accès au paquet `flash`.

## Méthode

Toute la logique de `Sfx` est pure : canaux, volume global, sourdine, fondus, liste des sons qui jouent. Seules trois classes Flash touchent à la plateforme : `Sound`, `SoundChannel` et `SoundTransform`. Parallel Change dans `Sfx` : dans le build Flash, rien ne change ; dans le build JS, `Sfx` utilise `mt.audio.Sound`, `mt.audio.SoundChannel` et `mt.audio.SoundTransform`, qui ont la même petite API et jouent avec Web Audio.

## Règles

### Le build Flash ne change pas

`{#html5.sound::flash-build-unchanged}`

Le SWF reste identique octet pour octet après le Parallel Change de `Sfx`.

### Un son se joue, se règle et s'arrête comme avec `Sfx`

`{#html5.sound::sfx-like-flash}`

Le volume réel d'un son est celui de `Sfx` : volume du son × volume global × volume du canal, à 0 si le son, son canal ou tout le son est coupé, borné entre 0 et 1. Changer un de ces réglages change le volume des sons qui jouent. `play` arrête d'abord le son s'il jouait déjà. `isPlaying` est vrai entre `play` et la fin ou `stop`. À la fin d'un son, `Sfx` le retire des sons qui jouent et appelle une fois le rappel de `onEndOnce`. Une boucle de N tours joue N fois avant de finir.

### Les musiques se téléchargent comme avec `Sfx.download`

`{#html5.sound::download-like-flash}`

Le jeu télécharge ses deux musiques avec `Sfx.download` (`Rockfaller_interface.mp3`, `Rockfaller_ingame.mp3`). En JS, `Sfx.download` télécharge et décode le MP3, puis appelle le rappel de fin avec le `Sfx`. Une erreur de téléchargement ou de décodage appelle le rappel d'erreur avec un message qui nomme l'adresse : `SoundManager` réessaie alors plus tard.

### Le son démarre au premier clic

`{#html5::sound-starts-on-first-click}` (règle de [`html5-migration.md`](html5-migration.md))

Les navigateurs bloquent le son avant un geste de l'utilisateur. Le moteur Web Audio reprend son contexte au premier appui ou toucher. Avant, les sons « jouent » en silence : `isPlaying` reste vrai et la logique du jeu ne change pas. Quand le contexte démarre, un son qui joue encore en silence continue à voix haute, là où il en est : c'est le cas de la musique du niveau 1, lancée avant le premier clic. Une durée au-delà de la limite de `setTimeout` (2³¹ − 1 ms, comme 999 999 tours d'une musique) ne programme pas de fin.

Bug trouvé en jouant : la musique du niveau 1 ne s'entendait pas, celle du niveau 2 si.

### Les sons sont prêts avant le jeu

`{#html5.sound::sounds-preloaded}`

`Sfx` lit ses sons de façon synchrone (`getAsset`). En JS, le décodage d'un MP3 est asynchrone : le chargement du jeu précharge et décode tous les sons avant de lancer le jeu. Un son qui ne se charge pas donne une erreur qui le nomme.

## Critères d'acceptation

Compilés en JS, lancés par Node, avec un faux moteur audio :

- Étant donné un son de volume 0,5 sur le canal 2 de volume 0,5, avec un volume global de 0,8, quand il joue, alors son volume réel vaut 0,2.
- Étant donné un son qui joue, quand on coupe son canal, alors son volume réel passe à 0. Quand on rétablit le canal, il revient.
- Étant donné un son qui joue, quand on le rejoue, alors le premier jeu s'arrête avant le second.
- Étant donné un son qui joue, quand il finit, alors `isPlaying` devient faux, et le rappel de `onEndOnce` est appelé une seule fois.
- Étant donné un son qui joue, quand on l'arrête, alors `isPlaying` devient faux, et le rappel de fin n'est pas appelé.
- Étant donné `Sfx.disable()`, quand on joue un son, alors il ne joue pas.

Playwright :

- Étant donné la page sans clic, alors le contexte audio est suspendu. Après un clic, il tourne.
- Étant donné un son préchargé, quand on le joue, alors le moteur Web Audio crée une source sur ce son.

## Hors périmètre

- La spatialisation (`playSpatial`, `spatialize`) et le compteur de rythme : le jeu ne les utilise pas. Le code reste dans `Sfx`, il marche s'il est appelé.
- La barre de chargement Flash de `Sfx.download` : le jeu la cache déjà (`SHOW_PROGRESS_BARS = false`).
