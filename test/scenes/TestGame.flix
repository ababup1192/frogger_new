// Tests for Frogger Game module

// ========================================================================
// テスト用ヘルパー
// ========================================================================

/// テスト用のダミー FontAtlas（空のグリフマップ）
def testFontAtlas(): FontAtlas = {
    textureName = "font_test",
    fontSize = 32.0f32,
    textureSize = 512.0f32,
    glyphs = Map.empty()
}

// ========================================================================
// buildScene: ノード数・構造
// ========================================================================

/// ノード合計
///   背景5 + ホーム5(+sprites=10) + プレイヤー1(+Sprite+Hitbox=3)
///   + playerTarget1 + 車両15(+sprite=30) + 丸太12(+sprites=46) + 亀5(+sprites=22)
///   + gameTimer1 + deathTimer1 + timerLabel1 + livesLabel1 = 121
@Test
def testBuildSceneNodeCount(): Unit \ Assert =
    Assert.assertEq(expected = 121, Scene.nodeCount(Game.buildScene(testFontAtlas())))

/// ルートノード = 背景5 + ホーム5 + プレイヤー1 + playerTarget1 + 車両15 + 丸太12 + 亀5
///   + gameTimer1 + deathTimer1 + timerLabel1 + livesLabel1 = 48
@Test
def testBuildSceneRootCount(): Unit \ Assert =
    Assert.assertEq(expected = 48, Map.size(Scene.nodes(Game.buildScene(testFontAtlas()))))

// ========================================================================
// buildScene: プレイヤー構成 (CharacterBody2D + AnimatedSprite2D + Hitbox)
// ========================================================================

/// プレイヤーの初期位置が (384, 832)
@Test
def testPlayerInitialPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("player", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = (384.0f32, 832.0f32), (pos#x, pos#y))

/// プレイヤー（CharacterBody2D）は不可視（描画は子スプライトが担当）
@Test
def testPlayerIsInvisible(): Unit \ Assert =
    match Scene.get("player", Game.buildScene(testFontAtlas())) {
        case Some(node) => Assert.assertFalse(CanvasItem.isVisible(node))
        case None => bug!("player not found")
    }

/// プレイヤーの子は Sprite と Hitbox の 2 つ
@Test
def testPlayerChildrenCount(): Unit \ Assert =
    Assert.assertEq(
        expected = 2,
        List.length(Scene.getChildren("player", Game.buildScene(testFontAtlas()))))

/// Sprite 子ノードは AnimatedSprite2D で、idle アニメーションの最初のフレームは FroggerIdle
@Test
def testPlayerSpriteAnimation(): Unit \ Assert =
    match Scene.getAt("player" :: "Sprite" :: Nil, Game.buildScene(testFontAtlas())) {
        case Some(GameNode.AnimSpriteNode(sprite)) =>
            Assert.assertEq(
                expected = ("idle", "FroggerIdle"),
                (AnimatedSprite2D.getCurrentAnimation(sprite),
                 AnimatedSprite2D.currentTexture(sprite)))
        case _ => bug!("player Sprite not found")
    }

/// Hitbox 子ノードは Area2D で、monitoring=true（Vehicle と衝突検出）
@Test
def testPlayerHitboxMonitoring(): Unit \ Assert =
    match Scene.getAt("player" :: "Hitbox" :: Nil, Game.buildScene(testFontAtlas())) {
        case Some(node) => Assert.assertTrue(CollisionObject2D.isMonitoring(node))
        case None => bug!("player Hitbox not found")
    }

// ========================================================================
// buildScene: 背景ゾーン配置
// ========================================================================

/// 水ゾーン背景の位置が (0, 64)
@Test
def testBgWaterPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("bgWater", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = (0.0f32, 64.0f32), (pos#x, pos#y))

/// 道路ゾーン背景の位置が (0, 512)
@Test
def testBgRoadPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("bgRoad", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = (0.0f32, 512.0f32), (pos#x, pos#y))

/// 中央分離帯背景の位置が (0, 448)
@Test
def testBgMedianPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("bgMedian", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = (0.0f32, 448.0f32), (pos#x, pos#y))

// ========================================================================
// buildScene: 車両配置
// ========================================================================

/// レーン0の最初の車両が Y=512 に配置される
@Test
def testVehicleLane0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("v0_0", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = 512.0f32, pos#y)

/// レーン0の2台目の車両は spacing=100 で 164px 先
///   startX = 1 * (64 + 100) = 164
@Test
def testVehicleLane0SecondPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("v0_1", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = (164.0f32, 512.0f32), (pos#x, pos#y))

// ========================================================================
// buildScene: 丸太配置
// ========================================================================

/// レーン0の最初の丸太が Y=64 に配置される
@Test
def testLogLane0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("l0_0", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = 64.0f32, pos#y)

/// レーン0の丸太は middles=1 なので 3 つの子スプライト（LogStart + LogMiddle + LogEnd）
@Test
def testLogLane0SpriteCount(): Unit \ Assert =
    Assert.assertEq(
        expected = 3,
        List.length(Scene.getChildren("l0_0", Game.buildScene(testFontAtlas()))))

/// 丸太のプラットフォームは monitoring/monitorable=false（手動判定）
@Test
def testLogNotMonitoring(): Unit \ Assert =
    match Scene.get("l0_0", Game.buildScene(testFontAtlas())) {
        case Some(node) =>
            Assert.assertEq(
                expected = (false, false),
                (CollisionObject2D.isMonitoring(node), CollisionObject2D.isMonitorable(node)))
        case None => bug!("log l0_0 not found")
    }

// ========================================================================
// Player process: ターゲットへの移動
// ========================================================================

/// Vec2 を比較可能なタプルに変換するヘルパー
def vecToTuple(v: Vec2.Vec2): (Float32, Float32) = (v#x, v#y)

/// process でプレイヤーが playerTarget（Marker2D）に向かって移動する
///   moveSpeed=512, dt=0.1 → 51.2px 移動。832-51.2=780.8
@Test
def testPlayerProcessMovesTowardTarget(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    // ターゲットを上に設定
    let scene1 = Scene.mapAt("playerTarget" :: Nil, node -> match node {
        case GameNode.Marker2DNode(m) =>
            GameNode.Marker2DNode(Node2D.setPosition({x = 384.0f32, y = 768.0f32}, m))
        case other => other
    }, state#scene);
    let processed = Scene.processAll(0.1, false, scene1);
    let pos = Scene.globalPosition("player", processed);
    Assert.assertEq(expected = (384.0f32, 780.8f32), vecToTuple(pos))

/// ターゲットが現在位置と同じ場合、移動しない
@Test
def testPlayerProcessStaysAtTarget(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let processed = Scene.processAll(0.1, false, state#scene);
    let pos = Scene.globalPosition("player", processed);
    Assert.assertEq(expected = (384.0f32, 832.0f32), vecToTuple(pos))

// ========================================================================
// AnimatedSprite2D process: フレーム進行
// ========================================================================

/// fps=4 で 0.3 秒後（frameDuration=0.25 超過）にフレームが 1 に進む
@Test
def testAnimSpriteAdvancesFrame(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let processed = Scene.processAll(0.3, false, state#scene);
    match Scene.getAt("player" :: "Sprite" :: Nil, processed) {
        case Some(GameNode.AnimSpriteNode(sprite)) =>
            Assert.assertEq(expected = "FroggerLeap", AnimatedSprite2D.currentTexture(sprite))
        case _ => bug!("player Sprite not found after process")
    }

// ========================================================================
// Vehicle process: 移動とラップ
// ========================================================================

/// Vehicle が process で vx * dt 分移動する
@Test
def testVehicleProcessMoves(): Unit \ Assert =
    let scene = Game.buildScene(testFontAtlas());
    let origPos = Scene.globalPosition("v0_0", scene);
    let processed = Scene.processAll(0.1, false, scene);
    let newPos = Scene.globalPosition("v0_0", processed);
    Assert.assertEq(
        expected = (origPos#x - 20.0f32, origPos#y),
        (newPos#x, newPos#y))

/// Vehicle が画面左端を超えたら右端にラップする
@Test
def testVehicleWrapsLeft(): Unit \ Assert =
    let scene = Game.buildScene(testFontAtlas())
        |> Scene.setGlobalPosition("v0_0", {x = -99.0f32, y = 512.0f32});
    let processed = Scene.processAll(0.1, false, scene);
    let newPos = Scene.globalPosition("v0_0", processed);
    Assert.assertEq(expected = Game.screenW() + 100.0f32, newPos#x)

// ========================================================================
// LogPlatform process: 移動とラップ
// ========================================================================

/// LogPlatform が process で vx * dt 分移動する
@Test
def testLogProcessMoves(): Unit \ Assert =
    let scene = Game.buildScene(testFontAtlas());
    let origPos = Scene.globalPosition("l0_0", scene);
    // Lane 0: vx=120, dt=0.1 → +12px
    let processed = Scene.processAll(0.1, false, scene);
    let newPos = Scene.globalPosition("l0_0", processed);
    Assert.assertEq(
        expected = (origPos#x + 12.0f32, origPos#y),
        (newPos#x, newPos#y))

// ========================================================================
// buildScene: 亀配置
// ========================================================================

/// 亀レーン0の最初のグループが Y=320 に配置される
@Test
def testTurtleLane0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("t0_0", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = 320.0f32, pos#y)

/// 亀レーン0のグループは sections=3 なので 3 つの子スプライト
@Test
def testTurtleLane0SpriteCount(): Unit \ Assert =
    Assert.assertEq(
        expected = 3,
        List.length(Scene.getChildren("t0_0", Game.buildScene(testFontAtlas()))))

/// 亀プラットフォームは monitoring/monitorable=false（手動判定）
@Test
def testTurtleNotMonitoring(): Unit \ Assert =
    match Scene.get("t0_0", Game.buildScene(testFontAtlas())) {
        case Some(node) =>
            Assert.assertEq(
                expected = (false, false),
                (CollisionObject2D.isMonitoring(node), CollisionObject2D.isMonitorable(node)))
        case None => bug!("turtle t0_0 not found")
    }

// ========================================================================
// TurtlePlatform process: 移動とラップ
// ========================================================================

/// TurtlePlatform が process で vx * dt 分移動する
@Test
def testTurtleProcessMoves(): Unit \ Assert =
    let scene = Game.buildScene(testFontAtlas());
    let origPos = Scene.globalPosition("t0_0", scene);
    // Lane 0: vx=100, dt=0.1 → +10px
    let processed = Scene.processAll(0.1, false, scene);
    let newPos = Scene.globalPosition("t0_0", processed);
    Assert.assertEq(
        expected = (origPos#x + 10.0f32, origPos#y),
        (newPos#x, newPos#y))

// ========================================================================
// applyInput: ターゲット更新
// ========================================================================

/// 上方向入力でターゲットが 64px 上に移動する
///   初期: (384, 832) → (384, 768)
@Test
def testApplyInputUp(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let newState = Game.applyInput(Some(Vec2.up()), state);
    let target = Game.getPlayerTarget(newState#scene);
    Assert.assertEq(expected = (384.0f32, 768.0f32), vecToTuple(target))

/// 下方向は 832 でクランプされ移動しない
@Test
def testApplyInputClampDown(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let newState = Game.applyInput(Some(Vec2.down()), state);
    let target = Game.getPlayerTarget(newState#scene);
    Assert.assertEq(expected = (384.0f32, 832.0f32), vecToTuple(target))

/// None 入力は状態を変更しない
@Test
def testApplyInputNone(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let newState = Game.applyInput(None, state);
    let target = Game.getPlayerTarget(newState#scene);
    Assert.assertEq(
        expected = vecToTuple(Game.playerStart()),
        vecToTuple(target))

// ========================================================================
// justPressedKeys: エッジ検出
// ========================================================================

/// 前フレームになかったキーだけが返る
@Test
def testJustPressedKeysEdgeDetect(): Unit \ Assert =
    let prev = Set#{Engine.Key.W};
    let curr = Set#{Engine.Key.W, Engine.Key.D};
    Assert.assertEq(
        expected = Set#{Engine.Key.D},
        Game.justPressedKeys(curr, prev))

/// 前フレームと同じキーの場合は空集合
@Test
def testJustPressedKeysNoChange(): Unit \ Assert =
    let keys = Set#{Engine.Key.W};
    Assert.assertEq(
        expected = (Set.empty(): Set[Engine.Key]),
        Game.justPressedKeys(keys, keys))

// ========================================================================
// inputDirection: キーから方向ベクトルへの変換
// ========================================================================

/// W キーで上方向 (0, -1)
@Test
def testInputDirectionUp(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.W}));
    Assert.assertEq(expected = (0.0f32, -1.0f32), vecToTuple(dir))

/// S キーで下方向 (0, 1)
@Test
def testInputDirectionDown(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.S}));
    Assert.assertEq(expected = (0.0f32, 1.0f32), vecToTuple(dir))

/// A キーで左方向 (-1, 0)
@Test
def testInputDirectionLeft(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.A}));
    Assert.assertEq(expected = (-1.0f32, 0.0f32), vecToTuple(dir))

/// D キーで右方向 (1, 0)
@Test
def testInputDirectionRight(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.D}));
    Assert.assertEq(expected = (1.0f32, 0.0f32), vecToTuple(dir))

/// 矢印キー Up も上方向を返す
@Test
def testInputDirectionArrowUp(): Unit \ Assert =
    let dir = Option.getWithDefault(Vec2.zero(), Game.inputDirection(Set#{Engine.Key.Up}));
    Assert.assertEq(expected = (0.0f32, -1.0f32), vecToTuple(dir))

/// キーなしで None（sentinel 99 が返る）
@Test
def testInputDirectionNone(): Unit \ Assert =
    let sentinel: Vec2.Vec2 = {x = 99.0f32, y = 99.0f32};
    let dir = Option.getWithDefault(sentinel, Game.inputDirection(Set.empty()));
    Assert.assertEq(expected = (99.0f32, 99.0f32), vecToTuple(dir))

// ========================================================================
// directionToRotation
// ========================================================================

/// 上方向は 0 ラジアン
@Test
def testDirectionToRotationUp(): Unit \ Assert =
    Assert.assertEq(expected = 0.0, Game.directionToRotation(Vec2.up()))

/// 下方向は π ラジアン
@Test
def testDirectionToRotationDown(): Unit \ Assert =
    Assert.assertEq(expected = 3.1415926535898, Game.directionToRotation(Vec2.down()))

// ========================================================================
// checkDeath: 衝突死亡判定
// ========================================================================

/// スプライトが赤色のとき isDead=true に変わり deathTimer が開始される
@Test
def testCheckDeathDetectsRed(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let redScene = Scene.mapAt("player" :: "Sprite" :: Nil, node -> match node {
        case GameNode.AnimSpriteNode(sprite) =>
            GameNode.AnimSpriteNode(CanvasItem.setModulate({r = 1.0f32, g = 0.2f32, b = 0.2f32}, sprite))
        case other => other
    }, state#scene);
    let deadState = Game.checkDeath({scene = redScene | state});
    // isDead=true かつ deathTimer が running
    let timerRunning = match Scene.get("deathTimer", deadState#scene) {
        case Some(GameNode.TimerNode(timer)) => Timer.isRunning(timer)
        case _ => false
    };
    Assert.assertEq(expected = (true, true), (deadState#isDead, timerRunning))

/// 通常色のスプライトでは isDead は変わらない
@Test
def testCheckDeathNormalColor(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let checkedState = Game.checkDeath(state);
    Assert.assertFalse(checkedState#isDead)

// ========================================================================
// checkDrown: 溺死判定
// ========================================================================

/// 水ゾーンにいてプラットフォーム上にいないとき溺死
///   丸太(y=64-256) + 亀(y=320-384) の Y 範囲は [32,416]
///   y=430 は全プラットフォームの Y 範囲外で水ゾーン内 (64 ≤ 430 < 448)
@Test
def testCheckDrownInWater(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let waterPos: Vec2.Vec2 = {x = 384.0f32, y = 430.0f32};
    let scene1 = Scene.setGlobalPosition("player", waterPos, state#scene)
        |> Scene.mapAt("player" :: Nil, node -> match node {
            case GameNode.Player(r) =>
                GameNode.Player({body = Node2D.setPosition(waterPos, r#body)})
            case other => other
        })
        |> Scene.mapAt("playerTarget" :: Nil, node -> match node {
            case GameNode.Marker2DNode(m) =>
                GameNode.Marker2DNode(Node2D.setPosition(waterPos, m))
            case other => other
        });
    let drownState = Game.checkDrown({scene = scene1 | state});
    Assert.assertTrue(drownState#isDead)

/// 道路ゾーンにいるときは溺死しない
@Test
def testCheckDrownNotInWater(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let checkedState = Game.checkDrown(state);
    Assert.assertFalse(checkedState#isDead)

// ========================================================================
// buildScene: ホームスロット配置
// ========================================================================

/// 5 つのホームスロットが存在する
@Test
def testHomeSlotCount(): Unit \ Assert =
    let scene = Game.buildScene(testFontAtlas());
    let exists = List.forAll(idx ->
        not Option.isEmpty(Scene.get("home${idx}", scene)),
        List.range(0, 5));
    Assert.assertTrue(exists)

/// ホームスロット 0 の位置が (64, 0)
@Test
def testHomeSlot0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("home0", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = (64.0f32, 0.0f32), (pos#x, pos#y))

/// ホームスロット 2（中央）の位置が (384, 0)
@Test
def testHomeSlot2Position(): Unit \ Assert =
    let pos = Scene.globalPosition("home2", Game.buildScene(testFontAtlas()));
    Assert.assertEq(expected = (384.0f32, 0.0f32), (pos#x, pos#y))

/// 初期状態ではホームスロットは全て未充填
@Test
def testHomeSlotInitiallyUnfilled(): Unit \ Assert =
    let scene = Game.buildScene(testFontAtlas());
    Assert.assertFalse(Game.allHomesFilled(scene))

/// 各ホームスロットは子スプライトを 1 つ持つ
@Test
def testHomeSlotHasSprite(): Unit \ Assert =
    Assert.assertEq(
        expected = 1,
        List.length(Scene.getChildren("home0", Game.buildScene(testFontAtlas()))))

// ========================================================================
// tryFillHomeSlot: ホームスロット充填
// ========================================================================

/// プレイヤーがホームゾーン中央（x=384, y=0）に到達すると home2 が充填される
@Test
def testTryFillHomeSlotFills(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let homePos: Vec2.Vec2 = {x = 384.0f32, y = 0.0f32};
    let scene1 = state#scene
        |> Scene.mapAt("player" :: Nil, node -> match node {
            case GameNode.Player(r) =>
                GameNode.Player({body = Node2D.setPosition(homePos, r#body)})
            case other => other
        })
        |> Scene.mapAt("playerTarget" :: Nil, node -> match node {
            case GameNode.Marker2DNode(m) =>
                GameNode.Marker2DNode(Node2D.setPosition(homePos, m))
            case other => other
        });
    let filledState = Game.tryFillHomeSlot({scene = scene1 | state});
    // home2 が充填されている
    match Scene.get("home2", filledState#scene) {
        case Some(GameNode.HomeSlot(r)) => Assert.assertTrue(r#filled)
        case _ => bug!("home2 not found")
    }

/// ホームスロット充填後、プレイヤーがスタート位置にリセットされる
@Test
def testTryFillHomeSlotResetsPlayer(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let homePos: Vec2.Vec2 = {x = 384.0f32, y = 0.0f32};
    let scene1 = state#scene
        |> Scene.mapAt("player" :: Nil, node -> match node {
            case GameNode.Player(r) =>
                GameNode.Player({body = Node2D.setPosition(homePos, r#body)})
            case other => other
        })
        |> Scene.mapAt("playerTarget" :: Nil, node -> match node {
            case GameNode.Marker2DNode(m) =>
                GameNode.Marker2DNode(Node2D.setPosition(homePos, m))
            case other => other
        });
    let filledState = Game.tryFillHomeSlot({scene = scene1 | state});
    let pos = Scene.globalPosition("player", filledState#scene);
    Assert.assertEq(expected = (384.0f32, 832.0f32), (pos#x, pos#y))

/// ホームゾーンにいないとき tryFillHomeSlot は何もしない
@Test
def testTryFillHomeSlotNoOpInRoad(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let filledState = Game.tryFillHomeSlot(state);
    Assert.assertFalse(Game.allHomesFilled(filledState#scene))

/// 全5スロット充填で allHomesFilled が true を返す
@Test
def testAllHomesFilledWin(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    // 全スロットを手動で充填
    let scene1 = List.range(0, 5) |> List.foldLeft((acc, idx) ->
        Scene.mapAt("home${idx}" :: Nil, node -> match node {
            case GameNode.HomeSlot(r) =>
                GameNode.HomeSlot({filled = true | r})
            case other => other
        }, acc),
        state#scene);
    Assert.assertTrue(Game.allHomesFilled(scene1))

// ========================================================================
// applyTimeouts: 死亡タイマーとリスポーン
// ========================================================================

/// 死亡中に deathTimer の process で timeLeft が減少し、タイムアウト前は isDead のまま
@Test
def testApplyTimeoutsDeathTimerNotExpired(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    // deathTimer を手動開始して process で 0.5s 進める
    let scene1 = Scene.mapAt("deathTimer" :: Nil, node -> match node {
        case GameNode.TimerNode(timer) =>
            GameNode.TimerNode(Timer.start(timer))
        case other => other
    }, state#scene);
    let scene2 = Scene.processAll(0.5, false, scene1);
    let updated = Game.applyTimeouts({isDead = true, scene = scene2 | state});
    // 0.5s 後の timeLeft: 2.0 - 0.5 = 1.5（まだ running、timedOut=false）
    Assert.assertTrue(updated#isDead)

/// タイマーが 0 以下になるとリスポーンする（isDead=false, ライフ -1）
@Test
def testApplyTimeoutsDeathTimerRespawns(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    // deathTimer を手動開始し、大きな dt で process して timedOut=true にする
    let scene1 = Scene.mapAt("deathTimer" :: Nil, node -> match node {
        case GameNode.TimerNode(timer) =>
            GameNode.TimerNode(Timer.start(timer))
        case other => other
    }, state#scene);
    let scene2 = Scene.processAll(2.1, false, scene1);
    let updated = Game.applyTimeouts({isDead = true, scene = scene2 | state});
    Assert.assertEq(
        expected = (false, 2),
        (updated#isDead, updated#lives))

/// リスポーン後にプレイヤーがスタート位置に戻る
@Test
def testRespawnResetsPosition(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let scene1 = Scene.mapAt("deathTimer" :: Nil, node -> match node {
        case GameNode.TimerNode(timer) =>
            GameNode.TimerNode(Timer.start(timer))
        case other => other
    }, state#scene);
    let scene2 = Scene.processAll(2.1, false, scene1);
    let updated = Game.applyTimeouts({isDead = true, scene = scene2 | state});
    let pos = Scene.globalPosition("player", updated#scene);
    Assert.assertEq(expected = (384.0f32, 832.0f32), (pos#x, pos#y))

/// リスポーン後にスプライトが idle アニメーションに戻る
@Test
def testRespawnResetsAnimation(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let scene1 = Scene.mapAt("deathTimer" :: Nil, node -> match node {
        case GameNode.TimerNode(timer) =>
            GameNode.TimerNode(Timer.start(timer))
        case other => other
    }, state#scene);
    let scene2 = Scene.processAll(2.1, false, scene1);
    let updated = Game.applyTimeouts({isDead = true, scene = scene2 | state});
    match Scene.getAt("player" :: "Sprite" :: Nil, updated#scene) {
        case Some(GameNode.AnimSpriteNode(sprite)) =>
            Assert.assertEq(expected = "idle", AnimatedSprite2D.getCurrentAnimation(sprite))
        case _ => bug!("player Sprite not found after respawn")
    }

/// タイマーがタイムアウトしていないときは applyTimeouts は何もしない
@Test
def testApplyTimeoutsNoOpWhenNoTimeout(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let updated = Game.applyTimeouts(state);
    Assert.assertFalse(updated#isDead)

// ========================================================================
// applyTimeouts: ゲームタイマー
// ========================================================================

/// ゲームタイマーが process で減少する
@Test
def testGameTimerDecreases(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    // gameTimer は autostart=true なので readyAll 後は running
    let scene1 = Scene.readyAll(state#scene);
    let scene2 = Scene.processAll(1.0, false, scene1);
    match Scene.get("gameTimer", scene2) {
        case Some(GameNode.TimerNode(timer)) =>
            // 30.0 - 1.0 = 29.0
            Assert.assertEq(expected = 29.0f32, Timer.getTimeLeft(timer))
        case _ => bug!("gameTimer not found")
    }

/// ゲームタイマーが 0 以下になると applyTimeouts で isDead=true になる
@Test
def testApplyTimeoutsGameTimerDeath(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    // gameTimer を短い waitTime の Timer に置き換えて開始
    let shortTimer = Timer.make(0.5f32) |> Timer.setAutostart(true) |> Timer.ready;
    let scene1 = Scene.set("gameTimer", GameNode.TimerNode(shortTimer), state#scene);
    let scene2 = Scene.processAll(1.0, false, scene1);
    let updated = Game.applyTimeouts({scene = scene2 | state});
    Assert.assertTrue(updated#isDead)

/// 既に isDead=true のときゲームタイマーの timedOut は追加死亡しない
@Test
def testApplyTimeoutsGameTimerSkipsWhenDead(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let updated = Game.applyTimeouts({isDead = true | state});
    // isDead=true のまま（追加の状態変更なし）
    Assert.assertTrue(updated#isDead)

// ========================================================================
// Timer timedOut フラグ
// ========================================================================

/// Timer.process でタイムアウトすると timedOut=true になる
@Test
def testTimerTimedOutFlag(): Unit \ Assert =
    let timer = Timer.make(1.0f32) |> Timer.start;
    let processed = Timer.process(1.5f32, timer);
    Assert.assertTrue(Timer.isTimedOut(processed))

/// Timer.process でタイムアウトしなければ timedOut=false のまま
@Test
def testTimerNotTimedOut(): Unit \ Assert =
    let timer = Timer.make(2.0f32) |> Timer.start;
    let processed = Timer.process(0.5f32, timer);
    Assert.assertFalse(Timer.isTimedOut(processed))

/// Timer.clearTimedOut でフラグがクリアされる
@Test
def testTimerClearTimedOut(): Unit \ Assert =
    let timer = Timer.make(1.0f32) |> Timer.start;
    let processed = Timer.process(1.5f32, timer);
    let cleared = Timer.clearTimedOut(processed);
    Assert.assertFalse(Timer.isTimedOut(cleared))

/// handleTimeouts 後に timedOut フラグがクリアされる
@Test
def testHandleTimeoutsClearsFlag(): Unit \ Assert =
    let state = Game.initGameState(testFontAtlas());
    let shortTimer = Timer.make(0.5f32) |> Timer.setAutostart(true) |> Timer.ready;
    let scene1 = Scene.set("gameTimer", GameNode.TimerNode(shortTimer), state#scene);
    let scene2 = Scene.processAll(1.0, false, scene1);
    // processAll 後は timedOut=true のはず
    let timedOutPaths = TimerEvent.detectTimeoutPaths(scene2);
    let hasGameTimer = List.exists(p -> p == "gameTimer" :: Nil, timedOutPaths);
    // handleTimeouts で処理・クリア
    let scene3 = TimerEvent.handleTimeouts(scene2);
    let afterPaths = TimerEvent.detectTimeoutPaths(scene3);
    Assert.assertEq(expected = (true, Nil), (hasGameTimer, afterPaths))

// ========================================================================
// isGameOver / resetGame
// ========================================================================

/// ライフ 0 でゲームオーバー
@Test
def testIsGameOverTrue(): Unit \ Assert =
    let state = {lives = 0 | Game.initGameState(testFontAtlas())};
    Assert.assertTrue(Game.isGameOver(state))

/// ライフ残ありでゲームオーバーではない
@Test
def testIsGameOverFalse(): Unit \ Assert =
    Assert.assertFalse(Game.isGameOver(Game.initGameState(testFontAtlas())))

/// resetGame で初期状態に戻る
@Test
def testResetGame(): Unit \ Assert =
    let state = Game.resetGame(testFontAtlas());
    Assert.assertEq(expected = (3, false), (state#lives, state#isDead))

// ========================================================================
// Timer ノードの存在と初期値
// ========================================================================

/// gameTimer が存在し waitTime=30.0
@Test
def testGameTimerExists(): Unit \ Assert =
    match Scene.get("gameTimer", Game.buildScene(testFontAtlas())) {
        case Some(GameNode.TimerNode(timer)) =>
            Assert.assertEq(expected = 30.0f32, Timer.getTimeLeft(timer))
        case _ => bug!("gameTimer not found")
    }

/// deathTimer が存在し running=false
@Test
def testDeathTimerExists(): Unit \ Assert =
    match Scene.get("deathTimer", Game.buildScene(testFontAtlas())) {
        case Some(GameNode.TimerNode(timer)) =>
            Assert.assertFalse(Timer.isRunning(timer))
        case _ => bug!("deathTimer not found")
    }

// ========================================================================
// Label2D ノードの存在
// ========================================================================

/// timerLabel が存在する
@Test
def testTimerLabelExists(): Unit \ Assert =
    match Scene.get("timerLabel", Game.buildScene(testFontAtlas())) {
        case Some(GameNode.Label2DNode(_)) => Assert.assertTrue(true)
        case _ => bug!("timerLabel not found")
    }

/// livesLabel が存在する
@Test
def testLivesLabelExists(): Unit \ Assert =
    match Scene.get("livesLabel", Game.buildScene(testFontAtlas())) {
        case Some(GameNode.Label2DNode(_)) => Assert.assertTrue(true)
        case _ => bug!("livesLabel not found")
    }
