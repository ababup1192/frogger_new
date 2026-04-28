def main(): Unit \ IO =
    if (Engine.ensureMainThread()) ()
    else {
        let config: Engine.EngineConfig = {
            screenWidth = 800,
            screenHeight = 600,
            title = "Sprite2D Sample",
            textureManifest =
                {name = "frog", path = "textures/FroggerIdle.png", hasAlpha = true} :: Nil,
            clearColor = {r = 0.2f32, g = 0.3f32, b = 0.3f32}
        };
        LwjglLayer.withLwjgl(config, () -> {
            let scene = SampleScene.buildScene() |> Scene.readyAll;
            gameLoop(scene)
        })
    }

def gameLoop(scene: Scene[GameNode]): Unit \ Engine.Game =
    if (Engine.Game.shouldClose()) ()
    else {
        GameEngine.update(Engine.Game.getDeltaTime(), false, scene) 
        |> gameLoop
    }
