/// シーンツリーの基本ノード（Godot Node 準拠）
/// see: https://docs.godotengine.org/en/stable/classes/class_node.html
///
/// ライフサイクル:
///   addNode → ready → [毎フレーム] process(delta)
///
/// 全メソッドにデフォルト実装があり、必要なものだけオーバーライドすればよい。
/// 型パラメータ s はゲーム固有の状態を表す。
/// エンジンノード (EngineNode) は SceneEntry 内に別途保持される。
pub trait Node[s] {

    // ── ライフサイクル ──

    /// シーン構築後に一度だけ呼ばれる初期化コールバック
    /// 他ノードへの参照取得や初期状態の計算に使う
    pub def ready(state: s, engineNode: EngineNode, _path: NodePath, scene: Scene[s]): (s, EngineNode, Scene[s]) =
            (state, engineNode, scene)

    /// 毎フレーム呼ばれる更新コールバック
    /// delta: 前フレームからの経過秒数（Float64）
    pub def process(_delta: Float64, state: s, engineNode: EngineNode, _path: NodePath, scene: Scene[s]): (s, EngineNode, Scene[s]) =
            (state, engineNode, scene)

    // ── タイムアウト検出 ──

    /// timeout イベントが保留中か
    pub def isTimedOut(_state: s): Bool = false

    /// timeout フラグをクリア
    pub def clearTimedOut(state: s): s = state

    // ── ポーズ制御 ──

    /// このノードの ProcessMode を返す（デフォルト: Pausable）
    /// Scene.processAll がポーズ中に呼ぶかどうかの判定に使われる
    pub def getProcessMode(_state: s): ProcessMode =
            ProcessMode.Pausable
}
