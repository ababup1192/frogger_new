/// エンジンノード — 全ビルトインノード型を統一的に扱うための sum type
///
/// Scene[s] の各 SceneEntry は EngineNode（描画・物理・衝突）と
/// ゲーム固有の状態 s を分離して保持する。
/// CanvasItem / Node2D / CollisionObject2D / Renderable は
/// EngineNode に対して一度だけ実装され、ゲーム側のボイラープレートを排除する。
pub enum EngineNode {
    /// 静的スプライト（背景・車両スプライト・丸太スプライト用）
    case Sprite2DNode(Sprite2D)
    /// 衝突エリア（Area2D ベースの当たり判定）
    case Area2DNode(Area2D)
    /// キャラクターボディ（プレイヤー等の物理ボディ）
    case Body2DNode(CharacterBody2D)
    /// アニメーション付きスプライト
    case AnimSprite2DNode(AnimatedSprite2D)
    /// テキストラベル（HUD 表示）
    case Label2DNode(Label2D)
    /// 位置マーカー（スポーン地点・参照点）
    case Marker2DNode(Marker2D)
}

mod EngineNode {

    /// エンジンレベルの毎フレーム処理
    /// AnimatedSprite2D のフレーム送りを自動で行う。
    pub def engineProcess(delta: Float32, node: EngineNode): EngineNode = match node {
        case EngineNode.AnimSprite2DNode(sprite) =>
            EngineNode.AnimSprite2DNode(AnimatedSprite2D.advanceFrame(delta, sprite))
        case _ => node
    }

    /// Sprite2D を Drawable に変換する
    /// centered=false（背景）の場合は scale を uvScale にしてタイリングする
    pub def spriteToDrawable(sprite: Sprite2D, globalPos: Vec2.Vec2): Engine.Drawable =
        let Sprite2D.Sprite2D(r) = sprite;
        let uvSc: Vec2.Vec2 = if (r#centered) {x = 1.0f32, y = 1.0f32}
                               else r#scale;
        {
            texture = r#texture,
            position = globalPos,
            scale = r#scale,
            rotation = Float64.truncateToFloat32(r#rotation),
            color = r#modulate,
            centered = r#centered,
            uvOffset = {x = 0.0f32, y = 0.0f32},
            uvScale = uvSc,
            zIndex = r#zIndex
        }

    /// AnimatedSprite2D を Drawable に変換する
    pub def animSpriteToDrawable(sprite: AnimatedSprite2D, globalPos: Vec2.Vec2): Engine.Drawable =
        let AnimatedSprite2D.AnimatedSprite2D(r) = sprite;
        {
            texture = AnimatedSprite2D.currentTexture(sprite),
            position = globalPos,
            scale = r#scale,
            rotation = Float64.truncateToFloat32(r#rotation),
            color = r#modulate,
            centered = r#centered,
            uvOffset = {x = 0.0f32, y = 0.0f32},
            uvScale = {x = 1.0f32, y = 1.0f32},
            zIndex = r#zIndex
        }

    /// EngineNode からフォールバック用 Drawable を組み立てる（デバッグ表示用）
    pub def fallbackDrawable(node: EngineNode, globalPos: Vec2.Vec2): Engine.Drawable =
        {
            texture = "white",
            position = globalPos,
            scale = Node2D.getScale(node),
            rotation = Float64.truncateToFloat32(Node2D.getRotation(node)),
            color = CanvasItem.getModulate(node),
            centered = true,
            uvOffset = {x = 0.0f32, y = 0.0f32},
            uvScale = {x = 1.0f32, y = 1.0f32},
            zIndex = CanvasItem.getZIndex(node)
        }
}

// ── CanvasItem 実装 ──

instance CanvasItem[EngineNode] {
    pub def isVisible(node: EngineNode): Bool = match node {
        case EngineNode.Sprite2DNode(sprite) => CanvasItem.isVisible(sprite)
        case EngineNode.Area2DNode(area) => CanvasItem.isVisible(area)
        case EngineNode.Body2DNode(body) => CanvasItem.isVisible(body)
        case EngineNode.AnimSprite2DNode(sprite) => CanvasItem.isVisible(sprite)
        case EngineNode.Label2DNode(label) => CanvasItem.isVisible(label)
        case EngineNode.Marker2DNode(marker) => CanvasItem.isVisible(marker)
    }
    pub def setVisible(visible: Bool, node: EngineNode): EngineNode = match node {
        case EngineNode.Sprite2DNode(sprite) => EngineNode.Sprite2DNode(CanvasItem.setVisible(visible, sprite))
        case EngineNode.Area2DNode(area) => EngineNode.Area2DNode(CanvasItem.setVisible(visible, area))
        case EngineNode.Body2DNode(body) => EngineNode.Body2DNode(CanvasItem.setVisible(visible, body))
        case EngineNode.AnimSprite2DNode(sprite) => EngineNode.AnimSprite2DNode(CanvasItem.setVisible(visible, sprite))
        case EngineNode.Label2DNode(label) => EngineNode.Label2DNode(CanvasItem.setVisible(visible, label))
        case EngineNode.Marker2DNode(marker) => EngineNode.Marker2DNode(CanvasItem.setVisible(visible, marker))
    }
    pub def getModulate(node: EngineNode): Color = match node {
        case EngineNode.Sprite2DNode(sprite) => CanvasItem.getModulate(sprite)
        case EngineNode.Area2DNode(area) => CanvasItem.getModulate(area)
        case EngineNode.Body2DNode(body) => CanvasItem.getModulate(body)
        case EngineNode.AnimSprite2DNode(sprite) => CanvasItem.getModulate(sprite)
        case EngineNode.Label2DNode(label) => CanvasItem.getModulate(label)
        case EngineNode.Marker2DNode(marker) => CanvasItem.getModulate(marker)
    }
    pub def setModulate(color: Color, node: EngineNode): EngineNode = match node {
        case EngineNode.Sprite2DNode(sprite) => EngineNode.Sprite2DNode(CanvasItem.setModulate(color, sprite))
        case EngineNode.Area2DNode(area) => EngineNode.Area2DNode(CanvasItem.setModulate(color, area))
        case EngineNode.Body2DNode(body) => EngineNode.Body2DNode(CanvasItem.setModulate(color, body))
        case EngineNode.AnimSprite2DNode(sprite) => EngineNode.AnimSprite2DNode(CanvasItem.setModulate(color, sprite))
        case EngineNode.Label2DNode(label) => EngineNode.Label2DNode(CanvasItem.setModulate(color, label))
        case EngineNode.Marker2DNode(marker) => EngineNode.Marker2DNode(CanvasItem.setModulate(color, marker))
    }
    pub def getZIndex(node: EngineNode): Int32 = match node {
        case EngineNode.Sprite2DNode(sprite) => CanvasItem.getZIndex(sprite)
        case EngineNode.Area2DNode(area) => CanvasItem.getZIndex(area)
        case EngineNode.Body2DNode(body) => CanvasItem.getZIndex(body)
        case EngineNode.AnimSprite2DNode(sprite) => CanvasItem.getZIndex(sprite)
        case EngineNode.Label2DNode(label) => CanvasItem.getZIndex(label)
        case EngineNode.Marker2DNode(marker) => CanvasItem.getZIndex(marker)
    }
    pub def setZIndex(zIndex: Int32, node: EngineNode): EngineNode = match node {
        case EngineNode.Sprite2DNode(sprite) => EngineNode.Sprite2DNode(CanvasItem.setZIndex(zIndex, sprite))
        case EngineNode.Area2DNode(area) => EngineNode.Area2DNode(CanvasItem.setZIndex(zIndex, area))
        case EngineNode.Body2DNode(body) => EngineNode.Body2DNode(CanvasItem.setZIndex(zIndex, body))
        case EngineNode.AnimSprite2DNode(sprite) => EngineNode.AnimSprite2DNode(CanvasItem.setZIndex(zIndex, sprite))
        case EngineNode.Label2DNode(label) => EngineNode.Label2DNode(CanvasItem.setZIndex(zIndex, label))
        case EngineNode.Marker2DNode(marker) => EngineNode.Marker2DNode(CanvasItem.setZIndex(zIndex, marker))
    }
}

// ── Node2D 実装 ──

instance Node2D[EngineNode] {
    pub def getPosition(node: EngineNode): Vec2.Vec2 = match node {
        case EngineNode.Sprite2DNode(sprite) => Node2D.getPosition(sprite)
        case EngineNode.Area2DNode(area) => Node2D.getPosition(area)
        case EngineNode.Body2DNode(body) => Node2D.getPosition(body)
        case EngineNode.AnimSprite2DNode(sprite) => Node2D.getPosition(sprite)
        case EngineNode.Label2DNode(label) => Node2D.getPosition(label)
        case EngineNode.Marker2DNode(marker) => Node2D.getPosition(marker)
    }
    pub def setPosition(position: Vec2.Vec2, node: EngineNode): EngineNode = match node {
        case EngineNode.Sprite2DNode(sprite) => EngineNode.Sprite2DNode(Node2D.setPosition(position, sprite))
        case EngineNode.Area2DNode(area) => EngineNode.Area2DNode(Node2D.setPosition(position, area))
        case EngineNode.Body2DNode(body) => EngineNode.Body2DNode(Node2D.setPosition(position, body))
        case EngineNode.AnimSprite2DNode(sprite) => EngineNode.AnimSprite2DNode(Node2D.setPosition(position, sprite))
        case EngineNode.Label2DNode(label) => EngineNode.Label2DNode(Node2D.setPosition(position, label))
        case EngineNode.Marker2DNode(marker) => EngineNode.Marker2DNode(Node2D.setPosition(position, marker))
    }
    pub def getRotation(node: EngineNode): Float64 = match node {
        case EngineNode.Sprite2DNode(sprite) => Node2D.getRotation(sprite)
        case EngineNode.Area2DNode(area) => Node2D.getRotation(area)
        case EngineNode.Body2DNode(body) => Node2D.getRotation(body)
        case EngineNode.AnimSprite2DNode(sprite) => Node2D.getRotation(sprite)
        case EngineNode.Label2DNode(label) => Node2D.getRotation(label)
        case EngineNode.Marker2DNode(marker) => Node2D.getRotation(marker)
    }
    pub def setRotation(rotation: Float64, node: EngineNode): EngineNode = match node {
        case EngineNode.Sprite2DNode(sprite) => EngineNode.Sprite2DNode(Node2D.setRotation(rotation, sprite))
        case EngineNode.Area2DNode(area) => EngineNode.Area2DNode(Node2D.setRotation(rotation, area))
        case EngineNode.Body2DNode(body) => EngineNode.Body2DNode(Node2D.setRotation(rotation, body))
        case EngineNode.AnimSprite2DNode(sprite) => EngineNode.AnimSprite2DNode(Node2D.setRotation(rotation, sprite))
        case EngineNode.Label2DNode(label) => EngineNode.Label2DNode(Node2D.setRotation(rotation, label))
        case EngineNode.Marker2DNode(marker) => EngineNode.Marker2DNode(Node2D.setRotation(rotation, marker))
    }
    pub def getScale(node: EngineNode): Vec2.Vec2 = match node {
        case EngineNode.Sprite2DNode(sprite) => Node2D.getScale(sprite)
        case EngineNode.Area2DNode(area) => Node2D.getScale(area)
        case EngineNode.Body2DNode(body) => Node2D.getScale(body)
        case EngineNode.AnimSprite2DNode(sprite) => Node2D.getScale(sprite)
        case EngineNode.Label2DNode(label) => Node2D.getScale(label)
        case EngineNode.Marker2DNode(marker) => Node2D.getScale(marker)
    }
    pub def setScale(scale: Vec2.Vec2, node: EngineNode): EngineNode = match node {
        case EngineNode.Sprite2DNode(sprite) => EngineNode.Sprite2DNode(Node2D.setScale(scale, sprite))
        case EngineNode.Area2DNode(area) => EngineNode.Area2DNode(Node2D.setScale(scale, area))
        case EngineNode.Body2DNode(body) => EngineNode.Body2DNode(Node2D.setScale(scale, body))
        case EngineNode.AnimSprite2DNode(sprite) => EngineNode.AnimSprite2DNode(Node2D.setScale(scale, sprite))
        case EngineNode.Label2DNode(label) => EngineNode.Label2DNode(Node2D.setScale(scale, label))
        case EngineNode.Marker2DNode(marker) => EngineNode.Marker2DNode(Node2D.setScale(scale, marker))
    }
    pub def getSkew(node: EngineNode): Float64 = match node {
        case EngineNode.Sprite2DNode(sprite) => Node2D.getSkew(sprite)
        case EngineNode.Area2DNode(area) => Node2D.getSkew(area)
        case EngineNode.Body2DNode(body) => Node2D.getSkew(body)
        case EngineNode.AnimSprite2DNode(sprite) => Node2D.getSkew(sprite)
        case EngineNode.Label2DNode(label) => Node2D.getSkew(label)
        case EngineNode.Marker2DNode(marker) => Node2D.getSkew(marker)
    }
    pub def setSkew(skew: Float64, node: EngineNode): EngineNode = match node {
        case EngineNode.Sprite2DNode(sprite) => EngineNode.Sprite2DNode(Node2D.setSkew(skew, sprite))
        case EngineNode.Area2DNode(area) => EngineNode.Area2DNode(Node2D.setSkew(skew, area))
        case EngineNode.Body2DNode(body) => EngineNode.Body2DNode(Node2D.setSkew(skew, body))
        case EngineNode.AnimSprite2DNode(sprite) => EngineNode.AnimSprite2DNode(Node2D.setSkew(skew, sprite))
        case EngineNode.Label2DNode(label) => EngineNode.Label2DNode(Node2D.setSkew(skew, label))
        case EngineNode.Marker2DNode(marker) => EngineNode.Marker2DNode(Node2D.setSkew(skew, marker))
    }
}

// ── CollisionObject2D 実装 ──

instance CollisionObject2D[EngineNode] {
    pub def getCollisionShape(node: EngineNode): Option[CollisionShape2D] = match node {
        case EngineNode.Area2DNode(area) => CollisionObject2D.getCollisionShape(area)
        case _ => None
    }
    pub def isMonitoring(node: EngineNode): Bool = match node {
        case EngineNode.Area2DNode(area) => CollisionObject2D.isMonitoring(area)
        case _ => false
    }
    pub def isMonitorable(node: EngineNode): Bool = match node {
        case EngineNode.Area2DNode(area) => CollisionObject2D.isMonitorable(area)
        case _ => false
    }
    redef getCollisionPriority(node: EngineNode): Int32 = match node {
        case EngineNode.Area2DNode(area) => CollisionObject2D.getCollisionPriority(area)
        case _ => 0
    }
}

// ── Renderable 実装 ──

instance Engine.Renderable[EngineNode] {
    pub def toDrawables(node: EngineNode, globalPos: Vec2.Vec2): List[Engine.Drawable] =
        match node {
            case EngineNode.Sprite2DNode(sprite) =>
                EngineNode.spriteToDrawable(sprite, globalPos) :: Nil
            case EngineNode.AnimSprite2DNode(sprite) =>
                EngineNode.animSpriteToDrawable(sprite, globalPos) :: Nil
            case EngineNode.Label2DNode(label) =>
                Label2D.toDrawables(label, globalPos)
            case _ =>
                EngineNode.fallbackDrawable(node, globalPos) :: Nil
        }
}
