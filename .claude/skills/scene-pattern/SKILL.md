---
name: scene-pattern
description: "Sceneモジュールの設計パターン。JSON宣言・エフェクト分離・Config抽出・テスト構成の規約 - 新しいSceneを作るとき、既存Sceneをリファクタするとき"
user-invocable: false
---

# Scene モジュール設計パターン

## 対象ファイル

- `src/scenes/**/*.flix`
- `src/scenes/**/*.scene.json`
- `src/SceneLoader.flix`

## ファイル構成

| ファイル | 役割 |
|---|---|
| `src/scenes/<Name>.scene.json` | ノードツリーの構造とパラメータを宣言 |
| `src/scenes/<Name>.flix` | 振る舞いのロジック |
| `test/Test<Name>.flix` | テスト |

## scene.json — 構造の宣言

ノードツリーをJSONで定義する。コードには振る舞いだけを書き、構造やパラメータはJSONに寄せる。

使えるノードタイプ: `CharacterBody2D`, `AnimatedSprite2D`, `Area2D`, `RectShape2D`

## Flix モジュール — 構成要素と順序

### 1. Child enum + SceneChild instance

子ノード名を型安全に参照する。文字列のハードコードを避ける。

```flix
pub enum Child with Eq, ToString { case Sprite; case Hitbox }
instance SceneTree.SceneChild[Child] {
    pub def sceneName(_c: Child): String = <Name>.nodeName()
    pub def childName(c: Child): String = match c { ... }
}
```

### 2. 定数

ノード名・初期位置など、プログラム側が正(source of truth)となる値を定数として公開する。

### 3. Config（必要に応じて）

実行中にノードから読み出すパラメータを type alias にまとめ、`forM` + アクセサで抽出する。

- **純粋関数にする（`Fs.FileRead` をつけない）**
- シーンツリー上の既存ノードからアクセサで取得する

```flix
pub def loadConfig(scene: SceneTree.Node): Config =
    let config = forM (
        node <- SceneTree.findNode(nodeName(), scene);
        data <- SceneTree.characterBodyData(node)
    ) yield { ... };
    match config {
        case Some(c) => c
        case None    => bug!("...")
    }
```

### 4. build 関数 — Fs.FileRead はここだけ

```flix
pub def build<Name>(): SceneTree.Node \ Fs.FileRead =
    SceneLoader.loadScene("src/scenes/<Name>.scene.json")
```

### 5. 振る舞い — すべて純粋関数

入力処理・状態更新・クエリなど。`loadConfig(scene)` でパラメータを取得する。

## 親シーンへの組み込み

- 親シーンの `Child` enum にケースを追加
- `SceneChild` instance の `childName` にマッピングを追加
- `buildInitialScene` の子リストに `build*()` を追加

## テスト

### JSON一括検証テスト（必須）

`build*()` の結果を `forM` で全パラメータ一括検証する。プログラム側の定数との一致もここで確認。

```flix
@Test
def testBuild<Name>MatchesJson(): Unit \ {Assert, Fs.FileRead} =
    let node = <Name>.build<Name>();
    let result = forM (
        ... <- アクセサでデータ抽出
    ) yield {
        Assert.assertEq(...)
    };
    match result {
        case Some(_) => ()
        case None    => bug!("Node structure does not match expected JSON layout")
    }
```

### 振る舞いテスト

純粋関数のロジックを個別にテストする。

## エフェクト分離の原則

`Fs.FileRead` は `build*` 関数だけが持つ。それ以外はシーンノードを受け取る純粋関数にして、エフェクトの伝播を防ぐ。
