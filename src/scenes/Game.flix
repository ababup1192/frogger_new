// Game — ゲーム専用の sum type + シーン構築
//
// 構造:
//   frog (Area2D, invisible) → sprite (Sprite2D, renders)
//   turtle (Area2D, invisible) → sprite (Sprite2D, renders)
//
// Area2D はセンサーとして衝突検出のみ担当し、
// 子の Sprite2D がパルス描画と色変調を担当する。

pub enum GameNode with Eq, Order {
    case Frog(Area2D)
    case Turtle(Area2D)
    case SpriteNode(Sprite2D)
}

// ── Node 実装（毎フレームの振る舞い） ──

instance Node[GameNode] {
    redef process(delta: Float64, self: GameNode, path: NodePath,
                    scene: Scene[GameNode]): (GameNode, Scene[GameNode]) =
        match self {
            case GameNode.Frog(area) =>
                let (node, sc) = Game.processPulse(delta, frequency = 2.0, baseRadius = 40.0f32, rotSign = 1.0, area, path, scene);
                (GameNode.Frog(node), sc)
            case GameNode.Turtle(area) =>
                let (node, sc) = Game.processPulse(delta, frequency = 3.0, baseRadius = 40.0f32, rotSign = -1.0, area, path, scene);
                (GameNode.Turtle(node), sc)
            case _ =>
                (self, scene)
        }
}

// ── AreaHandler 実装（衝突応答） ──

instance AreaHandler[GameNode] {
    pub def onAreaEntered(selfPath: NodePath, self: GameNode,
                          _otherPath: NodePath, other: GameNode,
                          scene: Scene[GameNode]): Scene[GameNode] =
        match (self, other) {
            // カエルが亀と重なったら赤くする
            case (GameNode.Frog(_), GameNode.Turtle(_)) =>
                Scene.updateSpriteChild(selfPath, sprite ->
                    CanvasItem.setModulate({r = 1.0f32, g = 0.2f32, b = 0.2f32}, sprite),
                    scene)
            case _ => scene
        }
    redef onAreaExited(selfPath: NodePath, self: GameNode,
                       _otherPath: NodePath, other: GameNode,
                       scene: Scene[GameNode]): Scene[GameNode] =
        match (self, other) {
            // カエルが亀から離れたら白に戻す
            case (GameNode.Frog(_), GameNode.Turtle(_)) =>
                Scene.updateSpriteChild(selfPath, sprite ->
                    CanvasItem.setModulate({r = 1.0f32, g = 1.0f32, b = 1.0f32}, sprite),
                    scene)
            case _ => scene
        }
}

mod Game {
        /// カエルと亀を並べたシーンを構築する。
    pub def buildScene(): Scene[GameNode] =
        let shape = CollisionShape2D.CircleShape2D({radius = 40.0f32});
        Scene.empty()
            |> Scene.addNode("frog",
                GameNode.Frog(CanvasItem.setVisible(false, Area2D.make({x = 345.0f32, y = 300.0f32}, shape))))
            |> Scene.addChild("frog", "sprite",
                GameNode.SpriteNode(Sprite2D.make("frog", {x = 0.0f32, y = 0.0f32}, {x = 5.0f32, y = 5.0f32})))
            |> Scene.addNode("turtle",
                GameNode.Turtle(CanvasItem.setVisible(false, Area2D.make({x = 420.0f32, y = 300.0f32}, shape))))
            |> Scene.addChild("turtle", "sprite",
                GameNode.SpriteNode(Sprite2D.make("turtle", {x = 0.0f32, y = 0.0f32}, {x = 5.0f32, y = 5.0f32})))

    /// GameNode から内部の Area2D を取り出す（SpriteNode では呼ばないこと）
    pub def getArea(node: GameNode): Area2D = match node {
        case GameNode.Frog(area) => area
        case GameNode.Turtle(area) => area
        case GameNode.SpriteNode(_) => bug!("SpriteNode has no Area2D")
    }

    /// GameNode のテクスチャ名を返す
    pub def getTexture(node: GameNode): String = match node {
        case GameNode.Frog(_) => "frog"
        case GameNode.Turtle(_) => "turtle"
        case GameNode.SpriteNode(sprite) =>
            let Sprite2D.Sprite2D(r) = sprite;
            r#texture
    }

    /// 内部の Area2D に関数を適用し、再ラップして返す
    pub def mapArea(f: Area2D -> Area2D, node: GameNode): GameNode = match node {
        case GameNode.Frog(area) => GameNode.Frog(f(area))
        case GameNode.Turtle(area) => GameNode.Turtle(f(area))
        case GameNode.SpriteNode(_) => node
    }

    /// 毎フレームの拡大縮小 + 回転アニメーション。
    /// rotSign: 回転の向き（1.0 = 正方向、-1.0 = 逆方向）
    pub def processPulse(delta: Float64, frequency: {frequency = Float64},
                         baseRadius: {baseRadius = Float32}, rotSign: {rotSign = Float64},
                         area: Area2D, path: NodePath,
                         scene: Scene[GameNode]): (Area2D, Scene[GameNode]) =
        let Area2D.Area2D(r) = area;
        let time = r#rotation + delta;
        let sinValue = Vec2.sin32(Float64.truncateToFloat32(time * frequency#frequency));
        let pulseFactor = 1.0f32 + 0.5f32 * sinValue;
        let scaledRadius = baseRadius#baseRadius * pulseFactor;
        let updatedArea = Area2D.Area2D({
            rotation = time,
            collisionShape = Some(CollisionShape2D.CircleShape2D({radius = scaledRadius}))
            | r
        });
        let scale = 5.0f32 * pulseFactor;
        let rotation = rotSign#rotSign * time;
        let newScene = Scene.updateSpriteChild(path, sprite ->
            Node2D.setRotation(rotation,
                Node2D.setScale({x = scale, y = scale}, sprite)),
            scene);
        (updatedArea, newScene)


}

// ========================================================================
// ボイラープレート（trait 委譲）
// ========================================================================

instance CanvasItem[GameNode] {
    pub def isVisible(node: GameNode): Bool = match node {
        case GameNode.SpriteNode(sprite) => CanvasItem.isVisible(sprite)
        case _ => CanvasItem.isVisible(Game.getArea(node))
    }
    pub def setVisible(visible: Bool, node: GameNode): GameNode = match node {
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(CanvasItem.setVisible(visible, sprite))
        case _ => Game.mapArea(area -> CanvasItem.setVisible(visible, area), node)
    }
    pub def getModulate(node: GameNode): Color = match node {
        case GameNode.SpriteNode(sprite) => CanvasItem.getModulate(sprite)
        case _ => CanvasItem.getModulate(Game.getArea(node))
    }
    pub def setModulate(color: Color, node: GameNode): GameNode = match node {
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(CanvasItem.setModulate(color, sprite))
        case _ => Game.mapArea(area -> CanvasItem.setModulate(color, area), node)
    }
    pub def getZIndex(node: GameNode): Int32 = match node {
        case GameNode.SpriteNode(sprite) => CanvasItem.getZIndex(sprite)
        case _ => CanvasItem.getZIndex(Game.getArea(node))
    }
    pub def setZIndex(zIndex: Int32, node: GameNode): GameNode = match node {
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(CanvasItem.setZIndex(zIndex, sprite))
        case _ => Game.mapArea(area -> CanvasItem.setZIndex(zIndex, area), node)
    }
}

instance Node2D[GameNode] {
    pub def getPosition(node: GameNode): Vec2.Vec2 = match node {
        case GameNode.SpriteNode(sprite) => Node2D.getPosition(sprite)
        case _ => Node2D.getPosition(Game.getArea(node))
    }
    pub def setPosition(position: Vec2.Vec2, node: GameNode): GameNode = match node {
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(Node2D.setPosition(position, sprite))
        case _ => Game.mapArea(area -> Node2D.setPosition(position, area), node)
    }
    pub def getRotation(node: GameNode): Float64 = match node {
        case GameNode.SpriteNode(sprite) => Node2D.getRotation(sprite)
        case _ => Node2D.getRotation(Game.getArea(node))
    }
    pub def setRotation(rotation: Float64, node: GameNode): GameNode = match node {
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(Node2D.setRotation(rotation, sprite))
        case _ => Game.mapArea(area -> Node2D.setRotation(rotation, area), node)
    }
    pub def getScale(node: GameNode): Vec2.Vec2 = match node {
        case GameNode.SpriteNode(sprite) => Node2D.getScale(sprite)
        case _ => Node2D.getScale(Game.getArea(node))
    }
    pub def setScale(scale: Vec2.Vec2, node: GameNode): GameNode = match node {
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(Node2D.setScale(scale, sprite))
        case _ => Game.mapArea(area -> Node2D.setScale(scale, area), node)
    }
    pub def getSkew(node: GameNode): Float64 = match node {
        case GameNode.SpriteNode(sprite) => Node2D.getSkew(sprite)
        case _ => Node2D.getSkew(Game.getArea(node))
    }
    pub def setSkew(skew: Float64, node: GameNode): GameNode = match node {
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(Node2D.setSkew(skew, sprite))
        case _ => Game.mapArea(area -> Node2D.setSkew(skew, area), node)
    }
}

instance CollisionObject2D[GameNode] {
    pub def getCollisionShape(node: GameNode): Option[CollisionShape2D] = match node {
        case GameNode.SpriteNode(_) => None
        case _ => CollisionObject2D.getCollisionShape(Game.getArea(node))
    }
    pub def isMonitoring(node: GameNode): Bool = match node {
        case GameNode.SpriteNode(_) => false
        case _ => CollisionObject2D.isMonitoring(Game.getArea(node))
    }
    pub def isMonitorable(node: GameNode): Bool = match node {
        case GameNode.SpriteNode(_) => false
        case _ => CollisionObject2D.isMonitorable(Game.getArea(node))
    }
    redef getCollisionPriority(node: GameNode): Int32 = match node {
        case GameNode.SpriteNode(_) => 0
        case _ => CollisionObject2D.getCollisionPriority(Game.getArea(node))
    }
}

instance Engine.Renderable[GameNode] {
    pub def toDrawable(node: GameNode, globalPos: Vec2.Vec2): Engine.Drawable =
        Scene.toDrawable(Game.getTexture(node), node, globalPos)
}
