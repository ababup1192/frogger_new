---
name: scene-pattern
description: "GameNodeとシーン構築の設計パターン。enum設計・buildScene・trait委譲・テスト構成の規約 - 新しいゲームを作るとき、GameNodeを拡張するとき"
user-invocable: false
---

# GameNode + Scene 設計パターン

## 対象ファイル

| ファイル | 役割 |
|---|---|
| `src/scenes/Game.flix` | GameNode enum + trait instance + buildScene + ゲームロジック |
| `test/scenes/TestGame.flix` | テスト |
| `src/Main.flix` | メインループ（GameEngine 呼び出し） |

## Game.flix の構成要素と順序

### 1. GameNode enum

ゲームに登場するノード種別を定義する。`Eq`, `Order` を derive する。

```flix
pub enum GameNode with Eq, Order {
    case Frog(Area2D)
    case Turtle(Area2D)
    case SpriteNode(Sprite2D)
}
```

設計方針:
- 衝突を持つノードは `Area2D` をラップする
- 描画専用ノードは `SpriteNode(Sprite2D)` で統一する
- バリアントが多くなる場合は `Actor({kind = ActorKind, area = Area2D, ...})` でデータ駆動にする（`/engine-guide` 参照）

### 2. Node instance（ライフサイクル）

```flix
instance Node[GameNode] {
    redef process(delta, self, path, scene) =
        match self {
            case GameNode.Frog(area) => ...
            case GameNode.Turtle(area) => ...
            case _ => (self, scene)
        }
}
```

- `process` は `(GameNode, Scene[GameNode])` を返す — 自分自身と Scene の両方を更新できる
- `SpriteNode` 等、振る舞いのないバリアントは `case _ => (self, scene)`

### 3. AreaHandler instance（衝突応答）

```flix
instance AreaHandler[GameNode] {
    pub def onAreaEntered(selfPath, self, _otherPath, other, scene) =
        match (self, other) {
            case (GameNode.Frog(_), GameNode.Turtle(_)) => ...
            case _ => scene
        }
    redef onAreaExited(selfPath, self, _otherPath, other, scene) =
        match (self, other) {
            case (GameNode.Frog(_), GameNode.Turtle(_)) => ...
            case _ => scene
        }
}
```

- `(self, other)` のペアで match して応答を決める
- `onAreaExited` はデフォルトが何もしない。必要な場合のみ `redef`

### 4. mod Game — ゲームロジック

```flix
mod Game {
    /// シーン構築
    pub def buildScene(): Scene[GameNode] =
        Scene.empty()
            |> Scene.addNode("frog", ...)
            |> Scene.addChild("frog", "sprite", ...)

    /// ヘルパー: 内部 Area2D の取り出し
    pub def getArea(node: GameNode): Area2D = ...

    /// ヘルパー: テクスチャ名
    pub def getTexture(node: GameNode): String = ...

    /// ヘルパー: Area2D への関数適用
    pub def mapArea(f: Area2D -> Area2D, node: GameNode): GameNode = ...

    /// ゲーム固有ロジック
    pub def processPulse(...): ... = ...
}
```

推奨ヘルパー:
- `getArea` — 内部 Area2D を取り出す（`SpriteNode` では `bug!`）
- `mapArea` — 内部 Area2D に関数を適用して再ラップ
- `getTexture` — Renderable 実装用

### 5. trait 委譲ボイラープレート

`CanvasItem`, `Node2D`, `CollisionObject2D`, `Engine.Renderable` の instance。
全て `match` で内部型に委譲する。

```flix
instance CanvasItem[GameNode] {
    pub def isVisible(node: GameNode): Bool = match node {
        case GameNode.SpriteNode(sprite) => CanvasItem.isVisible(sprite)
        case _ => CanvasItem.isVisible(Game.getArea(node))
    }
    // ...
}
```

- `SpriteNode` と それ以外（Area2D 系）の2分岐が基本
- `CollisionObject2D` では `SpriteNode` は `None` / `false` / `0` を返す

## buildScene のパターン

```flix
pub def buildScene(): Scene[GameNode] =
    let shape = CollisionShape2D.CircleShape2D({radius = 40.0f32});
    Scene.empty()
        // ルートノード: Area2D（invisible、衝突検出用）
        |> Scene.addNode("frog",
            GameNode.Frog(CanvasItem.setVisible(false,
                Area2D.make({x = 345.0f32, y = 300.0f32}, shape))))
        // 子ノード: Sprite2D（描画用）
        |> Scene.addChild("frog", "sprite",
            GameNode.SpriteNode(Sprite2D.make("frog",
                {x = 0.0f32, y = 0.0f32}, {x = 5.0f32, y = 5.0f32})))
```

規約:
- Area2D ノードは `visible = false` にする（センサー専用）
- 子の Sprite2D が描画を担当する
- 座標はローカル座標（親からの相対位置）
- `|>` パイプでチェーンする

## Main.flix のパターン

```flix
def main(): Unit \ IO =
    // ...
    LwjglLayer.withLwjgl(config, () -> {
        let scene = Game.buildScene() |> Scene.readyAll;
        gameLoop(Set.empty(), scene)
    })

def gameLoop(prevOverlaps: OverlapPairSet, scene: Scene[GameNode]): Unit \ Engine.Game =
    if (Engine.Game.shouldClose()) ()
    else {
        let delta = Engine.Game.getDeltaTime();
        let (newScene, newOverlaps) =
            GameEngine.updateWithAreaHandler(delta, false, prevOverlaps, scene);
        gameLoop(newOverlaps, newScene)
    }
```

- `Scene.readyAll` を忘れないこと
- `prevOverlaps` は `Set.empty()` で初期化

## テスト構成

### シーン構築テスト（必須）

`buildScene` の結果が期待通りの構造を持つことを検証:

```flix
@Test
def testBuildSceneNodeCount(): Bool =
    let scene = Game.buildScene();
    Scene.nodeCount(scene) == 4  // frog + sprite + turtle + sprite

@Test
def testBuildSceneFrogExists(): Bool =
    let scene = Game.buildScene();
    Option.isSome(Scene.get("frog", scene))
```

### 振る舞いテスト

純粋関数のロジックを個別にテスト:

```flix
@Test
def testProcessUpdatesRotation(): Bool =
    let scene = Game.buildScene();
    let processed = Scene.processAll(0.016, false, scene);
    // 回転が更新されていることを検証
    ...
```

### 衝突応答テスト

AreaHandler のロジックを直接テスト:

```flix
@Test
def testFrogTurtleCollisionChangesColor(): Bool =
    let scene = Game.buildScene();
    let frog = ...; let turtle = ...;
    let result = AreaHandler.onAreaEntered("frog" :: Nil, frog, "turtle" :: Nil, turtle, scene);
    // sprite の modulate が赤になっていることを検証
    ...
```
