// Tests for Game module (processPulse, AreaHandler)
//
// buildScene() の初期配置:
//   frog  (x=345, y=300, radius=40) → sprite (scale=5x5)
//   turtle(x=420, y=300, radius=40) → sprite (scale=5x5)
//   距離=75px < 半径合計=80px → 初期状態で重なっている

/// テスト用ヘルパー: 親ノード配下の Sprite の modulate を取得する
def getSpriteModulate(parentName: String, scene: Scene[GameNode]): Color =
    match Scene.getAt(parentName :: "sprite" :: Nil, scene) {
        case Some(GameNode.SpriteNode(sprite)) => CanvasItem.getModulate(sprite)
        case _ => bug!("sprite child not found for ${parentName}")
    }

/// テスト用ヘルパー: 親ノード配下の Sprite の scale を取得する
def getSpriteScale(parentName: String, scene: Scene[GameNode]): Vec2.Vec2 =
    match Scene.getAt(parentName :: "sprite" :: Nil, scene) {
        case Some(GameNode.SpriteNode(sprite)) => Node2D.getScale(sprite)
        case _ => bug!("sprite child not found for ${parentName}")
    }

/// テスト用ヘルパー: 親ノード配下の Sprite の rotation を取得する
def getSpriteRotation(parentName: String, scene: Scene[GameNode]): Float64 =
    match Scene.getAt(parentName :: "sprite" :: Nil, scene) {
        case Some(GameNode.SpriteNode(sprite)) => Node2D.getRotation(sprite)
        case _ => bug!("sprite child not found for ${parentName}")
    }

// ========================================================================
// Game.processPulse
// ========================================================================

/// delta 分だけ経過時間（rotation フィールド）が加算される
@Test
def testProcessPulseAdvancesTime(): Unit \ Assert =
    let scene = Game.buildScene();
    let area = Game.getArea(Option.getWithDefault(bug!("frog not found"), Scene.get("frog", scene)));
    let (updatedArea, _newScene) = Game.processPulse(1.0, frequency = 2.0, baseRadius = 40.0f32, rotSign = 1.0, area, "frog" :: Nil, scene);
    let Area2D.Area2D(r) = updatedArea;
    Assert.assertEq(expected = 1.0, r#rotation)

/// パルスで衝突半径が baseRadius * pulseFactor に更新される
///
///   time=0 から delta=1.0 経過後:
///     pulseFactor = 1.0 + 0.5 * sin(1.0 * 2.0)
///     scaledRadius = 40.0 * pulseFactor
///
@Test
def testProcessPulseUpdatesCollisionRadius(): Unit \ Assert =
    let scene = Game.buildScene();
    let area = Game.getArea(Option.getWithDefault(bug!("frog not found"), Scene.get("frog", scene)));
    let (updatedArea, _newScene) = Game.processPulse(1.0, frequency = 2.0, baseRadius = 40.0f32, rotSign = 1.0, area, "frog" :: Nil, scene);
    let sinValue = Vec2.sin32(Float64.truncateToFloat32(1.0 * 2.0));
    let expectedRadius = 40.0f32 * (1.0f32 + 0.5f32 * sinValue);
    let actualRadius = match CollisionObject2D.getCollisionShape(updatedArea) {
        case Some(CollisionShape2D.CircleShape2D(r)) => r#radius
        case _ => bug!("expected CircleShape2D")
    };
    Assert.assertEq(expected = expectedRadius, actualRadius)

/// パルスで子 Sprite の scale が 5.0 * pulseFactor に更新される
@Test
def testProcessPulseUpdatesSpriteScale(): Unit \ Assert =
    let scene = Game.buildScene();
    let area = Game.getArea(Option.getWithDefault(bug!("frog not found"), Scene.get("frog", scene)));
    let (_updatedArea, newScene) = Game.processPulse(1.0, frequency = 2.0, baseRadius = 40.0f32, rotSign = 1.0, area, "frog" :: Nil, scene);
    let sinValue = Vec2.sin32(Float64.truncateToFloat32(1.0 * 2.0));
    let expectedScale = 5.0f32 * (1.0f32 + 0.5f32 * sinValue);
    let actualScale = getSpriteScale("frog", newScene);
    Assert.assertEq(expected = (expectedScale, expectedScale), (actualScale#x, actualScale#y))

/// パルスで子 Sprite の rotation が rotSign * time に更新される
@Test
def testProcessPulseUpdatesSpriteRotation(): Unit \ Assert =
    let scene = Game.buildScene();
    let area = Game.getArea(Option.getWithDefault(bug!("frog not found"), Scene.get("frog", scene)));
    let (_updatedArea, newScene) = Game.processPulse(1.0, frequency = 2.0, baseRadius = 40.0f32, rotSign = -1.0, area, "frog" :: Nil, scene);
    Assert.assertEq(expected = -1.0, getSpriteRotation("frog", newScene))

// ========================================================================
// AreaHandler[GameNode] — onAreaEntered
// ========================================================================

/// カエルが亀と重なるとカエルの子 Sprite が赤くなる
///
///   buildScene の初期配置: frog(x=345) と turtle(x=420) は距離 75 < 半径合計 80 で重なる
///
@Test
def testAreaHandlerFrogTurnsRedOnTurtleOverlap(): Unit \ Assert =
    let scene = Game.buildScene();
    let (result, _overlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene);
    let color = getSpriteModulate("frog", result);
    Assert.assertEq(expected = (1.0f32, 0.2f32, 0.2f32), (color#r, color#g, color#b))

/// 亀側の子 Sprite は衝突しても変化しない（AreaHandler は Frog→Turtle 方向のみ）
@Test
def testAreaHandlerTurtleUnchangedOnFrogOverlap(): Unit \ Assert =
    let scene = Game.buildScene();
    let (result, _overlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene);
    let color = getSpriteModulate("turtle", result);
    Assert.assertEq(expected = (1.0f32, 1.0f32, 1.0f32), (color#r, color#g, color#b))

/// カエルと亀が離れていれば子 Sprite の色は変わらない
///
///   frog を x=0 に移動 → turtle(x=420) との距離=420 > 半径合計=80 で重ならない
///
@Test
def testAreaHandlerNoChangeWhenApart(): Unit \ Assert =
    let scene = Game.buildScene()
        |> Scene.set("frog",
            GameNode.Frog(CanvasItem.setVisible(false,
                Area2D.make({x = 0.0f32, y = 300.0f32},
                    CollisionShape2D.CircleShape2D({radius = 40.0f32})))));
    let (result, _overlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene);
    let color = getSpriteModulate("frog", result);
    Assert.assertEq(expected = (1.0f32, 1.0f32, 1.0f32), (color#r, color#g, color#b))

// ========================================================================
// AreaHandler[GameNode] — onAreaExited
// ========================================================================

/// カエルが亀から離れるとカエルの子 Sprite が白に戻る
///
///   フレーム1: buildScene のまま（重なり）  → 赤くなる + prevOverlaps 取得
///   フレーム2: frog を x=0 に移動（離脱）   → 白に戻る
///
@Test
def testAreaHandlerFrogTurnsWhiteOnExit(): Unit \ Assert =
    // フレーム1: 重なり → prevOverlaps を取得
    let scene1 = Game.buildScene();
    let (_sceneAfterEnter, prevOverlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene1);
    // フレーム2: frog を遠くに移動して離脱
    let scene2 = Game.buildScene()
        |> Scene.set("frog",
            GameNode.Frog(CanvasItem.setVisible(false,
                Area2D.make({x = 0.0f32, y = 300.0f32},
                    CollisionShape2D.CircleShape2D({radius = 40.0f32})))));
    let (result, newOverlaps) = AreaEvent.processAndEmitHandled(0.016, false, prevOverlaps, scene2);
    let color = getSpriteModulate("frog", result);
    Assert.assertEq(
        expected = ((1.0f32, 1.0f32, 1.0f32), 0),
        ((color#r, color#g, color#b), Set.size(newOverlaps))
    )
