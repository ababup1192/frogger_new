/// 衝突応答トレイト（ノード主導のエリアイベント処理）
///
/// OnAreaEvent エフェクトの代替。外部ハンドラではなく、
/// ノード型自身が衝突応答ロジックを持つ。

pub trait AreaHandler[n] {

    /// 自分(self)のエリアに他ノード(other)が侵入したとき呼ばれる。
    /// Scene を書き換えて返す。
    ///
    /// selfPath: 自分のパス
    /// self: 自分の実体
    /// otherPath: 相手のパス
    /// other: 相手の実体
    /// scene: 現在のシーン
    pub def onAreaEntered(
        selfPath: NodePath,
        self: n,
        otherPath: NodePath,
        other: n,
        scene: Scene[n]
    ): Scene[n]

    /// 自分(self)のエリアから他ノード(other)が離脱したとき呼ばれる。
    /// デフォルトでは何もしない。
    pub def onAreaExited(
        _selfPath: NodePath,
        _self: n,
        _otherPath: NodePath,
        _other: n,
        scene: Scene[n]
    ): Scene[n] = scene
}
