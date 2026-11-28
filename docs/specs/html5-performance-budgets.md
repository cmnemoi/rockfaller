# Budgets de performance de la version PixiJS

Les règles observables qui gardent la version PixiJS rapide. Elles viennent de l'audit [`html5-performance.md`](html5-performance.md) ; le plan [`html5-performance-plan.md`](html5-performance-plan.md) dit quel lot rend chacune vraie.

## Pourquoi

Dans Chrome, la version PixiJS dessine 9 à 12 images par seconde, et les téléphones modestes sont une cible. Une correction de performance se perd sans bruit, au détour d'un autre changement. Ces budgets la gardent : chacun est un compte exact, vérifié par un test.

## Méthode

- Les tests comptent des choses exactes : changements de cible de rendu, appels GPU, sprites filtrés, programmes liés, rappels `requestAnimationFrame`. Ces comptes ne dépendent pas de la machine : ils tiennent en CI, même sur SwiftShader.
- Les durées et la mémoire se mesurent avec la sonde (`mise run perf`), hors CI, et se notent dans l'audit.

## Le compteur

`{#html5.perf::meter-off-by-default}`

Sans `perf` dans l'adresse de la page du jeu, le compteur ne s'installe pas : la page et le jeu ne changent pas.

Avec `?perf`, le compteur s'installe avant PixiJS. Pour chaque image rendue, il compte :

- les appels GPU (`drawElements`, `drawArrays`) ;
- les changements de cible de rendu (`bindFramebuffer`) ;
- les sprites visibles, ceux qui ont un filtre et ceux qui ont un masque ;
- les programmes liés et les envois de textures ;
- les rappels `requestAnimationFrame` et le temps JavaScript de chacun.

Deux fois par seconde, il affiche dans un coin de la page les images rendues par seconde et ces comptes. Il les expose aussi dans `window.rockfallerPerf`, pour les tests et la sonde. Sur un téléphone, il suffit d'ouvrir `/pixi/game.html?perf`.

### Critères d'acceptation (Playwright)

- Étant donné la page du jeu sans `?perf`, alors elle n'a ni affichage du compteur, ni `window.rockfallerPerf`.
- Étant donné la page du jeu avec `?perf`, après 2 s de jeu, alors le compteur a vu des images rendues, et chacune a fait au moins un appel GPU.
- Étant donné la page du jeu avec `?perf`, alors l'affichage montre les images rendues par seconde.

## Pas de passe de rendu sur les menus

`{#html5.perf::no-render-pass-on-menus}`

Sur la carte et sur la fenêtre de niveau, aucune image ne change de cible de rendu, et aucun sprite n'a de filtre. Les textes colorés, seuls porteurs de filtres sur ces écrans, passent par la teinte (`html5.h2d.color::multiplied-color-as-tint`).

### Critères d'acceptation (Playwright, page du jeu avec `?perf`)

- Étant donné le niveau 5 débloqué et la fenêtre LOGIN fermée, quand la carte s'affiche, alors aucune image ne change de cible de rendu, et aucun sprite n'a de filtre.
- Étant donné la fenêtre du niveau 5 ouverte, alors aucune image ne change de cible de rendu, et aucun sprite n'a de filtre.

## Pas de passe de rendu en partie

`{#html5.perf::no-render-pass-in-game}`

Au tutoriel, en partie et pendant les coups, aucune image ne change de cible de rendu, sauf pour les sprites masqués (`alphaMap`, le projecteur du tutoriel) : un masque PixiJS est un filtre, qui en coûte deux. Une image fait au plus 30 appels GPU : les effets des combos changent de mode de mélange, jusqu'à 18 appels mesurés. Les couleurs qui mélangent les canaux, comme celle des particules de magma, passent par le shader de lot (`html5.h2d.color::color-matrix-in-batch`).

### Critères d'acceptation (Playwright, page du jeu avec `?perf`)

- Étant donné une nouvelle partie, quand la première bulle du tutoriel s'affiche, alors chaque image change de cible au plus 2 fois par sprite masqué, et fait au plus 30 appels GPU.
- Étant donné le niveau 5 lancé, puis 6 clics sur la grille, alors aucune image ne change de cible, et chacune fait au plus 30 appels GPU.

## Pas de shader compilé en jouant

`{#html5.perf::no-shader-while-playing}`

Lier un programme GPU fige le jeu : 378 ms au premier masque du projecteur du tutoriel. Aucune image montrée sur la page ne lie de programme, jusqu'au projecteur compris. Les shaders sont préparés avant, hors écran (`html5.h2d::shaders-ready-before-play`).

### Critères d'acceptation (Playwright, page du jeu avec `?perf`)

- Étant donné une nouvelle partie, quand le joueur passe la première bulle du tutoriel jusqu'au projecteur, alors aucune image montrée sur la page n'a lié de programme.

## Une seule boucle

`{#html5.perf::one-loop}`

La page reçoit un seul rappel `requestAnimationFrame` par image : celui de la boucle du jeu. Le gestionnaire d'interaction de PixiJS en ajoutait un second, et testait les 800 à 1300 sprites à chaque mouvement du pointeur (`html5.h2d::renderer-settings`).

### Critère d'acceptation (Playwright, page du jeu avec `?perf`)

- Étant donné le jeu lancé, alors chaque image montrée sur la page reçoit un seul rappel `requestAnimationFrame`.

## Budgets à venir

Chaque budget s'écrit ici, avec ses critères, au début de son lot.

| Règle | Lot | Aujourd'hui |
|---|---|---|
| `html5.perf::no-identical-frame` : 30 images rendues par seconde à 60 Hz comme à 120 Hz | 5 | une par rafraîchissement de l'écran |
| `html5.perf::little-garbage-per-frame` : au plus 100 Ko alloués par image rendue (sonde) | 6 | environ 1 070 Ko |
| `html5.perf::sound-memory` : sons décodés au démarrage sous le seuil choisi (sonde) | 7 | 209 Mo |
| `html5.perf::no-upload-while-playing` : aucun envoi de texture pendant le défilement de la carte ni en partie | 8 | 5 à 11 envois au défilement |

## Hors périmètre

- Des seuils de durée en CI : ils varient avec la machine.
- Firefox dans les tests : le Firefox de Playwright installé ici est trop vieux. Le compteur `?perf` permet de le mesurer à la main.
