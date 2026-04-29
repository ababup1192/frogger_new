---
name: engine-guide
description: "ゲームエンジン（Scene[n], GameNode, GameEngine）のコードを書く前に参照するお作法ガイド。GameNode設計、trait実装、衝突応答、動的スポーンを含む"
user-invocable: false
---

# ゲームエンジン開発のお作法

## アーキテクチャ

```
エンジン層（汎用・変更不要）        ゲーム層（開発者が書く）
─────────────────────────       ─────────────────────
Scene[n]  — ツリー管理            GameNode — enum 定義
GameEngine — 更新パイプライン       trait instance — 委譲
AreaEvent — 衝突検出              buildScene() — 構築
AreaHandler — 衝突応答 trait       process / onAreaEntered — 振る舞い
```

エンジン層は `n` のジェネリクスで動く。開発者は **GameNode の設計と trait instance** だけを行う。

## 対象ファイル

- ゲーム層: `src/scenes/Game.flix`, `test/scenes/TestGame.flix`, `src/Main.flix`
- エンジン層: `src/engine/**/*.flix`（拡張時のみ）

## GameNode 設計

### 基本形: バリアントごとに内部型をラップ

衝突を持つノードは `Area2D`、描画専用は `SpriteNode(Sprite2D)`。
具体例は `Game.flix` の `GameNode` enum を参照。

### スケールする形: データ駆動

バリアントが増える場合は `Actor({kind = ActorKind, area = Area2D, ...})` に統一する。

- trait ボイラープレートが **2分岐で固定**（`Actor` vs `SpriteNode`）
- 新しい種別は `ActorKind` に1行追加するだけ
- 種別固有データは `ActorKind` のバリアントに持たせる

## Game.flix の構成順序

1. **GameNode enum** — `with Eq, Order` を derive
2. **Node instance** — `process` で毎フレーム更新。振る舞いのないバリアントは `case _ => (self, scene)`
3. **AreaHandler instance** — `(self, other)` ペアで match。`onAreaExited` は必要時のみ `redef`
4. **mod Game** — `buildScene`, ヘルパー(`getArea`, `mapArea`, `getTexture`), ゲーム固有ロジック
5. **trait 委譲ボイラープレート** — `CanvasItem`, `Node2D`, `CollisionObject2D`, `Renderable`

## 設計ルール

### trait 委譲

- `SpriteNode` と Area2D 系の **2分岐** が基本
- ヘルパー関数 `getArea` / `mapArea` で簡潔にする
- `CollisionObject2D` では `SpriteNode` は `None` / `false` / `0` を返す

### シーン構築 (buildScene)

- `Scene.empty() |> Scene.addNode(...) |> Scene.addChild(...)` のパイプチェーン
- Area2D ノードは `visible = false`（センサー専用）、子の Sprite2D が描画担当
- 座標はローカル座標（親からの相対位置）

### 衝突応答

- **AreaHandler 方式（推奨）**: ノード型自身が衝突ロジックを持つ。`GameEngine.updateWithAreaHandler` で使う
- **OnAreaEvent 方式**: 同じノード型で場面ごとに応答を変えたい場合のみ

### 動的スポーン / デスポーン

- `process` や `onAreaEntered` 内で `Scene.addNode` / `Scene.removeAt` を呼ぶ
- 同一フレームで追加したノードの `process` は **次フレームから**
- 走査中の削除は安全（`getAt` が `None` を返す）
- 名前はユニークにすること（カウンタ等を使う）

### メインループ (Main.flix)

- `Scene.readyAll` を初期化で忘れないこと
- `prevOverlaps` は `Set.empty()` で初期化し、ループで持ち回す

## やってはいけないこと

- エンジン層に `GameNode` 固有のロジックを入れない
- `bug!()` を到達不能パス以外に使わない — `match` の網羅性に任せる

## テスト

- **構築テスト（必須）**: `buildScene` の結果のノード数・存在確認
- **振る舞いテスト**: `Scene.processAll` 後の状態検証
- **衝突応答テスト**: `AreaHandler.onAreaEntered` を直接呼び出して検証
