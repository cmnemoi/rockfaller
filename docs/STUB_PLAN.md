# Plan de stub pour les modules `mt.*` manquants

## Vue d'ensemble

Ce document detalhe le plan d'implementation des stubs pour les **18 modules `mt.*`** qui ne sont pas presentes dans le dossier `mt/` fourni par Motion-Twin.

Ces stubs permettent de compiler et d'executer le jeu **Rockfaller** en mode standalone/offline, sans necessiter le serveur backend ni les services plateformes (Facebook, Game Center, etc.).

---

## Bilan de couverture

| Statut | Nombre | Pourcentage |
|---|---|---|
| Modules presents | ~49 | ~80% |
| Modules a stubber | 18 | ~20% |

Les modules manquants se répartissent en trois catégories :
- **Infrastructure plateforme** : réseau, assets, sauvegarde, workers
- **Analytics/Social** : tracking, utilisateurs, amis,achats
- **Utilitaires** : Math, Console, Types divers

---

## Ordre d'implementation recommande

```
Triviale/Faible → Critique → Moyenne
```

1. `mt/MLib.hx` — Fonctions math triviales
2. `mt/Console.hx` — Debug console
3. `mt/Page.hx` — Dead code (level editor)
4. `mt/net/Error.hx` — Type alias simple
5. `mt/flash/VarSecure.hx` — Wrapper simple
6. **`mt/Worker.hx`** — Systeme de taches (CRITIQUE)
7. **`mt/net/Http.hx`** — Requetes HTTP (CRITIQUE)
8. **`mt/net/Codec.hx`** — Protocole reseau (CRITIQUE)
9. `mt/device/EventTracker.hx` — Analytics
10. `mt/device/User.hx` — Auth utilisateur
11. `mt/net/FriendRequest.hx` — Types sociaux
12. `mt/device/Facebook.hx` — Facebook
13. `mt/device/FriendRequest.hx` — Amis
14. `mt/device/GameCenter.hx` — Game Center
15. `mt/device/TextField.hx` — Champ texte
16. `mt/device/Cash.hx` — Achats in-app
17. **`mt/SecureSO.hx`** — Sauvegarde joueur (CRITIQUE)
18. **`mt/Assets.hx`** — Chargement assets (CRITIQUE)
19. Redirections `mt/deepnight/HProcess` / `Process`

---

## Detail des modules a stubber

### Priorite CRITIQUE (5 modules)

#### 1. `mt/Worker.hx` — Systeme de taches asynchrones

**Fichier:** `mt/Worker.hx`

**Usage:** 6 fichiers (Main, PreloaderH2D, SubLoader, AssetManager, LevelDesign, MobileServer)

**API requise:**
```haxe
package mt;

class Worker {
    public function new() {}
    public function enqueue(task:WorkerTask):Void;
}

class WorkerTask {
    public var onComplete:Null<Void->Void>;
    public function new(work:Void->Void);
}
```

**Strategie:** Execution synchrone immediate. `enqueue()` execute la tache puis appelle `onComplete` directement (pas de thread separé). Fonctionne pour le mode standalone.

---

#### 2. `mt/Assets.hx` — Chargement des assets graphiques

**Fichier:** `mt/Assets.hx`

**Usage:** 3 fichiers (PreloaderH2D, AssetManager, SubLoader)

**API requise:**
```haxe
package mt;

class Assets {
    // Config
    static var USE_HALF_SIZE:Bool;
    static var USE_CACHE:Bool;

    // Methodes
    static function getTile(path:String):Void->h2d.Tile;
    static function getTileDeferred(path:String, worker:Worker, callback:h2d.Tile->Void):Void;

    // Types internes
    class PVRTexture extends h3d.mat.Texture {
        function reallocMT():Dynamic;
    }
}
```

**Strategie:** Deleguer au systeme de ressources Heaps (`hxd.Res`). Retourner un thunk qui charge la texture a la demande.

---

#### 3. `mt/SecureSO.hx` — Sauvegarde securisee

**Fichier:** `mt/SecureSO.hx`

**Usage:** 1 fichier (LevelDesign)

**API requise:**
```haxe
package mt;

class SecureSO {
    public function new(config:{ name:String, aesKey:Dynamic, aesIv:Dynamic, v2:Bool });
    public function get(key:String):Dynamic;
    public function set(key:String, value:Dynamic):Void;
}
```

**Strategie:** Implementer avec un `Map<String, Dynamic>` simple, sans chiffrement. Pour la persistance, utiliser `sys.io.File` en standalone ou `flash.net.SharedObject` en cible Flash/OpenFL.

---

#### 4. `mt/net/Codec.hx` — Serialisation protocole client-serveur

**Fichier:** `mt/net/Codec.hx`

**Usage:** 5 fichiers (DataManager client/level editor, PreloaderH2D, MobileServer, Main level editor)

**API requise:**
```haxe
package mt.net;

class Codec {
    static function getInitData():Dynamic;  // ProtocolCom
    static function requestUrl(
        url:String,
        data:Dynamic,                      // ProtocolCom
        onSuccess:Dynamic->Void,
        onError:Dynamic->Void,
        ?retry:Int
    ):Void;
}
```

**Strategie:** 
- `getInitData()` retourne `null` (le code client gere deja ce cas avec `if (d != null)`)
- `requestUrl()` appelle `onError` immediatement (mode offline)

---

#### 5. `mt/net/Http.hx` — Requetes HTTP

**Fichier:** `mt/net/Http.hx`

**Usage:** 2 fichiers (WebMain, Main)

**API requise:**
```haxe
package mt.net;

class Http {
    static var DEFAULT_TIMEOUT:Int;

    public function new(url:String);
    public function setParameter(name:String, value:String):Void;
    public function request(post:Bool):Void;
}
```

**Strategie:** Logger les requetes en console au lieu de les envoyer (utilise uniquement pour error logging).

---

### Priorite MOYENNE (5 modules)

#### 6. `mt/flash/VarSecure.hx` — Variable anti-triche

**Fichier:** `mt/flash/VarSecure.hx`

**Usage:** 9 fichiers (Game, UITop, ModuleScore, ModuleMoves, GoalManager, BoosterMoves, Pause, End, DataManager)

**API requise:**
```haxe
package mt.flash;

class VarSecure {
    public var bug:Bool;  // detection de triche

    public function new(initialValue:Int);
    public function get():Int;
    public function setValue(v:Int):Void;
    public function addValue(v:Int):Void;
}
```

**Strategie:** Wrapper simple autour d'un `Int`. `bug` reste toujours `false`.

---

#### 7. `mt/MLib.hx` — Utilitaires mathematiques

**Fichier:** `mt/MLib.hx`

**Usage:** 3 fichiers (FX, End, DataManager)

**API requise:**
```haxe
package mt;

class MLib {
    static function toRad(degrees:Int):Float;
    static function round(v:Float):Int;
}
```

**Strategie:** Implementation triviale avec les fonctions Math standard.

---

#### 8. `mt/device/EventTracker.hx` — Analytics

**Fichier:** `mt/device/EventTracker.hx`

**Usage:** 15 fichiers

**API requise:**
```haxe
package mt.device;

class EventTracker {
    static function view(screenName:String):Void;
    static function track(eventName:String, eventValue:String):Void;
    static function creditSpent(currency:String, amount:Int, item:String):Void;
    static function levelAchieved(level:Int):Void;
    static function tutorialPresented(description:String):Void;
    static function tutorialCompleted(description:String):Void;
    static function twTrack(eventName:String, data:Dynamic):Void;
}
```

**Strategie:** No-op avec `trace()` pour debug.

---

#### 9. `mt/device/User.hx` — Auth utilisateur

**Fichier:** `mt/device/User.hx`

**Usage:** 10 fichiers

**API requise:**
```haxe
package mt.device;

class User {
    static function isLogged():Bool;
    static function login():Void;
    static function logout():Void;
    static function getName():String;
    static function syncGoals():Void;
    static function play(path:String):Void;
}
```

**Strategie:** Retourner `false` pour `isLogged()`, "Guest" pour `getName()`.

---

#### 10. `mt/device/Cash.hx` — Achats in-app

**Fichier:** `mt/device/Cash.hx`

**Usage:** 1 fichier (Shop)

**API requise:**
```haxe
package mt.device;

class Cash {
    static function listProducts(category:String, callback:Null<ProductsData>->Void):Void;
}

typedef Product = {
    var _moneyA:{ _quantity:Int };
    var _localEstimatedPrice:Null<String>;
    var _price:String;
    var _buy:(Transaction->Void)->Void;
};

typedef ProductsData = {
    var list:Array<Product>;
    var otherPayment:Null<(Transaction->Void)->Void>;
};

typedef Transaction = {};
```

**Strategie:** Retourner `null` pour `listProducts()` — le code client gere deja ce cas.

---

### Priorite FAIBLE (8 modules)

#### 11. `mt/net/FriendRequest.hx` — Types de donnees sociales

**Fichier:** `mt/net/FriendRequest.hx`

**Usage:** 3 fichiers (AskLife, Mail, LevelDesign)

```haxe
package mt.net;

class FriendRequest {}

typedef Friend = {
    var net:Int;
    var id:String;
    var name:String;
    var avatar:Null<String>;
    var invitable:Bool;
};

typedef ListResp = Array<{ i:Int, f:Friend, t:Int, d:Null<Dynamic> }>;
```

---

#### 12. `mt/net/Error.hx` — Type d'erreur reseau

**Fichier:** `mt/net/Error.hx`

**Usage:** 1 fichier (MobileServer)

```haxe
package mt.net;

typedef Error = Dynamic;
```

---

#### 13. `mt/device/Facebook.hx` — Integration Facebook

**Fichier:** `mt/device/Facebook.hx`

**Usage:** 1 fichier (AskLife)

```haxe
package mt.device;

class Facebook {
    static function getToken(forceLogin:Bool, callback:Null<String>->Void):Void {
        callback(null);
    }
}
```

---

#### 14. `mt/device/FriendRequest.hx` — Features sociales

**Fichier:** `mt/device/FriendRequest.hx`

**Usage:** 2 fichiers (AskLife, Mail)

```haxe
package mt.device;

class FriendRequest {
    static function friends(arg1:Null<Dynamic>, arg2:Null<Dynamic>,
        callback:Null<Array<mt.net.FriendRequest.Friend>>->Void):Void;
    static function request(typeIndex:Int, message:String,
        friends:Array<mt.net.FriendRequest.Friend>, data:Null<String>,
        callback:Void->Void):Void;
    static function list(callback:mt.net.FriendRequest.ListResp->Void):Void;
    static function accept(ids:Array<Int>, reqDataFn:Int->{ message:String, data:Null<String> },
        callback:Dynamic->Void):Void;
}
```

---

#### 15. `mt/device/GameCenter.hx` — Integration Game Center iOS

**Fichier:** `mt/device/GameCenter.hx`

**Usage:** 1 fichier (Pause)

```haxe
package mt.device;

class GameCenter {
    static function name():Null<String>;
    static function isLogged():Bool;
    static function showAchievements():Void;
    static function connect(callback:Bool->Void):Void;
    static function isAvailable():Bool;
}
```

---

#### 16. `mt/device/TextField.hx` — Champ texte natif

**Fichier:** `mt/device/TextField.hx`

**Usage:** 2 fichiers (AskLife, level editor InputText)

```haxe
package mt.device;

class TextField {
    public var text:String;
    public var textSize:Float;
    public var width:Int;
    public var height:Int;
    public var type:TextFieldType;
    public var x:Int;
    public var y:Int;
    public var textColor:Int;
    public var onTextChanged:Null<String->Void>;

    public function new();
    public function destroy():Void;
}

enum TextFieldType {
    TF_Text;
    TF_Number;
}
```

---

#### 17. `mt/Console.hx` — Debug console

**Fichier:** `mt/Console.hx`

**Usage:** 1 fichier (WebMain)

```haxe
package mt;

class Console {
    static function dump():String;
}
```

---

#### 18. `mt/Page.hx` — Page display (dead code)

**Fichier:** `mt/Page.hx`

**Usage:** 1 fichier (level editor Main)

```haxe
package mt;

#if (flash || openfl)
class Page extends flash.display.Sprite {
    public function update():Void {}
}
#else
class Page {
    public function update():Void {}
}
#end
```

---

### Fix supplementaire : Redirections level editor

Le level editor importe `mt.deepnight.HProcess` et `mt.deepnight.Process` (sans `deprecated`), mais les fichiers sont sous `mt.deepnight.deprecated.*`.

#### Fichier: `mt/deepnight/HProcess.hx`
```haxe
package mt.deepnight;
typedef HProcess = mt.deepnight.deprecated.HProcess;
```

#### Fichier: `mt/deepnight/Process.hx`
```haxe
package mt.deepnight;
typedef Process = mt.deepnight.deprecated.Process;
```

---

## Resume

| Priorite | Modules | Fichiers a creer |
|---|---|---|
| **Critique** | Worker, Assets, SecureSO, Codec, Http | 5 |
| **Moyenne** | VarSecure, MLib, EventTracker, User, Cash | 5 |
| **Faible** | FriendRequest (net), Error, Facebook, FriendRequest (device), GameCenter, TextField, Console, Page | 8 |
| **Fix** | Redirections HProcess/Process | 2 |

**Total : 20 fichiers, ~280 lignes de code.**

---

## Prochaines etapes

1. Creer les fichiers dans l'ordre recommande
2. Tenter une premiere compilation avec `haxe` ou `openfl build`
3. Resoudre les erreurs de compilation une par une
4. Tester le jeu en mode standalone (sans serveur)
5. Affiner les stubs si necessaire (ex: implementation reelle de SecureSO avec persistance)
