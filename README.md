# Rockfaller Journey

Remise en route de **Rockfaller Journey** (Motion-Twin, 2015), un jeu de puzzle en Flash, à partir des sources publiées dans les [archives de jeux web de Motion-Twin](https://github.com/motion-twin/WebGamesArchives).

Le serveur d'origine n'existe plus. Le jeu tourne donc hors-ligne : un faux serveur local répond à sa place, et les 180 niveaux ont été reconstruits à partir d'une vidéo de partie.

**Jouer dans le navigateur :** https://cmnemoi.github.io/rockfaller/ (avec [Ruffle](https://ruffle.rs), l'émulateur Flash).

## État

- Les 180 niveaux sont jouables. 22 niveaux à gélatine ont peut-être moins de cases de gélatine que dans le jeu d'origine.
- La progression (niveaux débloqués et meilleurs scores) est sauvegardée dans le navigateur, par le stockage local de Ruffle.
- Les mécaniques propres à certains niveaux (eau, magma, motifs, geysers) ne sont pas encore reconstruites.
- L'éditeur de niveaux ne compile pas.

Le détail est dans [`docs/PLAN.md`](docs/PLAN.md).

## Construire le jeu

Prérequis : [mise](https://mise.jdx.dev) (il installe Haxe 3.2.1 et Neko 2.1, voir `mise.toml`).

```bash
mise run install  # haxelibs aux versions fixées, dans .haxelib/
mise run test     # faux serveur, progression et extraction des niveaux
mise run serve    # construit le SWF et la page web, puis les sert sur http://localhost:8000
```

`mise tasks` liste toutes les tâches (`build`, `web`, `check:protocol`…).

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
