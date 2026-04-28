// GameEngine — 汎用描画パイプライン
// Scene[n] の n がジェネリクスなので、GameNode に依存しない。

mod GameEngine {

    /// 1 フレーム分の更新: processAll → render
    pub def update(delta: Float32, paused: Bool, scene: Scene[n]): Scene[n] \ Engine.Game
            with Node[n], Node2D[n], Engine.Renderable[n] =
        let processedScene = Scene.processAll(Float32.toFloat64(delta), paused, scene);
        render(processedScene);
        processedScene

    /// 描画: globalPosition で座標解決、zIndex でソート、Renderable で Drawable 変換
    pub def render(scene: Scene[n]): Unit \ Engine.Game
            with Node2D[n], Order[n], Engine.Renderable[n] =
        let drawables =
            Scene.preorderNames(scene)
            |> List.filterMap(name ->
                match Scene.get(name, scene) {
                    case None => None
                    case Some(node) =>
                        if (CanvasItem.isVisible(node)) {
                            let gPos = Scene.globalPosition(name, scene);
                            Some(Engine.Renderable.toDrawable(node, gPos))
                        } else None
                }
            )
            |> List.sortBy(d -> d#zIndex);
        Engine.Game.render(drawables)
}
