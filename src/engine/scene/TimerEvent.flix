/// タイマータイムアウトイベントの検出と応答（Godot Timer.timeout シグナル準拠）
///
/// AreaEvent / AreaHandler パターンに倣い、TimerHandler トレイトで
/// タイムアウト時のイベント駆動を実現する。
///
/// 使い方:
///   1. TimerHandler[n] を実装し onTimeout でタイムアウト応答を記述
///   2. handleTimeouts(scene) をゲームループで呼び出す

pub mod TimerEvent {

    /// タイマータイムアウトに応答するトレイト
    pub trait TimerHandler[n] {
        /// タイマーがタイムアウトしたとき呼ばれる。
        /// timerPath: タイマーノードのパス
        /// timer: タイマーノードの実体
        /// scene: 現在のシーン
        pub def onTimeout(timerPath: NodePath, timer: n, scene: Scene[n]): Scene[n] = scene
    }

    /// timedOut=true のノードパスを収集する
    pub def detectTimeoutPaths(scene: Scene[n]): List[NodePath] with Node[n] =
        let paths = Scene.preorderPaths(scene);
        List.filterMap(path ->
            match Scene.getAt(path, scene) {
                case Some(node) =>
                    if (Node.isTimedOut(node)) Some(path)
                    else None
                case None => None
            }, paths)

    /// タイムアウトを処理し、フラグをクリアする
    /// 1. detectTimeoutPaths で対象パスを収集
    /// 2. 各パスに対して TimerHandler.onTimeout を呼び出し
    /// 3. 各パスの clearTimedOut を呼び出してフラグをリセット
    pub def handleTimeouts(scene: Scene[n]): Scene[n] with Node[n], TimerHandler[n] =
        let timedOutPaths = detectTimeoutPaths(scene);
        // onTimeout を呼び出し
        let sceneAfterHandlers = List.foldLeft((sc, path) ->
            match Scene.getAt(path, sc) {
                case Some(node) => TimerHandler.onTimeout(path, node, sc)
                case None => sc
            },
            scene,
            timedOutPaths);
        // timedOut フラグをクリア
        List.foldLeft((sc, path) ->
            Scene.mapAt(path, node -> Node.clearTimedOut(node), sc),
            sceneAfterHandlers,
            timedOutPaths)
}
