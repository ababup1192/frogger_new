// GameEngine — 汎用描画パイプライン
// Scene[n] の n がジェネリクスなので、GameNode に依存しない。

mod GameEngine {

    /// 1 フレーム分の更新: processAll → render
    pub def update(delta: Float32, paused: Bool, scene: Scene[n]): Scene[n] \ Engine.Game
            with Node[n], Node2D[n], Engine.Renderable[n] =
        let processedScene = Scene.processAll(Float32.toFloat64(delta), paused, scene);
        render(processedScene);
        processedScene

    /// 1 フレーム分の更新（Area2D 衝突検出付き）:
    /// processAndEmit → OnAreaEvent → render
    ///
    /// OnAreaEvent ハンドラは呼び出し元で提供する。
    pub def updateWithAreaEvents(delta: Float32, paused: Bool, scene: Scene[n]): Scene[n] \ {Engine.Game, OnAreaEvent}
            with Node[n], CollisionObject2D[n], Engine.Renderable[n] =
        let processedScene = AreaEvent.processAndEmit(Float32.toFloat64(delta), paused, scene);
        render(processedScene);
        processedScene

    /// 1 フレーム分の更新（AreaHandler 方式）:
    /// processAndEmitHandled → render
    ///
    /// OnAreaEvent ハンドラ不要。ノード型の AreaHandler instance で衝突応答する。
    /// prevOverlaps に前フレームのペアセットを渡すと、離脱イベントも発火される。
    pub def updateWithAreaHandler(delta: Float32, paused: Bool, prevOverlaps: OverlapPairSet,
                                  scene: Scene[n]): (Scene[n], OverlapPairSet) \ Engine.Game
            with Node[n], CollisionObject2D[n], AreaHandler[n], Engine.Renderable[n] =
        let (processedScene, currentOverlaps) = AreaEvent.processAndEmitHandled(Float32.toFloat64(delta), paused, prevOverlaps, scene);
        render(processedScene);
        (processedScene, currentOverlaps)

    /// 描画: Scene.toDrawables で Drawable リストを取得し、描画する
    pub def render(scene: Scene[n]): Unit \ Engine.Game
            with Node2D[n], Engine.Renderable[n] =
        Scene.toDrawables(scene) |> Engine.Game.render
}
