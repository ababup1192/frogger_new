// SampleScene — 回転+パルスする Sprite2D のサンプルシーン

mod SampleScene {
    pub def buildScene(): Scene[GameNode] =
        let sprite = Sprite2D.make("frog", {x = 400.0f32, y = 300.0f32}, {x = 10.0f32, y = 10.0f32});
        Scene.empty() |> Scene.addNode("frog", GameNode.RotatingFrog(sprite))
}
