// Tests for Frogger Game module

// ========================================================================
// buildScene: ノード数・構造
// ========================================================================

/// ノード合計
///   背景5 + ホーム5(+sprites=10) + プレイヤー1(+Sprite+Hitbox=3)
///   + 車両15(+sprite=30) + 丸太12(+sprites=46) + 亀5(+sprites=22) = 116
@Test
def testBuildSceneNodeCount(): Unit \ Assert =
    Assert.assertEq(expected = 116, Scene.nodeCount(Game.buildScene()))

/// ルートノード = 背景5 + ホーム5 + プレイヤー1 + 車両15 + 丸太12 + 亀5 = 43
@Test
def testBuildSceneRootCount(): Unit \ Assert =
    Assert.assertEq(expected = 43, Map.size(Scene.nodes(Game.buildScene())))

// ========================================================================
// buildScene: プレイヤー構成 (CharacterBody2D + AnimatedSprite2D + Hitbox)
// ========================================================================

/// プレイヤーの初期位置が (384, 832)
@Test
def testPlayerInitialPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("player", Game.buildScene());
    Assert.assertEq(expected = (384.0f32, 832.0f32), (pos#x, pos#y))

/// プレイヤー（CharacterBody2D）は不可視（描画は子スプライトが担当）
@Test
def testPlayerIsInvisible(): Unit \ Assert =
    match Scene.get("player", Game.buildScene()) {
        case Some(node) => Assert.assertFalse(CanvasItem.isVisible(node))
        case None => bug!("player not found")
    }

/// プレイヤーの子は Sprite と Hitbox の 2 つ
@Test
def testPlayerChildrenCount(): Unit \ Assert =
    Assert.assertEq(
        expected = 2,
        List.length(Scene.getChildren("player", Game.buildScene())))

/// Sprite 子ノードは AnimatedSprite2D で、idle ア��メーションの最初のフレームは FroggerIdle
@Test
def testPlayerSpriteAnimation(): Unit \ Assert =
    match Scene.getAt("player" :: "Sprite" :: Nil, Game.buildScene()) {
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
    match Scene.getAt("player" :: "Hitbox" :: Nil, Game.buildScene()) {
        case Some(node) => Assert.assertTrue(CollisionObject2D.isMonitoring(node))
        case None => bug!("player Hitbox not found")
    }

// ========================================================================
// buildScene: 背景ゾーン配置
// ========================================================================

/// 水ゾーン背景の位置が (0, 64)
@Test
def testBgWaterPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("bgWater", Game.buildScene());
    Assert.assertEq(expected = (0.0f32, 64.0f32), (pos#x, pos#y))

/// 道路ゾーン背景の位置が (0, 512)
@Test
def testBgRoadPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("bgRoad", Game.buildScene());
    Assert.assertEq(expected = (0.0f32, 512.0f32), (pos#x, pos#y))

/// 中央分離帯背景の位置が (0, 448)
@Test
def testBgMedianPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("bgMedian", Game.buildScene());
    Assert.assertEq(expected = (0.0f32, 448.0f32), (pos#x, pos#y))

// ========================================================================
// buildScene: 車両配置
// ========================================================================

/// レーン0の最初の車両が Y=512 に配置される
@Test
def testVehicleLane0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("v0_0", Game.buildScene());
    Assert.assertEq(expected = 512.0f32, pos#y)

/// レーン0の2台目の車両は spacing=100 で 164px 先
///   startX = 1 * (64 + 100) = 164
@Test
def testVehicleLane0SecondPosition(): Unit \ Assert =
    let pos = Scene.globalPosition("v0_1", Game.buildScene());
    Assert.assertEq(expected = (164.0f32, 512.0f32), (pos#x, pos#y))

// ========================================================================
// buildScene: 丸太配置
// ========================================================================

/// レーン0の最初の丸太が Y=64 に配置される
@Test
def testLogLane0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("l0_0", Game.buildScene());
    Assert.assertEq(expected = 64.0f32, pos#y)

/// レーン0の丸太は middles=1 なので 3 つの子スプライト（LogStart + LogMiddle + LogEnd）
@Test
def testLogLane0SpriteCount(): Unit \ Assert =
    Assert.assertEq(
        expected = 3,
        List.length(Scene.getChildren("l0_0", Game.buildScene())))

/// 丸太のプラットフォームは monitoring/monitorable=false（手動判定）
@Test
def testLogNotMonitoring(): Unit \ Assert =
    match Scene.get("l0_0", Game.buildScene()) {
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

/// process でプレイヤーが targetPosition に向かって移動する
///   moveSpeed=512, dt=0.1 → 51.2px 移動。832-51.2=780.8
@Test
def testPlayerProcessMovesTowardTarget(): Unit \ Assert =
    let state = Game.initGameState();
    // ターゲットを上に設定
    let scene1 = Scene.mapAt("player" :: Nil, node -> match node {
        case GameNode.Player(r) =>
            GameNode.Player({targetPosition = {x = 384.0f32, y = 768.0f32} | r})
        case other => other
    }, state#scene);
    let processed = Scene.processAll(0.1, false, scene1);
    let pos = Scene.globalPosition("player", processed);
    Assert.assertEq(expected = (384.0f32, 780.8f32), vecToTuple(pos))

/// ターゲットが現在位置と同じ場合、移動しない
@Test
def testPlayerProcessStaysAtTarget(): Unit \ Assert =
    let state = Game.initGameState();
    let processed = Scene.processAll(0.1, false, state#scene);
    let pos = Scene.globalPosition("player", processed);
    Assert.assertEq(expected = (384.0f32, 832.0f32), vecToTuple(pos))

// ========================================================================
// AnimatedSprite2D process: フレーム進行
// ========================================================================

/// fps=4 で 0.3 秒後（frameDuration=0.25 超過）にフレームが 1 に進む
@Test
def testAnimSpriteAdvancesFrame(): Unit \ Assert =
    let state = Game.initGameState();
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
    let scene = Game.buildScene();
    let origPos = Scene.globalPosition("v0_0", scene);
    let processed = Scene.processAll(0.1, false, scene);
    let newPos = Scene.globalPosition("v0_0", processed);
    Assert.assertEq(
        expected = (origPos#x - 20.0f32, origPos#y),
        (newPos#x, newPos#y))

/// Vehicle が画面左端を超えたら右端にラップする
@Test
def testVehicleWrapsLeft(): Unit \ Assert =
    let scene = Game.buildScene()
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
    let scene = Game.buildScene();
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
    let pos = Scene.globalPosition("t0_0", Game.buildScene());
    Assert.assertEq(expected = 320.0f32, pos#y)

/// 亀レーン0のグループは sections=3 なので 3 つの子スプライト
@Test
def testTurtleLane0SpriteCount(): Unit \ Assert =
    Assert.assertEq(
        expected = 3,
        List.length(Scene.getChildren("t0_0", Game.buildScene())))

/// 亀プラットフォームは monitoring/monitorable=false（手動判定）
@Test
def testTurtleNotMonitoring(): Unit \ Assert =
    match Scene.get("t0_0", Game.buildScene()) {
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
    let scene = Game.buildScene();
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
    let state = Game.initGameState();
    let newState = Game.applyInput(Some(Vec2.up()), state);
    let target = Game.getPlayerTarget(newState#scene);
    Assert.assertEq(expected = (384.0f32, 768.0f32), vecToTuple(target))

/// 下方向は 832 でクランプされ移動しない
@Test
def testApplyInputClampDown(): Unit \ Assert =
    let state = Game.initGameState();
    let newState = Game.applyInput(Some(Vec2.down()), state);
    let target = Game.getPlayerTarget(newState#scene);
    Assert.assertEq(expected = (384.0f32, 832.0f32), vecToTuple(target))

/// None 入力は状態を変更しない
@Test
def testApplyInputNone(): Unit \ Assert =
    let state = Game.initGameState();
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

/// 下���向は π ラジアン
@Test
def testDirectionToRotationDown(): Unit \ Assert =
    Assert.assertEq(expected = 3.1415926535898, Game.directionToRotation(Vec2.down()))

// ========================================================================
// checkDeath: 衝突死亡判定
// ========================================================================

/// スプライトが赤色のとき isDead=true に変わる
@Test
def testCheckDeathDetectsRed(): Unit \ Assert =
    let state = Game.initGameState();
    let redScene = Scene.mapAt("player" :: "Sprite" :: Nil, node -> match node {
        case GameNode.AnimSpriteNode(sprite) =>
            GameNode.AnimSpriteNode(CanvasItem.setModulate({r = 1.0f32, g = 0.2f32, b = 0.2f32}, sprite))
        case other => other
    }, state#scene);
    let deadState = Game.checkDeath({scene = redScene | state});
    Assert.assertEq(expected = (true, 2.0f32), (deadState#isDead, deadState#deathTimer))

/// 通常色のスプライトでは isDead は変わらない
@Test
def testCheckDeathNormalColor(): Unit \ Assert =
    let state = Game.initGameState();
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
    let state = Game.initGameState();
    let waterPos: Vec2.Vec2 = {x = 384.0f32, y = 430.0f32};
    let scene1 = Scene.setGlobalPosition("player", waterPos, state#scene)
        |> Scene.mapAt("player" :: Nil, node -> match node {
            case GameNode.Player(r) =>
                GameNode.Player({
                    body = Node2D.setPosition(waterPos, r#body),
                    targetPosition = waterPos
                    | r})
            case other => other
        });
    let drownState = Game.checkDrown({scene = scene1 | state});
    Assert.assertTrue(drownState#isDead)

/// 道路ゾーンにいるときは溺死しない
@Test
def testCheckDrownNotInWater(): Unit \ Assert =
    let state = Game.initGameState();
    let checkedState = Game.checkDrown(state);
    Assert.assertFalse(checkedState#isDead)

// ========================================================================
// buildScene: ホームスロット配置
// ========================================================================

/// 5 つのホームスロットが存在する
@Test
def testHomeSlotCount(): Unit \ Assert =
    let scene = Game.buildScene();
    let exists = List.forAll(idx ->
        not Option.isEmpty(Scene.get("home${idx}", scene)),
        List.range(0, 5));
    Assert.assertTrue(exists)

/// ホームスロット 0 の位置が (64, 0)
@Test
def testHomeSlot0Position(): Unit \ Assert =
    let pos = Scene.globalPosition("home0", Game.buildScene());
    Assert.assertEq(expected = (64.0f32, 0.0f32), (pos#x, pos#y))

/// ホームスロット 2（中央）の位置が (384, 0)
@Test
def testHomeSlot2Position(): Unit \ Assert =
    let pos = Scene.globalPosition("home2", Game.buildScene());
    Assert.assertEq(expected = (384.0f32, 0.0f32), (pos#x, pos#y))

/// 初期状態ではホームスロットは全て未充填
@Test
def testHomeSlotInitiallyUnfilled(): Unit \ Assert =
    let scene = Game.buildScene();
    Assert.assertFalse(Game.allHomesFilled(scene))

/// 各ホームスロットは子スプライトを 1 つ持つ
@Test
def testHomeSlotHasSprite(): Unit \ Assert =
    Assert.assertEq(
        expected = 1,
        List.length(Scene.getChildren("home0", Game.buildScene())))

// ========================================================================
// tryFillHomeSlot: ホームスロット充填
// ========================================================================

/// プレイヤーがホームゾーン中央（x=384, y=0）に到達すると home2 が充填される
@Test
def testTryFillHomeSlotFills(): Unit \ Assert =
    let state = Game.initGameState();
    let homePos: Vec2.Vec2 = {x = 384.0f32, y = 0.0f32};
    let scene1 = Scene.mapAt("player" :: Nil, node -> match node {
        case GameNode.Player(r) =>
            GameNode.Player({
                body = Node2D.setPosition(homePos, r#body),
                targetPosition = homePos
                | r})
        case other => other
    }, state#scene);
    let filledState = Game.tryFillHomeSlot({scene = scene1 | state});
    // home2 が充填されている
    match Scene.get("home2", filledState#scene) {
        case Some(GameNode.HomeSlot(r)) => Assert.assertTrue(r#filled)
        case _ => bug!("home2 not found")
    }

/// ホームスロット充填後、プレイヤーがスタート位置にリセットされる
@Test
def testTryFillHomeSlotResetsPlayer(): Unit \ Assert =
    let state = Game.initGameState();
    let homePos: Vec2.Vec2 = {x = 384.0f32, y = 0.0f32};
    let scene1 = Scene.mapAt("player" :: Nil, node -> match node {
        case GameNode.Player(r) =>
            GameNode.Player({
                body = Node2D.setPosition(homePos, r#body),
                targetPosition = homePos
                | r})
        case other => other
    }, state#scene);
    let filledState = Game.tryFillHomeSlot({scene = scene1 | state});
    let pos = Scene.globalPosition("player", filledState#scene);
    Assert.assertEq(expected = (384.0f32, 832.0f32), (pos#x, pos#y))

/// ホームゾーンにいないとき tryFillHomeSlot は何もしない
@Test
def testTryFillHomeSlotNoOpInRoad(): Unit \ Assert =
    let state = Game.initGameState();
    let filledState = Game.tryFillHomeSlot(state);
    Assert.assertFalse(Game.allHomesFilled(filledState#scene))

/// 全5スロット充填で allHomesFilled が true を返す
@Test
def testAllHomesFilledWin(): Unit \ Assert =
    let state = Game.initGameState();
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
// updateDeathTimer: 死亡タイマーとリスポーン
// ========================================================================

/// 死亡中にタイマーが減少する
@Test
def testUpdateDeathTimerDecreases(): Unit \ Assert =
    let state = {isDead = true, deathTimer = 2.0f32 | Game.initGameState()};
    let updated = Game.updateDeathTimer(0.5f32, state);
    Assert.assertEq(expected = (true, 1.5f32), (updated#isDead, updated#deathTimer))

/// タイマーが 0 以下になるとリスポーンする（isDead=false, ライフ -1）
@Test
def testUpdateDeathTimerRespawns(): Unit \ Assert =
    let state = {isDead = true, deathTimer = 0.1f32 | Game.initGameState()};
    let updated = Game.updateDeathTimer(0.2f32, state);
    Assert.assertEq(
        expected = (false, 2),
        (updated#isDead, updated#lives))

/// リスポーン後にプレイヤーがスタート位置に戻る
@Test
def testRespawnResetsPosition(): Unit \ Assert =
    let state = {isDead = true, deathTimer = 0.1f32 | Game.initGameState()};
    let updated = Game.updateDeathTimer(0.2f32, state);
    let pos = Scene.globalPosition("player", updated#scene);
    Assert.assertEq(expected = (384.0f32, 832.0f32), (pos#x, pos#y))

/// リスポーン後にスプライトが idle アニメーションに戻る
@Test
def testRespawnResetsAnimation(): Unit \ Assert =
    let state = {isDead = true, deathTimer = 0.1f32 | Game.initGameState()};
    let updated = Game.updateDeathTimer(0.2f32, state);
    match Scene.getAt("player" :: "Sprite" :: Nil, updated#scene) {
        case Some(GameNode.AnimSpriteNode(sprite)) =>
            Assert.assertEq(expected = "idle", AnimatedSprite2D.getCurrentAnimation(sprite))
        case _ => bug!("player Sprite not found after respawn")
    }

/// 死亡していないときは updateDeathTimer は何もしない
@Test
def testUpdateDeathTimerNoOpWhenAlive(): Unit \ Assert =
    let state = Game.initGameState();
    let updated = Game.updateDeathTimer(0.5f32, state);
    Assert.assertEq(expected = (false, 0.0f32), (updated#isDead, updated#deathTimer))

// ========================================================================
// updateGameTimer: ゲームタイマー
// ========================================================================

/// ゲームタイマーが減少する
@Test
def testUpdateGameTimerDecreases(): Unit \ Assert =
    let state = Game.initGameState();
    let updated = Game.updateGameTimer(1.0f32, state);
    Assert.assertEq(expected = 29.0f32, updated#timeRemaining)

/// タイマーが 0 以下になると死亡する
@Test
def testUpdateGameTimerDeath(): Unit \ Assert =
    let state = {timeRemaining = 0.5f32 | Game.initGameState()};
    let updated = Game.updateGameTimer(1.0f32, state);
    Assert.assertEq(expected = (true, 0.0f32), (updated#isDead, updated#timeRemaining))

/// 死亡中はゲームタイマーが減少しない
@Test
def testUpdateGameTimerPausedWhenDead(): Unit \ Assert =
    let state = {isDead = true, deathTimer = 2.0f32 | Game.initGameState()};
    let updated = Game.updateGameTimer(1.0f32, state);
    Assert.assertEq(expected = 30.0f32, updated#timeRemaining)

// ========================================================================
// isGameOver / resetGame
// ========================================================================

/// ライフ 0 でゲームオーバー
@Test
def testIsGameOverTrue(): Unit \ Assert =
    let state = {lives = 0 | Game.initGameState()};
    Assert.assertTrue(Game.isGameOver(state))

/// ライフ残ありでゲームオーバーではない
@Test
def testIsGameOverFalse(): Unit \ Assert =
    Assert.assertFalse(Game.isGameOver(Game.initGameState()))

/// resetGame で初期状態に戻る
@Test
def testResetGame(): Unit \ Assert =
    let state = Game.resetGame();
    Assert.assertEq(expected = (3, 30.0f32, false), (state#lives, state#timeRemaining, state#isDead))
