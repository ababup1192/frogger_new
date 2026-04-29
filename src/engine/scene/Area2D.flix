/// 2D エリアノード（Godot Area2D 準拠）
/// see: https://docs.godotengine.org/ja/4.x/classes/class_area2d.html
///
/// 2D 空間上の領域を定義し、他の CollisionObject2D との重なりを検出する。
/// 物理演算は行わず、純粋なセンサー（トリガー）として機能する。
///
///   Area2D
///     +-- CanvasItem: visible, zIndex, modulate
///     +-- Node2D: position, rotation, scale, skew
///     +-- CollisionObject2D: collisionShape, monitoring, monitorable
pub enum Area2D {
    case Area2D({
        position = Vec2.Vec2,
        rotation = Float64,
        scale = Vec2.Vec2,
        skew = Float64,
        visible = Bool,
        zIndex = Int32,
        modulate = Color,
        monitoring = Bool,
        monitorable = Bool,
        priority = Int32,
        collisionShape = Option[CollisionShape2D]
    })
}

instance ToString[Area2D] {
    pub def toString(area: Area2D): String =
        let Area2D.Area2D(r) = area;
        "Area2D(pos=(${r#position#x}, ${r#position#y}), monitoring=${r#monitoring})"
}

instance Eq[Area2D] {
    pub def eq(a: Area2D, b: Area2D): Bool =
        let Area2D.Area2D(ra) = a;
        let Area2D.Area2D(rb) = b;
        ra#position#x == rb#position#x and
        ra#position#y == rb#position#y and
        ra#rotation == rb#rotation and
        ra#scale#x == rb#scale#x and
        ra#scale#y == rb#scale#y and
        ra#skew == rb#skew and
        ra#visible == rb#visible and
        ra#zIndex == rb#zIndex and
        ra#monitoring == rb#monitoring and
        ra#monitorable == rb#monitorable and
        ra#priority == rb#priority and
        ra#collisionShape == rb#collisionShape
}

instance Order[Area2D] {
    pub def compare(a: Area2D, b: Area2D): Comparison =
        let Area2D.Area2D(ra) = a;
        let Area2D.Area2D(rb) = b;
        match Order.compare(ra#priority, rb#priority) {
            case Comparison.EqualTo => match Order.compare(ra#zIndex, rb#zIndex) {
                case Comparison.EqualTo => match Order.compare(ra#position#x, rb#position#x) {
                    case Comparison.EqualTo => Order.compare(ra#position#y, rb#position#y)
                    case c => c
                }
                case c => c
            }
            case c => c
        }
}

mod Area2D {
    /// デフォルト値で Area2D を生成する。
    /// monitoring / monitorable は共に true（Godot デフォルト準拠）。
    pub def make(position: Vec2.Vec2, shape: CollisionShape2D): Area2D =
        Area2D.Area2D({
            position = position,
            rotation = 0.0,
            scale = {x = 1.0f32, y = 1.0f32},
            skew = 0.0,
            visible = true,
            zIndex = 0,
            modulate = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
            monitoring = true,
            monitorable = true,
            priority = 0,
            collisionShape = Some(shape)
        })

    /// monitoring フラグを設定する
    pub def setMonitoring(v: Bool, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ monitoring = v | r })

    /// monitorable フラグを設定する
    pub def setMonitorable(v: Bool, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ monitorable = v | r })

    /// priority を設定する
    pub def setPriority(p: Int32, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ priority = p | r })

    /// 衝突形状を設定する
    pub def setCollisionShape(shape: Option[CollisionShape2D], area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ collisionShape = shape | r })
}

// -- CanvasItem 実装 --

instance CanvasItem[Area2D] {
    pub def isVisible(area: Area2D): Bool =
        let Area2D.Area2D(r) = area;
        r#visible
    pub def setVisible(visible: Bool, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ visible = visible | r })
    pub def getModulate(area: Area2D): Color =
        let Area2D.Area2D(r) = area;
        r#modulate
    pub def setModulate(color: Color, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ modulate = color | r })
    pub def getZIndex(area: Area2D): Int32 =
        let Area2D.Area2D(r) = area;
        r#zIndex
    pub def setZIndex(zIndex: Int32, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ zIndex = zIndex | r })
}

// -- Node2D 実装 --

instance Node2D[Area2D] {
    pub def getPosition(area: Area2D): Vec2.Vec2 =
        let Area2D.Area2D(r) = area;
        r#position
    pub def setPosition(position: Vec2.Vec2, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ position = position | r })
    pub def getRotation(area: Area2D): Float64 =
        let Area2D.Area2D(r) = area;
        r#rotation
    pub def setRotation(rotation: Float64, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ rotation = rotation | r })
    pub def getScale(area: Area2D): Vec2.Vec2 =
        let Area2D.Area2D(r) = area;
        r#scale
    pub def setScale(scale: Vec2.Vec2, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ scale = scale | r })
    pub def getSkew(area: Area2D): Float64 =
        let Area2D.Area2D(r) = area;
        r#skew
    pub def setSkew(skew: Float64, area: Area2D): Area2D =
        let Area2D.Area2D(r) = area;
        Area2D.Area2D({ skew = skew | r })
}

// -- CollisionObject2D 実装 --

instance CollisionObject2D[Area2D] {
    pub def getCollisionShape(area: Area2D): Option[CollisionShape2D] =
        let Area2D.Area2D(r) = area;
        r#collisionShape
    pub def isMonitoring(area: Area2D): Bool =
        let Area2D.Area2D(r) = area;
        r#monitoring
    pub def isMonitorable(area: Area2D): Bool =
        let Area2D.Area2D(r) = area;
        r#monitorable
    redef getCollisionPriority(area: Area2D): Int32 =
        let Area2D.Area2D(r) = area;
        r#priority
}

// -- Node 実装 --

instance Node[Area2D] {
    redef getSelf(path: NodePath, scene: Scene[Area2D]): Option[Area2D] =
        Scene.getAt(path, scene)
    redef setSelf(path: NodePath, self: Area2D, scene: Scene[Area2D]): Scene[Area2D] =
        Scene.setAt(path, self, scene)
}
