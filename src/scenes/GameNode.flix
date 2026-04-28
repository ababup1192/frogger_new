// GameNode — ゲーム専用の sum type
// Scene[n] の n を具体化する enum。各ケースが Sprite2D を内包し、
// trait を match で委譲する。

pub enum GameNode with Eq, Order {
    case RotatingFrog(Sprite2D)
}

// ── CanvasItem 実装 ──

instance CanvasItem[GameNode] {
    pub def isVisible(n: GameNode): Bool = match n {
        case GameNode.RotatingFrog(s) => CanvasItem.isVisible(s)
    }
    pub def setVisible(v: Bool, n: GameNode): GameNode = match n {
        case GameNode.RotatingFrog(s) =>
            GameNode.RotatingFrog(CanvasItem.setVisible(v, s))
    }
    pub def getModulate(n: GameNode): Color = match n {
        case GameNode.RotatingFrog(s) => CanvasItem.getModulate(s)
    }
    pub def getZIndex(n: GameNode): Int32 = match n {
        case GameNode.RotatingFrog(s) => CanvasItem.getZIndex(s)
    }
    pub def setZIndex(z: Int32, n: GameNode): GameNode = match n {
        case GameNode.RotatingFrog(s) =>
            GameNode.RotatingFrog(CanvasItem.setZIndex(z, s))
    }
}

// ── Node2D 実装 ──

instance Node2D[GameNode] {
    pub def getPosition(n: GameNode): Vec2.Vec2 = match n {
        case GameNode.RotatingFrog(s) => Node2D.getPosition(s)
    }
    pub def setPosition(p: Vec2.Vec2, n: GameNode): GameNode = match n {
        case GameNode.RotatingFrog(s) =>
            GameNode.RotatingFrog(Node2D.setPosition(p, s))
    }
    pub def getRotation(n: GameNode): Float64 = match n {
        case GameNode.RotatingFrog(s) => Node2D.getRotation(s)
    }
    pub def setRotation(r: Float64, n: GameNode): GameNode = match n {
        case GameNode.RotatingFrog(s) =>
            GameNode.RotatingFrog(Node2D.setRotation(r, s))
    }
    pub def getScale(n: GameNode): Vec2.Vec2 = match n {
        case GameNode.RotatingFrog(s) => Node2D.getScale(s)
    }
    pub def setScale(sc: Vec2.Vec2, n: GameNode): GameNode = match n {
        case GameNode.RotatingFrog(s) =>
            GameNode.RotatingFrog(Node2D.setScale(sc, s))
    }
    pub def getSkew(n: GameNode): Float64 = match n {
        case GameNode.RotatingFrog(s) => Node2D.getSkew(s)
    }
    pub def setSkew(sk: Float64, n: GameNode): GameNode = match n {
        case GameNode.RotatingFrog(s) =>
            GameNode.RotatingFrog(Node2D.setSkew(sk, s))
    }
}

// ── Node 実装 ──

instance Node[GameNode] {
    pub def getSelf(name: NodeName, scene: Scene[GameNode]): Option[GameNode] =
        Scene.get(name, scene)

    pub def setSelf(name: NodeName, self: GameNode, scene: Scene[GameNode]): Scene[GameNode] =
        Scene.set(name, self, scene)

    redef process(delta: Float64, self: GameNode, _name: NodeName,
                    scene: Scene[GameNode]): (GameNode, Scene[GameNode]) =
        match self {
            case GameNode.RotatingFrog(sprite) =>
                let updated = sprite |> Node2D.rotate(delta);
                (GameNode.RotatingFrog(updated), scene)
        }
}

// ── Renderable 実装 ──

instance Engine.Renderable[GameNode] {
    pub def toDrawable(node: GameNode, globalPos: Vec2.Vec2): Engine.Drawable = match node {
        case GameNode.RotatingFrog(s) =>
            let rot = Node2D.getRotation(s);
            let pulse = 1.0f32 + 0.5f32
                * Vec2.sin32(Float64.truncateToFloat32(rot) * 2.0f32);
            let d = Sprite2D.toDrawableAt(s, globalPos);
            {scale = {x = d#scale#x * pulse, y = d#scale#y * pulse} | d}
    }
}

// ── ヘルパー ──

mod GameNode {
    /// GameNode から内部の Sprite2D を取り出す
    pub def getSprite(node: GameNode): Sprite2D = match node {
        case GameNode.RotatingFrog(s) => s
    }
}
