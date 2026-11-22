# Inventaire : ce que le client utilise du moteur

Mesuré le 2026-11-22, à l'étape 2 de [`html5-migration.md`](html5-migration.md). Cet inventaire remplace les estimations de départ (« ~10 classes `h2d`, ~10 fichiers `flash.*` »), qui étaient trop basses.

## Méthode et limites

1. **Compilation Haxe 4 vers JS** du client (`WebMain`). Le compilateur s'arrête à la première erreur : `You cannot access the flash package while targeting js` (`WebMain.hx:48`). Il ne donne donc pas une liste complète.
2. **Compilation Haxe 4 vers SWF**, où `flash.*` est permis. Elle échoue dans Lime 2.9.1, qui remplace `haxe.CallStack` de la bibliothèque standard. **OpenFL 3.6.1 et Lime 2.9.1 ne marchent pas en Haxe 4.** Le build JS ne peut pas les utiliser.
3. **Inventaire statique** (script jetable). Le script part de `client/client/src` et de `src/com`, puis suit les `import`, les noms qualifiés et les classes du même paquet. Il compte les fichiers qui mentionnent chaque type de `flash`, `openfl`, `h2d`, `hxd` et `h3d`.

Limites de l'inventaire statique :
- Il surestime : un fichier atteint par un `import` n'est pas forcément exécuté, et le script ne lit pas les `#if`.
- Il ne trouve pas les ruptures de syntaxe ou de typage entre Haxe 3 et Haxe 4. On les trouvera fichier par fichier, à l'étape 4.

## Résultats

Fichiers atteints : **146 fichiers, 35 603 lignes**. 77 de ces fichiers sont dans `client/mt`.

| Paquet | Types utilisés | Fichiers |
|---|---|---|
| `h2d` | 17 | 61 |
| `flash` | 55 | 33 |
| `h3d` | 7 | 19 |
| `hxd` | 14 | 18 |
| `openfl` | 11 | 13 |

### `h2d` : ce que la couche sur PixiJS doit fournir

Nombre de fichiers par type :

| Type | Fichiers | Type | Fichiers |
|---|---|---|---|
| `Sprite` | 35 | `Scene` | 4 |
| `Text` | 30 | `BlendMode` | 3 |
| `SpriteBatch` | 17 | `col.Point` | 3 |
| `Tile` | 14 | `Font` | 2 |
| `Interactive` | 12 | `Console` | 1 |
| `Bitmap` | 11 | `Graphics` | 1 |
| `Layers` | 10 | `RenderContext` | 1 |
| `Drawable` | 6 | `TextBatchElement`, `Tools` | 1 chacun |

`h2d.Text` et `h2d.Font` sont utilisés 173 fois dans `client/client/src`.

### `hxd` et `h3d`

- `hxd` (18 fichiers) : `Event` 4, `System` 4, `BitmapData` 3, `Float32` 2, `Res` 2, `Stage` 2, `res.FontBuilder` 2, puis `Charset`, `DrawProfiler`, `Math`, `Pixels`, `Profiler`, `Timer`, `UString` (1 chacun).
- `h3d` (19 fichiers) : `Engine` 9, `Vector` 6, `mat.Texture` 5, `Matrix` 3, `impl.Stage3dDriver` 2, `mat.Data` 1.

La couche doit donc aussi fournir une partie de `hxd` (événements, boucle, timer) et de `h3d` (`Engine`, `Vector`, `Texture`).

### `flash` et `openfl` : les Parallel Change à faire

Fichiers qui utilisent le plus `flash.*` ou `openfl.*` (nombre de lignes) :

| Lignes | Fichier | Sujet |
|---|---|---|
| 49 | `client/mt/deepnight/Lib.hx` | utilitaires `flash.display` |
| 47 | `client/mt/deepnight/Color.hx` | couleurs, `ColorTransform` |
| 39 | `client/client/src/manager/SoundManager.hx` | son |
| 32 | `client/mt/flash/Lib.hx` | utilitaires Flash |
| 23 | `client/mt/flash/Sfx.hx` | son |
| 23 | `client/mt/deepnight/deprecated/SpriteLibBitmap.hx` | ancienne SpriteLib |
| 21 | `client/mt/flash/EventTools.hx` | événements |
| 18 | `client/client/src/WebMain.hx` | point d'entrée, erreurs |
| 16 | `client/mt/deepnight/slb/BLib.hx` | **SpriteLib** |
| 14 | `client/mt/deepnight/deprecated/Process.hx` | boucle |
| 13 | `client/mt/deepnight/slb/BSprite.hx` | sprites Flash de la SpriteLib |
| 10 | `client/client/src/data/DataManager.hx` | données, stockage |
| 10 | `client/client/src/PreloaderOFL.hx` | préchargeur Flash |
| 10 | `client/client/src/Main.hx` | boucle, scène |

Les 28 autres fichiers ont moins de 10 lignes chacun.

## Ce que l'inventaire change au plan

1. **La SpriteLib mélange les deux moteurs.** `BLib` prend un `flash.display.BitmapData` dans son constructeur. Elle garde ce type même dans le build Heaps, qui passe `null`. `HSprite` et `HSpriteBE` n'utilisent que `h2d`. `BSprite` (sprites Flash) ne sert qu'au préchargeur Flash (`PreloaderOFL`), que le build JS remplace. `BLib` a donc besoin d'un Parallel Change avant que `HSprite` puisse tourner sur PixiJS.
2. **La couche `h2d` est plus grande que prévu.** Elle compte 17 types, plus une partie de `hxd` et de `h3d`. `Text` et `Font` sont le plus gros morceau, après `Sprite`.
3. **Le code de jeu est très couplé.** `Rock` dépend du singleton `Game` et de cinq managers. Afficher la grille d'un niveau avec le vrai code du jeu demande presque tout le jeu. L'afficher avec du code écrit pour la page dupliquerait la mise en page de `Rock`, et ce code serait jeté ensuite.
4. **OpenFL et Lime ne passent pas en Haxe 4.** Les 13 fichiers qui utilisent `openfl.*` ont tous besoin d'un Parallel Change, comme ceux qui utilisent `flash.*`.
