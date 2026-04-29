def main(): Unit \ IO =
    if (Engine.ensureMainThread()) ()
    else {
        let config: Engine.EngineConfig = {
            screenWidth = 800,
            screenHeight = 600,
            title = "Area2D Overlap Demo",
            textureManifest =
                {name = "frog", path = "textures/FroggerIdle.png", hasAlpha = true} ::
                {name = "turtle", path = "textures/Turtle_01.png", hasAlpha = true} :: Nil,
            clearColor = {r = 0.2f32, g = 0.3f32, b = 0.3f32}
        };
        LwjglLayer.withLwjgl(config, () -> {
            let scene = Game.buildScene() |> Scene.readyAll;
            gameLoop(Set.empty(), scene)
        })
    }

/// メインループ: AreaHandler 方式で更新。衝突応答は GameNode 側に定義済み。
def gameLoop(prevOverlaps: OverlapPairSet, scene: Scene[GameNode]): Unit \ Engine.Game =
    if (Engine.Game.shouldClose()) ()
    else {
        let delta = Engine.Game.getDeltaTime();
        let (newScene, newOverlaps) = GameEngine.updateWithAreaHandler(delta, false, prevOverlaps, scene);
        gameLoop(newOverlaps, newScene)
    }
