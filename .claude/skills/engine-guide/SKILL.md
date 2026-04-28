---
name: engine-guide
description: "ゲームエンジン（Scene, Game, Node）のコードを書く前に参照するお作法ガイド。責務分担、Nodeの使い分け、イベント検知の活用を含む - Scene、Game、Nodeに関するコードを書くとき、ゲームエンジンを拡張するとき"
user-invocable: false
---

# ゲームエンジン開発のお作法

ゲームエンジン関連のコード（Scene, Game, Node）を書く・修正する前に参照してください。

## 対象ファイル

- `src/scene/**/*.flix`
- `src/Game.flix`
- `src/SceneTree.flix`
- `src/NodeBuilders.flix`
- `src/Engine.flix`

## コーディングスタイル

- 無駄な実装（特に座標系）をしないように、状況に適した Node の種類を選び、使うこと
- `SceneTree.Node.MkNode` は手動で Node を作るので最終手段。既存の Node をなるべく使う
- 実装が複雑になっている場合は、ゲームエンジンの拡張を検討し、提案すること
- イベントの検知を有効活用する — `OnCollision`, `OnTimeout` など便利な Algebraic Effect がある
- イベントのノードは、`name` を `SceneTree.childName` などで必ずフィルタすること

## Game ファイルの責務

- ゲーム全体の状態定義（`GameState` 等）とメインループを持つ
- 入力のポーリング・エッジ検出を行い、Scene に渡す
- Scene の構築・入力適用・フレーム更新を呼び出す **オーケストレーター**
- ゲーム固有のロジック（移動計算等）は Scene に委譲する

## Scene ファイルの責務

- シーンが管理する子ノードを `SceneTree.SceneChild` で定義する
- シーンの初期構築（`buildInitialScene` 相当）を提供する
- 親子関係がある Scene では、責務を決め、親は子の呼び出し委譲をするオーケストレーターに徹する

## 手順

1. まず既存の Scene / Game ファイルを読んで、パターンを把握する
2. 上記の責務分担に従って、変更箇所を特定する
3. 使える Node の種類を確認してから実装する
