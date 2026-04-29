// Game — Frogger ゲーム専用の GameNode 定義とシーン構築・ゲームロジック

pub enum GameNode {
    /// プレイヤー（CharacterBody2D）
    case Player({body = CharacterBody2D})
    /// 車両（Area2D + 水平速度）
    case Vehicle({area = Area2D, vx = Float32})
    /// 丸太プラットフォーム（Area2D + 水平速度 + プラットフォーム幅）
    case LogPlatform({area = Area2D, vx = Float32, platformWidth = Float32})
    /// アニメーション付きスプライト（プレイヤースプライト用）
    case AnimSpriteNode(AnimatedSprite2D)
    /// 静的スプライト（背景・車両スプライト・丸太スプライト用）
    case SpriteNode(Sprite2D)
    /// ホームスロット（Area2D + 充填済みフラグ）
    case HomeSlot({area = Area2D, filled = Bool})
    /// 亀プラットフォーム（Area2D + 水平速度 + プラットフォーム幅）
    case TurtlePlatform({area = Area2D, vx = Float32, platformWidth = Float32})
    /// 汎用 Area2D（プレイヤーの Hitbox 等）
    case AreaNode(Area2D)
    /// 位置マーカー（ターゲット位置等の参照点）
    case Marker2DNode(Marker2D)
    /// タイマー（カウントダウン）
    case TimerNode(Timer)
    /// テキストラベル（HUD 表示）
    case Label2DNode(Label2D)
}

// ── Node 実装 ──

instance Node[GameNode] {
    redef ready(self: GameNode, _path: NodePath, scene: Scene[GameNode]): (GameNode, Scene[GameNode]) =
        match self {
            case GameNode.TimerNode(timer) =>
                (GameNode.TimerNode(Timer.ready(timer)), scene)
            case _ => (self, scene)
        }

    redef isTimedOut(self: GameNode): Bool = match self {
        case GameNode.TimerNode(timer) => Timer.isTimedOut(timer)
        case _ => false
    }

    redef clearTimedOut(self: GameNode): GameNode = match self {
        case GameNode.TimerNode(timer) => GameNode.TimerNode(Timer.clearTimedOut(timer))
        case other => other
    }

    redef process(delta: Float64, self: GameNode, _path: NodePath,
                    scene: Scene[GameNode]): (GameNode, Scene[GameNode]) =
        let dt = Float64.truncateToFloat32(delta);
        match self {
            // Player: ターゲット（Marker2D）に向かって moveToward で移動
            case GameNode.Player(r) =>
                let currentPos = Node2D.getPosition(r#body);
                let speed = CharacterBody2D.getMoveSpeed(r#body);
                let targetPos = Game.getPlayerTarget(scene);
                let newPos = Vec2.moveToward(currentPos, targetPos, speed * dt);
                let newBody = Node2D.setPosition(newPos, r#body);
                (GameNode.Player({body = newBody}), scene)
            // Vehicle: 水平方向に移動し、画面外でラップ
            case GameNode.Vehicle(r) =>
                let pos = Node2D.getPosition(r#area);
                let newX = pos#x + r#vx * dt;
                let wrappedX =
                    if (r#vx < 0.0f32 and newX < -100.0f32)
                        Game.screenW() + 100.0f32
                    else if (r#vx > 0.0f32 and newX > Game.screenW() + 100.0f32)
                        -100.0f32
                    else
                        newX;
                let newArea = Node2D.setPosition({x = wrappedX, y = pos#y}, r#area);
                (GameNode.Vehicle({area = newArea | r}), scene)
            // LogPlatform: Vehicle と同じ移動＋ラップ
            case GameNode.LogPlatform(r) =>
                let pos = Node2D.getPosition(r#area);
                let newX = pos#x + r#vx * dt;
                let wrappedX =
                    if (r#vx < 0.0f32 and newX < -100.0f32)
                        Game.screenW() + 100.0f32
                    else if (r#vx > 0.0f32 and newX > Game.screenW() + 100.0f32)
                        -100.0f32
                    else
                        newX;
                let newArea = Node2D.setPosition({x = wrappedX, y = pos#y}, r#area);
                (GameNode.LogPlatform({area = newArea | r}), scene)
            // TurtlePlatform: LogPlatform と同じ移動＋ラップ
            case GameNode.TurtlePlatform(r) =>
                let pos = Node2D.getPosition(r#area);
                let newX = pos#x + r#vx * dt;
                let wrappedX =
                    if (r#vx < 0.0f32 and newX < -100.0f32)
                        Game.screenW() + 100.0f32
                    else if (r#vx > 0.0f32 and newX > Game.screenW() + 100.0f32)
                        -100.0f32
                    else
                        newX;
                let newArea = Node2D.setPosition({x = wrappedX, y = pos#y}, r#area);
                (GameNode.TurtlePlatform({area = newArea | r}), scene)
            // AnimSpriteNode: フレームを進める
            case GameNode.AnimSpriteNode(sprite) =>
                (GameNode.AnimSpriteNode(AnimatedSprite2D.advanceFrame(dt, sprite)), scene)
            // TimerNode: カウントダウン処理
            case GameNode.TimerNode(timer) =>
                (GameNode.TimerNode(Timer.process(dt, timer)), scene)
            case _ => (self, scene)
        }
}

// ── TimerHandler 実装 ──

instance TimerEvent.TimerHandler[GameNode] {
    pub def onTimeout(timerPath: NodePath, _timer: GameNode, scene: Scene[GameNode]): Scene[GameNode] =
        match List.head(timerPath) {
            case Some("gameTimer") =>
                // deathTimer が既に動いていれば何もしない（衝突死亡中）
                match Scene.get("deathTimer", scene) {
                    case Some(GameNode.TimerNode(t)) if Timer.isRunning(t) => scene
                    case _ =>
                        Game.playDeathAnim({r = 1.0f32, g = 1.0f32, b = 0.2f32}, scene)
                            |> Game.startDeathTimer
                }
            case Some("deathTimer") =>
                Game.respawnPlayerScene(scene)
            case _ => scene
        }
}

// ── AreaHandler 実装 ──

instance AreaHandler[GameNode] {
    pub def onAreaEntered(selfPath: NodePath, _self: GameNode,
                          _otherPath: NodePath, other: GameNode,
                          scene: Scene[GameNode]): Scene[GameNode] =
        match (selfPath, other) {
            // プレイヤーの Hitbox が Vehicle と衝突 → スプライトを赤にする
            case ("player" :: "Hitbox" :: Nil, GameNode.Vehicle(_)) =>
                Scene.mapAt("player" :: "Sprite" :: Nil, node -> match node {
                    case GameNode.AnimSpriteNode(sprite) =>
                        GameNode.AnimSpriteNode(CanvasItem.setModulate({r = 1.0f32, g = 0.2f32, b = 0.2f32}, sprite))
                    case other2 => other2
                }, scene)
            case _ => scene
        }
}

mod Game {

    // ========================================================================
    // 画面・タイル定数
    // ========================================================================

    /// 画面幅（ピクセル）
    pub def screenW(): Float32 = 784.0f32

    /// 画面高さ（ピクセル）
    pub def screenH(): Float32 = 1000.0f32

    /// 画面幅（整数、EngineConfig 用）
    pub def screenWi(): Int32 = 784

    /// 画面高さ（整数、EngineConfig 用）
    pub def screenHi(): Int32 = 1000

    /// 1 タイルのサイズ（16px テクスチャを 4 倍表示）
    pub def tileSize(): Float32 = 64.0f32

    // ========================================================================
    // プレイヤー定数
    // ========================================================================

    /// プレイヤー初期位置（スタートゾーン中央）
    pub def playerStart(): Vec2.Vec2 = {x = 384.0f32, y = 832.0f32}

    /// プレイヤー移動速度（ピクセル/秒）
    pub def moveSpeed(): Float32 = 512.0f32

    /// プレイヤー位置クランプ範囲（左上）
    pub def playerMin(): Vec2.Vec2 = {x = 0.0f32, y = 0.0f32}

    /// プレイヤー位置クランプ範囲（右下: screenW - tileSize, スタートゾーン Y）
    pub def playerMax(): Vec2.Vec2 = {x = 720.0f32, y = 832.0f32}

    // ========================================================================
    // ゾーン Y 座標・高さ
    // ========================================================================

    def homeZoneY(): Float32 = 0.0f32
    def homeZoneH(): Float32 = 64.0f32

    pub def waterZoneY(): Float32 = 64.0f32
    pub def waterZoneH(): Float32 = 384.0f32

    def medianZoneY(): Float32 = 448.0f32
    def medianZoneH(): Float32 = 64.0f32

    def roadZoneY(): Float32 = 512.0f32
    def roadZoneH(): Float32 = 320.0f32

    def startZoneY(): Float32 = 832.0f32
    def startZoneH(): Float32 = 64.0f32

    // ========================================================================
    // ゲーム状態
    // ========================================================================

    /// ゲーム全体の状態を保持する型
    /// timeRemaining / deathTimer は Timer ノードに移行済み
    pub type alias GameState = {
        scene = Scene[GameNode],       // シーンツリー
        lives = Int32,                 // 残機
        filledHomes = Set[Int32],      // 充填済みホームスロット
        isDead = Bool,                 // 死亡フラグ
        prevKeys = Set[Engine.Key],    // 前フレームの押下キー
        prevOverlaps = OverlapPairSet  // 前フレームの衝突ペア
    }

    /// 初期ゲーム状態を構築する
    pub def initGameState(fontAtlas: FontAtlas): GameState =
        {
            scene = buildScene(fontAtlas) |> Scene.readyAll,
            lives = 3,
            filledHomes = Set.empty(),
            isDead = false,
            prevKeys = Set.empty(),
            prevOverlaps = Set.empty()
        }

    /// Frogger の初期シーンを構築する
    pub def buildScene(fontAtlas: FontAtlas): Scene[GameNode] =
        let green: Color = {r = 0.2f32, g = 0.55f32, b = 0.15f32};
        let sw = screenW();
        Scene.empty()
            // ── 背景ゾーン (zIndex=-10: 最背面) ──
            |> Scene.addNode("bgHome",
                makeSolidBg(green, {x = 0.0f32, y = homeZoneY()},
                    width = sw, height = homeZoneH(), zIndex = -10))
            |> Scene.addNode("bgWater",
                makeTiledBg("Water", {x = 0.0f32, y = waterZoneY()},
                    width = sw, height = waterZoneH(), zIndex = -10))
            |> Scene.addNode("bgMedian",
                makeTiledBg("Median", {x = 0.0f32, y = medianZoneY()},
                    width = sw, height = medianZoneH(), zIndex = -10))
            |> Scene.addNode("bgRoad",
                makeTiledBg("Road", {x = 0.0f32, y = roadZoneY()},
                    width = sw, height = roadZoneH(), zIndex = -10))
            |> Scene.addNode("bgStart",
                makeSolidBg(green, {x = 0.0f32, y = startZoneY()},
                    width = sw, height = startZoneH(), zIndex = -10))
            // ── ホームスロット ──
            |> addAllHomeSlots
            // ── プレイヤー (CharacterBody2D + AnimatedSprite2D + Hitbox) ──
            |> Scene.addNode("player",
                GameNode.Player({
                    body = CanvasItem.hide(CharacterBody2D.make(playerStart(), moveSpeed = moveSpeed()))
                }))
            // ── プレイヤーのターゲット位置（Marker2D） ──
            |> Scene.addNode("playerTarget",
                GameNode.Marker2DNode(Marker2D.make(playerStart())))
            |> Scene.addChild("player", "Sprite",
                GameNode.AnimSpriteNode(
                    AnimatedSprite2D.make(
                        Map#{
                            "idle" => ("FroggerIdle" :: "FroggerLeap" :: Nil),
                            "dead" => ("FroggerDead" :: Nil)
                        },
                        initialAnimation = "idle",
                        fps = 4.0f32,
                        {x = 0.0f32, y = 0.0f32},
                        {x = 4.0f32, y = 4.0f32})))
            |> Scene.addChildAt("player" :: Nil, "Hitbox",
                GameNode.AreaNode(
                    CanvasItem.hide(
                        Area2D.make({x = 16.0f32, y = 20.0f32},
                            CollisionShape2D.RectShape2D({width = 32.0f32, height = 24.0f32})))))
            // ── 車両 ──
            |> addAllVehicles
            // ── 丸太 ──
            |> addAllLogs
            // ── 亀 ──
            |> addAllTurtles
            // ── Timer ノード ──
            |> Scene.addNode("gameTimer",
                GameNode.TimerNode(
                    Timer.make(30.0f32)
                        |> Timer.setAutostart(true)))
            |> Scene.addNode("deathTimer",
                GameNode.TimerNode(Timer.make(2.0f32)))
            // ── HUD Label ──
            |> Scene.addNode("timerLabel",
                GameNode.Label2DNode(
                    Label2D.make("TIME: 30", fontAtlas, 24.0f32)
                        |> Node2D.setPosition({x = 10.0f32, y = 900.0f32})
                        |> CanvasItem.setZIndex(10)))
            |> Scene.addNode("livesLabel",
                GameNode.Label2DNode(
                    Label2D.make("LIVES: 3", fontAtlas, 24.0f32)
                        |> Node2D.setPosition({x = 10.0f32, y = 940.0f32})
                        |> CanvasItem.setZIndex(10)))

    // ========================================================================
    // GameNode ヘルパー
    // ========================================================================

    /// GameNode から内部の Area2D を取り出す（Area2D を持たないバリアントでは bug!）
    pub def getArea(node: GameNode): Area2D = match node {
        case GameNode.HomeSlot(r) => r#area
        case GameNode.Vehicle(r) => r#area
        case GameNode.LogPlatform(r) => r#area
        case GameNode.TurtlePlatform(r) => r#area
        case GameNode.AreaNode(area) => area
        case _ => bug!("Node has no Area2D")
    }

    /// 内部の Area2D に関数を適用して再ラップする
    pub def mapArea(f: Area2D -> Area2D, node: GameNode): GameNode = match node {
        case GameNode.HomeSlot(r) => GameNode.HomeSlot({area = f(r#area) | r})
        case GameNode.Vehicle(r) => GameNode.Vehicle({area = f(r#area) | r})
        case GameNode.LogPlatform(r) => GameNode.LogPlatform({area = f(r#area) | r})
        case GameNode.TurtlePlatform(r) => GameNode.TurtlePlatform({area = f(r#area) | r})
        case GameNode.AreaNode(area) => GameNode.AreaNode(f(area))
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

    // ========================================================================
    // スプライト生成ヘルパー
    // ========================================================================

    /// タイリング背景スプライトを生成する
    def makeTiledBg(texture: String, position: Vec2.Vec2,
                    width: {width = Float32}, height: {height = Float32},
                    zIndex: {zIndex = Int32}): GameNode =
        let texSize = 16.0f32;
        GameNode.SpriteNode(Sprite2D.Sprite2D({
            position = position,
            rotation = 0.0,
            scale = {x = width#width / texSize, y = height#height / texSize},
            skew = 0.0,
            visible = true,
            zIndex = zIndex#zIndex,
            modulate = {r = 1.0f32, g = 1.0f32, b = 1.0f32},
            texture = texture,
            centered = false,
            offset = {x = 0.0f32, y = 0.0f32},
            flipH = false,
            flipV = false
        }))

    /// 単色の矩形背景を生成する
    def makeSolidBg(color: Color, position: Vec2.Vec2,
                    width: {width = Float32}, height: {height = Float32},
                    zIndex: {zIndex = Int32}): GameNode =
        GameNode.SpriteNode(Sprite2D.Sprite2D({
            position = position,
            rotation = 0.0,
            scale = {x = width#width, y = height#height},
            skew = 0.0,
            visible = true,
            zIndex = zIndex#zIndex,
            modulate = color,
            texture = "white",
            centered = false,
            offset = {x = 0.0f32, y = 0.0f32},
            flipH = false,
            flipV = false
        }))

    // ========================================================================
    // 車両生成
    // ========================================================================

    /// 車両レーンの設定
    type alias VehicleLaneConfig = {
        texture = String,    // テクスチャ名
        y = Float32,         // レーン Y 座標
        vx = Float32,        // 速度（px/s, 負で左向き）
        count = Int32,       // 台数
        spacing = Float32    // 車両間の間隔
    }

    /// 5 レーン分の車両設定（旧 Frogger 準拠）
    def vehicleLanes(): List[VehicleLaneConfig] =
        {texture = "Car1", y = 512.0f32, vx = -200.0f32, count = 3, spacing = 100.0f32} ::
        {texture = "Car2", y = 576.0f32, vx = 250.0f32,  count = 4, spacing = 150.0f32} ::
        {texture = "Car3", y = 640.0f32, vx = -200.0f32, count = 2, spacing = 300.0f32} ::
        {texture = "Car4", y = 704.0f32, vx = 200.0f32,  count = 4, spacing = 300.0f32} ::
        {texture = "Car5", y = 768.0f32, vx = -160.0f32, count = 2, spacing = 230.0f32} ::
        Nil

    /// 1 レーン分の Vehicle ノードをシーンに追加する
    def addVehicleLane(laneIdx: Int32, config: VehicleLaneConfig,
                       scene: Scene[GameNode]): Scene[GameNode] =
        List.range(0, config#count) |> List.foldLeft((acc, vehicleIdx) -> {
            let name = "v${laneIdx}_${vehicleIdx}";
            let startX = Int32.toFloat32(vehicleIdx) * (tileSize() + config#spacing);
            let shape = CollisionShape2D.RectShape2D({width = 64.0f32, height = 48.0f32});
            let area = Area2D.make({x = startX, y = config#y}, shape)
                |> Area2D.setMonitoring(false)
                |> Area2D.setMonitorable(true);
            acc
                |> Scene.addNode(name,
                    GameNode.Vehicle({area = area, vx = config#vx}))
                |> Scene.addChild(name, "sprite",
                    GameNode.SpriteNode(
                        Sprite2D.make(config#texture, {x = 0.0f32, y = 0.0f32},
                            {x = 4.0f32, y = 4.0f32})))
        }, scene)

    /// 全車両レーンをシーンに追加する
    def addAllVehicles(scene: Scene[GameNode]): Scene[GameNode] =
        vehicleLanes()
            |> List.zipWithIndex
            |> List.foldLeft((acc, pair) -> {
                let (idx, config) = pair;
                addVehicleLane(idx, config, acc)
            }, scene)

    // ========================================================================
    // 丸太生成
    // ========================================================================

    /// 丸太レーンの設定
    /// middles: 中間セグメント数（合計ピース数 = middles + 2）
    type alias LogLaneConfig = {
        y = Float32,         // レーン Y 座標
        vx = Float32,        // 速度（px/s）
        middles = Int32,     // 中間セグメント数
        count = Int32,       // 丸太の本数
        spacing = Float32    // 丸太間の間隔
    }

    /// 4 レーン分の丸太設定（旧 Frogger 準拠）
    def logLanes(): List[LogLaneConfig] =
        {y =  64.0f32, vx =  120.0f32, middles = 1, count = 3, spacing = 250.0f32} ::
        {y = 128.0f32, vx =  -80.0f32, middles = 2, count = 2, spacing = 350.0f32} ::
        {y = 192.0f32, vx =  150.0f32, middles = 0, count = 4, spacing = 200.0f32} ::
        {y = 256.0f32, vx = -100.0f32, middles = 1, count = 3, spacing = 280.0f32} ::
        Nil

    /// 丸太のプラットフォーム幅を計算する（middles + 2 ピース × tileSize）
    def logWidth(middles: Int32): Float32 =
        Int32.toFloat32(middles + 2) * tileSize()

    /// 1 本の丸太にスプライト子ノードを追加する
    def addLogSprites(logName: String, middles: Int32,
                      scene: Scene[GameNode]): Scene[GameNode] =
        let totalPieces = middles + 2;
        let totalWidth = logWidth(middles);
        List.range(0, totalPieces) |> List.foldLeft((acc, pieceIdx) -> {
            let texture =
                if (pieceIdx == 0) "LogStart"
                else if (pieceIdx == totalPieces - 1) "LogEnd"
                else "LogMiddle";
            let offsetX = -1.0f32 * totalWidth / 2.0f32 + 32.0f32 + Int32.toFloat32(pieceIdx) * tileSize();
            Scene.addChild(logName, "s${pieceIdx}",
                GameNode.SpriteNode(
                    Sprite2D.make(texture, {x = offsetX, y = 0.0f32},
                        {x = 4.0f32, y = 4.0f32})),
                acc)
        }, scene)

    /// 1 レーン分の LogPlatform ノードをシーンに追加する
    def addLogLane(laneIdx: Int32, config: LogLaneConfig,
                   scene: Scene[GameNode]): Scene[GameNode] =
        let platformWidth = logWidth(config#middles);
        List.range(0, config#count) |> List.foldLeft((acc, logIdx) -> {
            let name = "l${laneIdx}_${logIdx}";
            let startX = Int32.toFloat32(logIdx) * (platformWidth + config#spacing);
            let shape = CollisionShape2D.RectShape2D({width = platformWidth, height = 48.0f32});
            let area = Area2D.make({x = startX, y = config#y}, shape)
                |> CanvasItem.hide
                |> Area2D.setMonitoring(false)
                |> Area2D.setMonitorable(false);
            acc
                |> Scene.addNode(name,
                    GameNode.LogPlatform({area = area, vx = config#vx, platformWidth = platformWidth}))
                |> addLogSprites(name, config#middles)
        }, scene)

    /// 全丸太レーンをシーンに追加する
    def addAllLogs(scene: Scene[GameNode]): Scene[GameNode] =
        logLanes()
            |> List.zipWithIndex
            |> List.foldLeft((acc, pair) -> {
                let (idx, config) = pair;
                addLogLane(idx, config, acc)
            }, scene)

    // ========================================================================
    // 亀生成
    // ========================================================================

    type alias TurtleLaneConfig = {
        y = Float32,
        vx = Float32,
        sections = Int32,
        count = Int32,
        spacing = Float32
    }

    def turtleLanes(): List[TurtleLaneConfig] =
        {y = 320.0f32, vx =  100.0f32, sections = 3, count = 3, spacing = 250.0f32} ::
        {y = 384.0f32, vx = -130.0f32, sections = 4, count = 2, spacing = 200.0f32} ::
        Nil

    def turtleWidth(sections: Int32): Float32 =
        Int32.toFloat32(sections) * tileSize()

    def addTurtleSprites(turtleName: String, sections: Int32,
                         scene: Scene[GameNode]): Scene[GameNode] =
        let totalWidth = turtleWidth(sections);
        List.range(0, sections) |> List.foldLeft((acc, sectionIdx) -> {
            let offsetX = -1.0f32 * totalWidth / 2.0f32 + 32.0f32 + Int32.toFloat32(sectionIdx) * tileSize();
            Scene.addChild(turtleName, "s${sectionIdx}",
                GameNode.SpriteNode(
                    Sprite2D.make("Turtle_01", {x = offsetX, y = 0.0f32},
                        {x = 4.0f32, y = 4.0f32})),
                acc)
        }, scene)

    def addTurtleLane(laneIdx: Int32, config: TurtleLaneConfig,
                      scene: Scene[GameNode]): Scene[GameNode] =
        let platformWidth = turtleWidth(config#sections);
        List.range(0, config#count) |> List.foldLeft((acc, turtleIdx) -> {
            let name = "t${laneIdx}_${turtleIdx}";
            let startX = Int32.toFloat32(turtleIdx) * (platformWidth + config#spacing);
            let shape = CollisionShape2D.RectShape2D({width = platformWidth, height = 48.0f32});
            let area = Area2D.make({x = startX, y = config#y}, shape)
                |> CanvasItem.hide
                |> Area2D.setMonitoring(false)
                |> Area2D.setMonitorable(false);
            acc
                |> Scene.addNode(name,
                    GameNode.TurtlePlatform({area = area, vx = config#vx, platformWidth = platformWidth}))
                |> addTurtleSprites(name, config#sections)
        }, scene)

    def addAllTurtles(scene: Scene[GameNode]): Scene[GameNode] =
        turtleLanes()
            |> List.zipWithIndex
            |> List.foldLeft((acc, pair) -> {
                let (idx, config) = pair;
                addTurtleLane(idx, config, acc)
            }, scene)

    // ========================================================================
    // ホームスロット生成
    // ========================================================================

    def homeSlotXPositions(): List[Float32] =
        64.0f32 :: 192.0f32 :: 384.0f32 :: 512.0f32 :: 704.0f32 :: Nil

    def addAllHomeSlots(scene: Scene[GameNode]): Scene[GameNode] =
        homeSlotXPositions()
            |> List.zipWithIndex
            |> List.foldLeft((acc, pair) -> {
                let (idx, slotX) = pair;
                let name = "home${idx}";
                let shape = CollisionShape2D.RectShape2D({width = 64.0f32, height = 64.0f32});
                let area = Area2D.make({x = slotX, y = homeZoneY()}, shape)
                    |> CanvasItem.hide
                    |> Area2D.setMonitoring(false)
                    |> Area2D.setMonitorable(false);
                acc
                    |> Scene.addNode(name,
                        GameNode.HomeSlot({area = area, filled = false}))
                    |> Scene.addChild(name, "sprite",
                        GameNode.SpriteNode(
                            Sprite2D.make("Home", {x = 0.0f32, y = 0.0f32},
                                {x = 4.0f32, y = 4.0f32})))
            }, scene)

    // ========================================================================
    // ホームスロット判定
    // ========================================================================

    pub def tryFillHomeSlot(state: GameState): GameState =
        let target = getPlayerTarget(state#scene);
        let playerPos = Scene.globalPosition("player", state#scene);
        let arrived = Vec2.distanceTo(playerPos, target) < 2.0f32;
        if (not arrived or target#y >= homeZoneY() + homeZoneH()) state
        else {
            let result = homeSlotXPositions()
                |> List.zipWithIndex
                |> List.foldLeft((best, pair) -> {
                    let (idx, slotX) = pair;
                    let slotName = "home${idx}";
                    match Scene.get(slotName, state#scene) {
                        case Some(GameNode.HomeSlot(r)) =>
                            if (r#filled) best
                            else {
                                let dist = Float32.abs(target#x - slotX);
                                match best {
                                    case None => Some((idx, slotName, dist))
                                    case Some((_, _, bestDist)) =>
                                        if (dist < bestDist) Some((idx, slotName, dist))
                                        else best
                                }
                            }
                        case _ => best
                    }
                }, (None: Option[(Int32, String, Float32)]));
            match result {
                case None => state
                case Some((_idx, slotName, _dist)) =>
                    let scene1 = Scene.mapAt(slotName :: Nil, node -> match node {
                        case GameNode.HomeSlot(r) =>
                            GameNode.HomeSlot({filled = true | r})
                        case other => other
                    }, state#scene);
                    let scene2 = Scene.mapAt(slotName :: "sprite" :: Nil, node -> match node {
                        case GameNode.SpriteNode(sprite) =>
                            GameNode.SpriteNode(Sprite2D.setTexture("HomeFrog", sprite))
                        case other => other
                    }, scene1);
                    let scene3 = Scene.mapAt("player" :: Nil, node -> match node {
                        case GameNode.Player(r) =>
                            GameNode.Player({body = Node2D.setPosition(playerStart(), r#body)})
                        case other => other
                    }, scene2);
                    let scene4 = Scene.mapAt("playerTarget" :: Nil, node -> match node {
                        case GameNode.Marker2DNode(m) =>
                            GameNode.Marker2DNode(Node2D.setPosition(playerStart(), m))
                        case other => other
                    }, scene3);
                    // ゲームタイマーをリスタート
                    let scene5 = Scene.mapAt("gameTimer" :: Nil, node -> match node {
                        case GameNode.TimerNode(timer) =>
                            GameNode.TimerNode(Timer.start(timer))
                        case other => other
                    }, scene4);
                    {scene = scene5 | state}
            }
        }

    pub def allHomesFilled(scene: Scene[GameNode]): Bool =
        homeSlotXPositions()
            |> List.zipWithIndex
            |> List.forAll(pair -> {
                let (idx, _) = pair;
                match Scene.get("home${idx}", scene) {
                    case Some(GameNode.HomeSlot(r)) => r#filled
                    case _ => false
                }
            })

    // ========================================================================
    // キーボード入力
    // ========================================================================

    pub def collectPressedKeys(): Set[Engine.Key] \ Engine.Game =
        let keys = Engine.Key.W :: Engine.Key.A :: Engine.Key.S :: Engine.Key.D ::
                   Engine.Key.Up :: Engine.Key.Down :: Engine.Key.Left :: Engine.Key.Right ::
                   Engine.Key.Enter :: Engine.Key.Escape :: Nil;
        List.foldLeft((acc, key) ->
            if (Engine.Game.isKeyPressed(key)) Set.insert(key, acc) else acc,
            Set.empty(), keys)

    pub def justPressedKeys(current: Set[Engine.Key], previous: Set[Engine.Key]): Set[Engine.Key] =
        Set.difference(current, previous)

    pub def inputDirection(justPressed: Set[Engine.Key]): Option[Vec2.Vec2] =
        if (Set.memberOf(Engine.Key.W, justPressed) or Set.memberOf(Engine.Key.Up, justPressed))
            Some(Vec2.up())
        else if (Set.memberOf(Engine.Key.S, justPressed) or Set.memberOf(Engine.Key.Down, justPressed))
            Some(Vec2.down())
        else if (Set.memberOf(Engine.Key.A, justPressed) or Set.memberOf(Engine.Key.Left, justPressed))
            Some(Vec2.left())
        else if (Set.memberOf(Engine.Key.D, justPressed) or Set.memberOf(Engine.Key.Right, justPressed))
            Some(Vec2.right())
        else
            None

    // ========================================================================
    // プレイヤー操作
    // ========================================================================

    pub def directionToRotation(direction: Vec2.Vec2): Float64 =
        if (direction#y < 0.0f32) 0.0
        else if (direction#x > 0.0f32) 1.5707963267949
        else if (direction#y > 0.0f32) 3.1415926535898
        else -1.5707963267949

    pub def applyInput(direction: Option[Vec2.Vec2], state: GameState): GameState =
        match direction {
            case None => state
            case Some(dir) =>
                let currentTarget = getPlayerTarget(state#scene);
                let newTarget = Vec2.clamp(
                    Vec2.add(currentTarget, Vec2.mul(dir, tileSize())),
                    playerMin(), playerMax());
                let scene1 = Scene.mapAt("playerTarget" :: Nil, node -> match node {
                    case GameNode.Marker2DNode(m) =>
                        GameNode.Marker2DNode(Node2D.setPosition(newTarget, m))
                    case other => other
                }, state#scene);
                let scene2 = Scene.mapAt("player" :: "Sprite" :: Nil, node -> match node {
                    case GameNode.AnimSpriteNode(sprite) =>
                        GameNode.AnimSpriteNode(Node2D.setRotation(directionToRotation(dir), sprite))
                    case other => other
                }, scene1);
                {scene = scene2 | state}
        }

    pub def getPlayerTarget(scene: Scene[GameNode]): Vec2.Vec2 =
        match Scene.get("playerTarget", scene) {
            case Some(GameNode.Marker2DNode(m)) => Node2D.getPosition(m)
            case _ => playerStart()
        }

    // ========================================================================
    // プラットフォーム乗り
    // ========================================================================

    def isOnPlatform(playerPos: Vec2.Vec2, logPos: Vec2.Vec2,
                     platformWidth: Float32): Bool =
        let halfW = platformWidth / 2.0f32;
        let halfH = 32.0f32;
        playerPos#x >= logPos#x - halfW and playerPos#x <= logPos#x + halfW and
        playerPos#y >= logPos#y - halfH and playerPos#y <= logPos#y + halfH

    pub def findPlatformVelocity(scene: Scene[GameNode]): Option[Float32] =
        let playerPos = Scene.globalPosition("player", scene);
        Map.foldLeftWithKey((acc, name, rootNode) ->
            match acc {
                case Some(_) => acc
                case None =>
                    match rootNode {
                        case GameNode.LogPlatform(r) =>
                            let logPos = Scene.globalPosition(name, scene);
                            if (isOnPlatform(playerPos, logPos, r#platformWidth))
                                Some(r#vx)
                            else
                                None
                        case GameNode.TurtlePlatform(r) =>
                            let turtlePos = Scene.globalPosition(name, scene);
                            if (isOnPlatform(playerPos, turtlePos, r#platformWidth))
                                Some(r#vx)
                            else
                                None
                        case _ => None
                    }
            },
            None, Scene.nodes(scene))

    pub def applyPlatformRiding(dt: Float32, state: GameState): GameState =
        match findPlatformVelocity(state#scene) {
            case None => state
            case Some(platformVx) =>
                let shift: Vec2.Vec2 = {x = platformVx * dt, y = 0.0f32};
                let scene1 = Scene.mapAt("player" :: Nil, node -> match node {
                    case GameNode.Player(r) =>
                        let currentPos = Node2D.getPosition(r#body);
                        let newBody = Node2D.setPosition(Vec2.add(currentPos, shift), r#body);
                        GameNode.Player({body = newBody})
                    case other => other
                }, state#scene);
                let scene2 = Scene.mapAt("playerTarget" :: Nil, node -> match node {
                    case GameNode.Marker2DNode(m) =>
                        let pos = Node2D.getPosition(m);
                        GameNode.Marker2DNode(Node2D.setPosition(Vec2.add(pos, shift), m))
                    case other => other
                }, scene1);
                {scene = scene2 | state}
        }

    // ========================================================================
    // 死亡判定
    // ========================================================================

    def playDeathAnim(color: Color, scene: Scene[GameNode]): Scene[GameNode] =
        Scene.mapAt("player" :: "Sprite" :: Nil, node -> match node {
            case GameNode.AnimSpriteNode(sprite) =>
                GameNode.AnimSpriteNode(
                    sprite
                        |> AnimatedSprite2D.play("dead")
                        |> CanvasItem.setModulate(color))
            case other => other
        }, scene)

    /// deathTimer を開始するヘルパー
    def startDeathTimer(scene: Scene[GameNode]): Scene[GameNode] =
        Scene.mapAt("deathTimer" :: Nil, node -> match node {
            case GameNode.TimerNode(timer) =>
                GameNode.TimerNode(Timer.start(timer))
            case other => other
        }, scene)

    pub def checkDeath(state: GameState): GameState =
        match Scene.getAt("player" :: "Sprite" :: Nil, state#scene) {
            case Some(GameNode.AnimSpriteNode(sprite)) =>
                let color = CanvasItem.getModulate(sprite);
                if (color#g < 0.5f32 and not state#isDead) {
                    let newScene = playDeathAnim({r = 1.0f32, g = 0.2f32, b = 0.2f32}, state#scene)
                        |> startDeathTimer;
                    {isDead = true, scene = newScene | state}
                } else
                    state
            case _ => state
        }

    pub def checkDrown(state: GameState): GameState =
        if (state#isDead) state
        else {
            let target = getPlayerTarget(state#scene);
            let playerPos = Scene.globalPosition("player", state#scene);
            let arrived = Vec2.distanceTo(playerPos, target) < 2.0f32;
            let inWater = target#y >= waterZoneY() and target#y < waterZoneY() + waterZoneH();
            if (arrived and inWater) {
                match findPlatformVelocity(state#scene) {
                    case Some(_) => state
                    case None =>
                        let newScene = playDeathAnim({r = 0.2f32, g = 0.2f32, b = 1.0f32}, state#scene)
                            |> startDeathTimer;
                        {isDead = true, scene = newScene | state}
                }
            } else
                state
        }

    // ========================================================================
    // 死亡タイマー・リスポーン・ゲームタイマー
    // ========================================================================

    def respawnPlayer(state: GameState): GameState =
        let scene1 = Scene.mapAt("player" :: Nil, node -> match node {
            case GameNode.Player(r) =>
                GameNode.Player({body = Node2D.setPosition(playerStart(), r#body)})
            case other => other
        }, state#scene);
        let scene1b = Scene.mapAt("playerTarget" :: Nil, node -> match node {
            case GameNode.Marker2DNode(m) =>
                GameNode.Marker2DNode(Node2D.setPosition(playerStart(), m))
            case other => other
        }, scene1);
        let scene2 = Scene.mapAt("player" :: "Sprite" :: Nil, node -> match node {
            case GameNode.AnimSpriteNode(sprite) =>
                GameNode.AnimSpriteNode(
                    sprite
                        |> AnimatedSprite2D.play("idle")
                        |> CanvasItem.setModulate({r = 1.0f32, g = 1.0f32, b = 1.0f32})
                        |> Node2D.setRotation(0.0))
            case other => other
        }, scene1b);
        // ゲームタイマーをリスタート
        let scene3 = Scene.mapAt("gameTimer" :: Nil, node -> match node {
            case GameNode.TimerNode(timer) =>
                GameNode.TimerNode(Timer.start(timer))
            case other => other
        }, scene2);
        {
            scene = scene3,
            isDead = false,
            lives = state#lives - 1
            | state
        }

    /// 死亡タイマーを更新し、タイマー切れでリスポーンする
    /// Timer ノードの process が dt を減算するため、dt パラメータ不要
    pub def updateDeathTimer(state: GameState): GameState =
        if (not state#isDead) state
        else {
            match Scene.get("deathTimer", state#scene) {
                case Some(GameNode.TimerNode(timer)) =>
                    if (Timer.getTimeLeft(timer) <= 0.0f32 and Timer.isStopped(timer))
                        respawnPlayer(state)
                    else
                        state
                case _ => state
            }
        }

    /// ゲームタイマーを更新し、タイマー切れで死亡する
    /// Timer ノードの process が dt を減算するため、dt パラメータ不要
    pub def updateGameTimer(state: GameState): GameState =
        if (state#isDead) state
        else {
            match Scene.get("gameTimer", state#scene) {
                case Some(GameNode.TimerNode(timer)) =>
                    if (Timer.getTimeLeft(timer) <= 0.0f32 and Timer.isStopped(timer)) {
                        let newScene = playDeathAnim({r = 1.0f32, g = 1.0f32, b = 0.2f32}, state#scene)
                            |> startDeathTimer;
                        {isDead = true, scene = newScene | state}
                    } else
                        state
                case _ => state
            }
        }

    pub def isGameOver(state: GameState): Bool =
        state#lives <= 0

    pub def resetGame(fontAtlas: FontAtlas): GameState =
        initGameState(fontAtlas)

    // ========================================================================
    // HUD 更新
    // ========================================================================

    /// Timer / lives の値を Label2D テキストに反映する
    pub def updateHUD(state: GameState): GameState =
        let timeInt = match Scene.get("gameTimer", state#scene) {
            case Some(GameNode.TimerNode(timer)) =>
                Float64.truncateToInt32(Float32.toFloat64(Float32.max(0.0f32, Timer.getTimeLeft(timer))))
            case _ => 0
        };
        let scene1 = Scene.mapAt("timerLabel" :: Nil, node -> match node {
            case GameNode.Label2DNode(label) =>
                GameNode.Label2DNode(Label2D.setText("TIME: ${timeInt}", label))
            case other => other
        }, state#scene);
        let scene2 = Scene.mapAt("livesLabel" :: Nil, node -> match node {
            case GameNode.Label2DNode(label) =>
                GameNode.Label2DNode(Label2D.setText("LIVES: ${state#lives}", label))
            case other => other
        }, scene1);
        {scene = scene2 | state}

    // ========================================================================
    // シーン構築
    // ========================================================================

}

// ========================================================================
// ボイラープレート（trait 委譲）
// ========================================================================

instance CanvasItem[GameNode] {
    pub def isVisible(node: GameNode): Bool = match node {
        case GameNode.Player(r) => CanvasItem.isVisible(r#body)
        case GameNode.AnimSpriteNode(sprite) => CanvasItem.isVisible(sprite)
        case GameNode.SpriteNode(sprite) => CanvasItem.isVisible(sprite)
        case GameNode.Marker2DNode(marker) => CanvasItem.isVisible(marker)
        case GameNode.TimerNode(timer) => CanvasItem.isVisible(timer)
        case GameNode.Label2DNode(label) => CanvasItem.isVisible(label)
        case _ => CanvasItem.isVisible(Game.getArea(node))
    }
    pub def setVisible(visible: Bool, node: GameNode): GameNode = match node {
        case GameNode.Player(r) =>
            GameNode.Player({body = CanvasItem.setVisible(visible, r#body)})
        case GameNode.AnimSpriteNode(sprite) => GameNode.AnimSpriteNode(CanvasItem.setVisible(visible, sprite))
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(CanvasItem.setVisible(visible, sprite))
        case GameNode.Marker2DNode(marker) => GameNode.Marker2DNode(CanvasItem.setVisible(visible, marker))
        case GameNode.TimerNode(timer) => GameNode.TimerNode(CanvasItem.setVisible(visible, timer))
        case GameNode.Label2DNode(label) => GameNode.Label2DNode(CanvasItem.setVisible(visible, label))
        case _ => Game.mapArea(area -> CanvasItem.setVisible(visible, area), node)
    }
    pub def getModulate(node: GameNode): Color = match node {
        case GameNode.Player(r) => CanvasItem.getModulate(r#body)
        case GameNode.AnimSpriteNode(sprite) => CanvasItem.getModulate(sprite)
        case GameNode.SpriteNode(sprite) => CanvasItem.getModulate(sprite)
        case GameNode.Marker2DNode(marker) => CanvasItem.getModulate(marker)
        case GameNode.TimerNode(timer) => CanvasItem.getModulate(timer)
        case GameNode.Label2DNode(label) => CanvasItem.getModulate(label)
        case _ => CanvasItem.getModulate(Game.getArea(node))
    }
    pub def setModulate(color: Color, node: GameNode): GameNode = match node {
        case GameNode.Player(r) =>
            GameNode.Player({body = CanvasItem.setModulate(color, r#body)})
        case GameNode.AnimSpriteNode(sprite) => GameNode.AnimSpriteNode(CanvasItem.setModulate(color, sprite))
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(CanvasItem.setModulate(color, sprite))
        case GameNode.Marker2DNode(marker) => GameNode.Marker2DNode(CanvasItem.setModulate(color, marker))
        case GameNode.TimerNode(timer) => GameNode.TimerNode(CanvasItem.setModulate(color, timer))
        case GameNode.Label2DNode(label) => GameNode.Label2DNode(CanvasItem.setModulate(color, label))
        case _ => Game.mapArea(area -> CanvasItem.setModulate(color, area), node)
    }
    pub def getZIndex(node: GameNode): Int32 = match node {
        case GameNode.Player(r) => CanvasItem.getZIndex(r#body)
        case GameNode.AnimSpriteNode(sprite) => CanvasItem.getZIndex(sprite)
        case GameNode.SpriteNode(sprite) => CanvasItem.getZIndex(sprite)
        case GameNode.Marker2DNode(marker) => CanvasItem.getZIndex(marker)
        case GameNode.TimerNode(timer) => CanvasItem.getZIndex(timer)
        case GameNode.Label2DNode(label) => CanvasItem.getZIndex(label)
        case _ => CanvasItem.getZIndex(Game.getArea(node))
    }
    pub def setZIndex(zIndex: Int32, node: GameNode): GameNode = match node {
        case GameNode.Player(r) =>
            GameNode.Player({body = CanvasItem.setZIndex(zIndex, r#body)})
        case GameNode.AnimSpriteNode(sprite) => GameNode.AnimSpriteNode(CanvasItem.setZIndex(zIndex, sprite))
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(CanvasItem.setZIndex(zIndex, sprite))
        case GameNode.Marker2DNode(marker) => GameNode.Marker2DNode(CanvasItem.setZIndex(zIndex, marker))
        case GameNode.TimerNode(timer) => GameNode.TimerNode(CanvasItem.setZIndex(zIndex, timer))
        case GameNode.Label2DNode(label) => GameNode.Label2DNode(CanvasItem.setZIndex(zIndex, label))
        case _ => Game.mapArea(area -> CanvasItem.setZIndex(zIndex, area), node)
    }
}

instance Node2D[GameNode] {
    pub def getPosition(node: GameNode): Vec2.Vec2 = match node {
        case GameNode.Player(r) => Node2D.getPosition(r#body)
        case GameNode.AnimSpriteNode(sprite) => Node2D.getPosition(sprite)
        case GameNode.SpriteNode(sprite) => Node2D.getPosition(sprite)
        case GameNode.Marker2DNode(marker) => Node2D.getPosition(marker)
        case GameNode.TimerNode(timer) => Node2D.getPosition(timer)
        case GameNode.Label2DNode(label) => Node2D.getPosition(label)
        case _ => Node2D.getPosition(Game.getArea(node))
    }
    pub def setPosition(position: Vec2.Vec2, node: GameNode): GameNode = match node {
        case GameNode.Player(r) =>
            GameNode.Player({body = Node2D.setPosition(position, r#body)})
        case GameNode.AnimSpriteNode(sprite) => GameNode.AnimSpriteNode(Node2D.setPosition(position, sprite))
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(Node2D.setPosition(position, sprite))
        case GameNode.Marker2DNode(marker) => GameNode.Marker2DNode(Node2D.setPosition(position, marker))
        case GameNode.TimerNode(timer) => GameNode.TimerNode(Node2D.setPosition(position, timer))
        case GameNode.Label2DNode(label) => GameNode.Label2DNode(Node2D.setPosition(position, label))
        case _ => Game.mapArea(area -> Node2D.setPosition(position, area), node)
    }
    pub def getRotation(node: GameNode): Float64 = match node {
        case GameNode.Player(r) => Node2D.getRotation(r#body)
        case GameNode.AnimSpriteNode(sprite) => Node2D.getRotation(sprite)
        case GameNode.SpriteNode(sprite) => Node2D.getRotation(sprite)
        case GameNode.Marker2DNode(marker) => Node2D.getRotation(marker)
        case GameNode.TimerNode(timer) => Node2D.getRotation(timer)
        case GameNode.Label2DNode(label) => Node2D.getRotation(label)
        case _ => Node2D.getRotation(Game.getArea(node))
    }
    pub def setRotation(rotation: Float64, node: GameNode): GameNode = match node {
        case GameNode.Player(r) =>
            GameNode.Player({body = Node2D.setRotation(rotation, r#body)})
        case GameNode.AnimSpriteNode(sprite) => GameNode.AnimSpriteNode(Node2D.setRotation(rotation, sprite))
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(Node2D.setRotation(rotation, sprite))
        case GameNode.Marker2DNode(marker) => GameNode.Marker2DNode(Node2D.setRotation(rotation, marker))
        case GameNode.TimerNode(timer) => GameNode.TimerNode(Node2D.setRotation(rotation, timer))
        case GameNode.Label2DNode(label) => GameNode.Label2DNode(Node2D.setRotation(rotation, label))
        case _ => Game.mapArea(area -> Node2D.setRotation(rotation, area), node)
    }
    pub def getScale(node: GameNode): Vec2.Vec2 = match node {
        case GameNode.Player(r) => Node2D.getScale(r#body)
        case GameNode.AnimSpriteNode(sprite) => Node2D.getScale(sprite)
        case GameNode.SpriteNode(sprite) => Node2D.getScale(sprite)
        case GameNode.Marker2DNode(marker) => Node2D.getScale(marker)
        case GameNode.TimerNode(timer) => Node2D.getScale(timer)
        case GameNode.Label2DNode(label) => Node2D.getScale(label)
        case _ => Node2D.getScale(Game.getArea(node))
    }
    pub def setScale(scale: Vec2.Vec2, node: GameNode): GameNode = match node {
        case GameNode.Player(r) =>
            GameNode.Player({body = Node2D.setScale(scale, r#body)})
        case GameNode.AnimSpriteNode(sprite) => GameNode.AnimSpriteNode(Node2D.setScale(scale, sprite))
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(Node2D.setScale(scale, sprite))
        case GameNode.Marker2DNode(marker) => GameNode.Marker2DNode(Node2D.setScale(scale, marker))
        case GameNode.TimerNode(timer) => GameNode.TimerNode(Node2D.setScale(scale, timer))
        case GameNode.Label2DNode(label) => GameNode.Label2DNode(Node2D.setScale(scale, label))
        case _ => Game.mapArea(area -> Node2D.setScale(scale, area), node)
    }
    pub def getSkew(node: GameNode): Float64 = match node {
        case GameNode.Player(r) => Node2D.getSkew(r#body)
        case GameNode.AnimSpriteNode(sprite) => Node2D.getSkew(sprite)
        case GameNode.SpriteNode(sprite) => Node2D.getSkew(sprite)
        case GameNode.Marker2DNode(marker) => Node2D.getSkew(marker)
        case GameNode.TimerNode(timer) => Node2D.getSkew(timer)
        case GameNode.Label2DNode(label) => Node2D.getSkew(label)
        case _ => Node2D.getSkew(Game.getArea(node))
    }
    pub def setSkew(skew: Float64, node: GameNode): GameNode = match node {
        case GameNode.Player(r) =>
            GameNode.Player({body = Node2D.setSkew(skew, r#body)})
        case GameNode.AnimSpriteNode(sprite) => GameNode.AnimSpriteNode(Node2D.setSkew(skew, sprite))
        case GameNode.SpriteNode(sprite) => GameNode.SpriteNode(Node2D.setSkew(skew, sprite))
        case GameNode.Marker2DNode(marker) => GameNode.Marker2DNode(Node2D.setSkew(skew, marker))
        case GameNode.TimerNode(timer) => GameNode.TimerNode(Node2D.setSkew(skew, timer))
        case GameNode.Label2DNode(label) => GameNode.Label2DNode(Node2D.setSkew(skew, label))
        case _ => Game.mapArea(area -> Node2D.setSkew(skew, area), node)
    }
}

instance CollisionObject2D[GameNode] {
    pub def getCollisionShape(node: GameNode): Option[CollisionShape2D] = match node {
        case GameNode.Player(_) => None
        case GameNode.AnimSpriteNode(_) => None
        case GameNode.SpriteNode(_) => None
        case GameNode.Marker2DNode(_) => None
        case GameNode.TimerNode(_) => None
        case GameNode.Label2DNode(_) => None
        case _ => CollisionObject2D.getCollisionShape(Game.getArea(node))
    }
    pub def isMonitoring(node: GameNode): Bool = match node {
        case GameNode.Player(_) => false
        case GameNode.AnimSpriteNode(_) => false
        case GameNode.SpriteNode(_) => false
        case GameNode.Marker2DNode(_) => false
        case GameNode.TimerNode(_) => false
        case GameNode.Label2DNode(_) => false
        case _ => CollisionObject2D.isMonitoring(Game.getArea(node))
    }
    pub def isMonitorable(node: GameNode): Bool = match node {
        case GameNode.Player(_) => false
        case GameNode.AnimSpriteNode(_) => false
        case GameNode.SpriteNode(_) => false
        case GameNode.Marker2DNode(_) => false
        case GameNode.TimerNode(_) => false
        case GameNode.Label2DNode(_) => false
        case _ => CollisionObject2D.isMonitorable(Game.getArea(node))
    }
    redef getCollisionPriority(node: GameNode): Int32 = match node {
        case GameNode.Player(_) => 0
        case GameNode.AnimSpriteNode(_) => 0
        case GameNode.SpriteNode(_) => 0
        case GameNode.Marker2DNode(_) => 0
        case GameNode.TimerNode(_) => 0
        case GameNode.Label2DNode(_) => 0
        case _ => CollisionObject2D.getCollisionPriority(Game.getArea(node))
    }
}

instance Engine.Renderable[GameNode] {
    pub def toDrawables(node: GameNode, globalPos: Vec2.Vec2): List[Engine.Drawable] =
        match node {
            case GameNode.SpriteNode(sprite) => Game.spriteToDrawable(sprite, globalPos) :: Nil
            case GameNode.AnimSpriteNode(sprite) => Game.animSpriteToDrawable(sprite, globalPos) :: Nil
            case GameNode.Label2DNode(label) => Label2D.toDrawables(label, globalPos)
            case _ => Scene.toDrawable("white", node, globalPos) :: Nil
        }
}
