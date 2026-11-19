# Rockfaller Journey

Remise en route de **Rockfaller Journey** (Motion-Twin, 2015), un jeu de puzzle en Flash, à partir des sources publiées dans les [archives de jeux web de Motion-Twin](https://github.com/motion-twin/WebGamesArchives).

Le serveur d'origine n'existe plus. Le jeu tourne donc hors-ligne : un faux serveur local répond à sa place, et les 180 niveaux ont été reconstruits à partir d'une vidéo de partie.

**Jouer dans le navigateur :** https://cmnemoi.github.io/rockfaller/ (avec [Ruffle](https://ruffle.rs), l'émulateur Flash).

## État

- Les 180 niveaux sont jouables, sauf 7 dont l'objectif n'a pas pu être lu dans la vidéo (29, 35, 92, 124, 133, 138, 145).
- La progression n'est pas sauvegardée : elle revient au niveau 1 à chaque chargement.
- Les mécaniques propres à certains niveaux (eau, magma, motifs, geysers) ne sont pas encore reconstruites.
- L'éditeur de niveaux ne compile pas.

Le détail est dans [`docs/PLAN.md`](docs/PLAN.md).

## Construire le jeu

Prérequis : [mise](https://mise.jdx.dev) (il installe Haxe 3.2.1 et Neko 2.1, voir `mise.toml`).

```bash
mise exec -- bash tools/install-deps.sh               # haxelibs aux versions fixées, dans .haxelib/
mise exec -- bash tools/build-flash.sh client release # client/client/bin/flash/bin/rockFallerMobile.swf
```

Tester :

```bash
mise exec -- haxe -cp . -cp src/com -D version2_1 -resource data/levels.json@levels -main tools.ProtocolCheck --interp
uv run tools/levels/test_classify_cells.py
uv run tools/levels/test_read_hud.py
uv run tools/levels/test_build_levels.py
```

`tools/levels/test_segment_video.py` demande les vidéos (`tools/levels/download_videos.sh`, 2,8 Go).

## Organisation

| Dossier | Contenu |
|---|---|
| `client/client` | Le client du jeu (Haxe, OpenFL, Heaps). |
| `client/levelEditor` | L'éditeur de niveaux de Motion-Twin. |
| `client/mt` | La bibliothèque `mt` de Motion-Twin, plus des stubs pour les modules absents des archives. |
| `src/com` | Types partagés et faux serveur (`Protocol.hx`). |
| `data` | Données du jeu, dont `levels.json` (les 180 niveaux). |
| `tools/levels` | Reconstruction des niveaux à partir de la vidéo. |
| `tools/fonts` | Reconstruction des atlas de polices manquants. |
| `docs` | Audit, plan et notes de travail. |

## Crédits et licence

- **Jeu :** Motion-Twin. Sources et données sous licence [CC BY-NC-SA 4.0](http://creativecommons.org/licenses/by-nc-sa/4.0/).
- **Niveaux :** reconstruits à partir de la playlist [« Rockfaller Journey » de Glitch3d](https://www.youtube.com/playlist?list=PLVHaVMlXRNl7CztZj_biaFGHSgDMpAZfT).
- **Polices :** BenchNine (Vernon Adams, SIL Open Font License). La licence de Mouse Deco et de Birmingham reste à vérifier.

Ce dépôt reste sous la même licence, CC BY-NC-SA 4.0 : pas d'usage commercial.
