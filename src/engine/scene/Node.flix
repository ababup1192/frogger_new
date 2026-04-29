/// シーンツリーの基本ノード（Godot Node 準拠）
/// see: https://docs.godotengine.org/en/stable/classes/class_node.html
///
/// ライフサイクル:
///   addNode → ready → [毎フレーム] process(delta)
///
/// 全メソッドにデフォルト実装があり、必要なものだけオーバーライドすればよい。
pub trait Node[n] {

    // ── Scene アクセス ──

    /// シーンからパスで自分を取得する
    pub def getSelf(path: NodePath, scene: Scene[n]): Option[n] =
            Scene.getAt(path, scene)

    /// シーンにパスで自分の状態を書き戻す
    pub def setSelf(path: NodePath, self: n, scene: Scene[n]): Scene[n] =
            Scene.setAt(path, self, scene)

    // ── ライフサイクル ──

    /// シーン構築後に一度だけ呼ばれる初期化コールバック
    /// 他ノードへの参照取得や初期状態の計算に使う
    pub def ready(self: n, _path: NodePath, scene: Scene[n]): (n, Scene[n]) =
            (self, scene)

    /// 毎フレーム呼ばれる更新コールバック
    /// delta: 前フレームからの経過秒数（Float64）
    pub def process(_delta: Float64, self: n, _path: NodePath, scene: Scene[n]): (n, Scene[n]) =
            (self, scene)

    // ── ポーズ制御 ──

    /// このノードの ProcessMode を返す（デフォルト: Pausable）
    /// Scene.processAll がポーズ中に呼ぶかどうかの判定に使われる
    pub def getProcessMode(_self: n): ProcessMode =
            ProcessMode.Pausable
}
