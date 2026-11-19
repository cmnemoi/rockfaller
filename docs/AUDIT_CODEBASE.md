# Audit technique du codebase Rockfaller

Date: 2026-02-14

## TL;DR

- Le repo contient la logique centrale du jeu et de l'editeur, mais il est **incomplet** pour un lancement direct (assets manquants, module `Protocol` absent).
- L'application est basee sur une stack legacy **Haxe + OpenFL + Heaps** avec une cible historique Flash/standalone.
- Dans l'etat actuel, le projet ne demarre pas sans restaurer plusieurs fichiers/dependances manquants.

## 1) Comment le codebase est organise

Structure principale:

- `client/client/`: client du jeu (runtime principal)
- `client/levelEditor/`: editeur de niveaux
- `src/com/`: types et structures partages (`Common.hx`)
- `data/`: donnees de jeu (`data.cdb`, `goals.cdb`, `loot.json`)
- `mt/`: bibliotheque utilitaire Motion-Twin + stubs locaux
- `www/`: assets web (images, musiques)
- `docs/`: documentation

## 2) Comment l'application est censee fonctionner

### 2.1 Pipeline de demarrage (jeu)

1. Entree OpenFL: `client/client/application.xml` avec `main="WebMain"`.
2. `WebMain` initialise le contexte, puis cree `Main`.
3. `Main.PREPARE_FIRST_INIT()` cree le moteur Heaps (`h3d.Engine`) et la scene.
4. `PreloaderH2D` charge progressivement:
   - audio
   - atlas textures (XML/PNG)
   - fontes
   - niveau de donnees initiales
5. `ProcessManager` pilote la navigation entre ecrans:
   - carte des niveaux (`process/Levels`)
   - partie (`process/Game`)
   - popups.

### 2.2 Gameplay

- Le jeu est un puzzle grid-based (rotation de groupes), avec:
  - etats de simulation (`manager/StateManager.hx`)
  - logique des roches (`Rock.hx`)
  - systemes specials (magma, eau, patterns, etc.)
- Les definitions de types metier (roches, objectifs, niveaux, user data) sont dans `src/com/Common.hx`.

### 2.3 Donnees

- `data/data.cdb` contient des tables gameplay (format CastleDB, ex: loot).
- `data/goals.cdb` contient des objectifs/traductions associees.
- `data/loot.json` apporte des labels de loot utilises au runtime.

### 2.4 Reseau / protocole

- Les appels applicatifs passent par `DataManager.DO_PROTOCOL(...)`.
- URLs cibles configurees: `/api/v<version>` (ex: `/api/v15`).
- Blocage identifie: le code depend d'un module `Protocol` (types et constantes), mais ce module n'est pas present dans ce repo.

## 3) Comment lancer l'application (intention projet)

### 3.1 Pre-requis attendus

- Haxe 3.4.7
- Neko 2.2.0
- haxelibs: `openfl`, `lime`, `h3d`, `castle` (+ selon cible)

Le fichier `mise.toml` indique explicitement Haxe/Neko attendus.

### 3.2 Commandes de lancement (a verifier)

Jeu:

```bash
cd client/client
haxelib run openfl test application.xml flash
```

Editeur:

```bash
cd client/levelEditor
haxelib run openfl test application.xml flash
```

## 4) Verification pratique effectuee (dans cet audit)

Ce qui a ete teste:

- `haxe -version`: OK (3.4.7)
- `haxelib list`: OK (openfl/lime/h3d/castle presents)
- `haxelib run openfl help`: OK

Echecs de build constates:

1. Client OpenFL: asset path manquant `./sfx_low`
2. Client avec `-D cpp`: asset path manquant `./sfxOgg`
3. Level editor OpenFL: haxelib manquant `air3`
4. Compilation Haxe directe (client): `Type not found : Protocol`
5. Compilation Haxe directe (editeur): `Type not found: Protocol`

Outil de post-build absent:

- `obfu9` non installe (utilise dans `application.xml` pour postBuild flash)

## 5) Ce qu'il manque / ce qui bloque

### 5.1 Bloquants majeurs

1. **Module `Protocol` absent**
   - Imports omnipresents (`import Protocol;`)
   - Enums/types/constants requis: `ProtocolCom`, `ProtocolError`, `InitClient`, `MAX_LIFES`, `TIME_REFILL_LIFE`, etc.

2. **Assets references mais absents/incoherents dans le layout actuel**
   - Dossiers audio attendus: `sfx_low`, `sfxOgg`
   - Fontes attendues: `assets/BenchNine-Regular.ttf`, `assets/Mouse_Deco.ttf`

3. **Dependances de build non satisfaites**
   - `air3` requis par l'editeur
   - `obfu9` requis pour certaines etapes post-build

4. **Stubs incomplets/incompatibles**
   - `Main` appelle `w.checkDone()` mais `mt/Worker.hx` ne fournit pas cette methode.

5. **Mode offline non fonctionnel en l'etat**
   - `mt/net/Codec.requestUrl()` retourne toujours une erreur.
   - Le preloader `standalone` entre en boucle de retry infini (observe pendant l'audit).

### 5.2 Impact produit

- En l'etat actuel, impossible d'obtenir un run local fiable du jeu complet sans correction des points de la section 5.1.
- L'editeur ne peut pas etre valide de bout en bout non plus.

## 6) Diagnostic global

Le codebase est une archive partielle d'un projet production legacy. La logique gameplay est largement presente, mais il manque des briques essentielles de build/runtime (protocole, assets, dependances/outils), ce qui bloque le lancement immediat.

## 7) Plan de remise en route recommande

### Priorite P0 (bloquant)

- [ ] Restaurer le module `Protocol` (ou un stub complet compatible).
- [ ] Corriger/aligner les paths d'assets (`sfx_low`/`sfxOgg`, fontes).
- [ ] Completer `mt/Worker` pour respecter l'API attendue (`checkDone` notamment).

### Priorite P1 (fonctionnel)

- [ ] Choisir une strategie de mode offline:
  - soit faux backend local (reponses `ProtocolCom` valides)
  - soit des donnees de bootstrap embarquees.
- [ ] Rendre les builds independants de `obfu9` en dev local (conditionner le postBuild).

### Priorite P2 (qualite de vie)

- [ ] Requalifier l'editeur (`air3` ou suppression de la dependance si obsolete).
- [ ] Ajouter un README de run minimal (pre-requis + commandes + limites connues).

## 8) Conclusion et prochaine etape

En l'etat, **ce n'est pas lancable directement** sans travaux de reconstruction. La base technique est exploitable, mais il faut d'abord combler les manques structurels cites ci-dessus.

Prochaine etape recommandee: traiter la priorite P0, en commencant par la restauration de `Protocol`.
