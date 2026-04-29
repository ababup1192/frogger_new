// Tests for AreaEvent module

/// テスト用ヘルパー: 矩形 Area2D を作る
def rectArea(x: Float32, y: Float32, w: Float32, h: Float32): Area2D =
    Area2D.make({x = x, y = y}, CollisionShape2D.RectShape2D({width = w, height = h}))

/// テスト用ヘルパー: 円形 Area2D を作る
def circleArea(x: Float32, y: Float32, r: Float32): Area2D =
    Area2D.make({x = x, y = y}, CollisionShape2D.CircleShape2D({radius = r}))

// ── processAndEmitHandled テスト用の sum type ──

enum TestAreaNode {
    case RedNode(Area2D)
    case BlueNode(Area2D)
}

def testAreaNodeGetArea(node: TestAreaNode): Area2D = match node {
    case TestAreaNode.RedNode(a) => a
    case TestAreaNode.BlueNode(a) => a
}

def testAreaNodeMapArea(f: Area2D -> Area2D, node: TestAreaNode): TestAreaNode = match node {
    case TestAreaNode.RedNode(a) => TestAreaNode.RedNode(f(a))
    case TestAreaNode.BlueNode(a) => TestAreaNode.BlueNode(f(a))
}

instance CanvasItem[TestAreaNode] {
    pub def isVisible(n: TestAreaNode): Bool = CanvasItem.isVisible(testAreaNodeGetArea(n))
    pub def setVisible(v: Bool, n: TestAreaNode): TestAreaNode = testAreaNodeMapArea(a -> CanvasItem.setVisible(v, a), n)
    pub def getModulate(n: TestAreaNode): Color = CanvasItem.getModulate(testAreaNodeGetArea(n))
    pub def setModulate(c: Color, n: TestAreaNode): TestAreaNode = testAreaNodeMapArea(a -> CanvasItem.setModulate(c, a), n)
    pub def getZIndex(n: TestAreaNode): Int32 = CanvasItem.getZIndex(testAreaNodeGetArea(n))
    pub def setZIndex(z: Int32, n: TestAreaNode): TestAreaNode = testAreaNodeMapArea(a -> CanvasItem.setZIndex(z, a), n)
}

instance Node2D[TestAreaNode] {
    pub def getPosition(n: TestAreaNode): Vec2.Vec2 = Node2D.getPosition(testAreaNodeGetArea(n))
    pub def setPosition(p: Vec2.Vec2, n: TestAreaNode): TestAreaNode = testAreaNodeMapArea(a -> Node2D.setPosition(p, a), n)
    pub def getRotation(n: TestAreaNode): Float64 = Node2D.getRotation(testAreaNodeGetArea(n))
    pub def setRotation(r: Float64, n: TestAreaNode): TestAreaNode = testAreaNodeMapArea(a -> Node2D.setRotation(r, a), n)
    pub def getScale(n: TestAreaNode): Vec2.Vec2 = Node2D.getScale(testAreaNodeGetArea(n))
    pub def setScale(s: Vec2.Vec2, n: TestAreaNode): TestAreaNode = testAreaNodeMapArea(a -> Node2D.setScale(s, a), n)
    pub def getSkew(n: TestAreaNode): Float64 = Node2D.getSkew(testAreaNodeGetArea(n))
    pub def setSkew(s: Float64, n: TestAreaNode): TestAreaNode = testAreaNodeMapArea(a -> Node2D.setSkew(s, a), n)
}

instance CollisionObject2D[TestAreaNode] {
    pub def getCollisionShape(n: TestAreaNode): Option[CollisionShape2D] = CollisionObject2D.getCollisionShape(testAreaNodeGetArea(n))
    pub def isMonitoring(n: TestAreaNode): Bool = CollisionObject2D.isMonitoring(testAreaNodeGetArea(n))
    pub def isMonitorable(n: TestAreaNode): Bool = CollisionObject2D.isMonitorable(testAreaNodeGetArea(n))
}

instance Node[TestAreaNode] {
}

instance AreaHandler[TestAreaNode] {
    pub def onAreaEntered(selfPath: NodePath, self: TestAreaNode,
                          _otherPath: NodePath, other: TestAreaNode,
                          scene: Scene[TestAreaNode]): Scene[TestAreaNode] =
        match (self, other) {
            case (TestAreaNode.RedNode(_), TestAreaNode.BlueNode(_)) =>
                let updated = CanvasItem.setModulate({r = 1.0f32, g = 0.0f32, b = 0.0f32}, self);
                Scene.setAt(selfPath, updated, scene)
            case _ => scene
        }
    redef onAreaExited(selfPath: NodePath, self: TestAreaNode,
                       _otherPath: NodePath, other: TestAreaNode,
                       scene: Scene[TestAreaNode]): Scene[TestAreaNode] =
        match (self, other) {
            case (TestAreaNode.RedNode(_), TestAreaNode.BlueNode(_)) =>
                let updated = CanvasItem.setModulate({r = 1.0f32, g = 1.0f32, b = 1.0f32}, self);
                Scene.setAt(selfPath, updated, scene)
            case _ => scene
        }
}

// ========================================================================
// detectOverlaps
// ========================================================================

/// 2 つの重なっている Area2D を検出する
@Test
def testDetectOverlapsTwoOverlapping(): Unit \ Assert =
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32))
        |> Scene.addNode("b", rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 2, List.length(overlaps))

/// 離れている Area2D は検出されない
@Test
def testDetectOverlapsNoOverlap(): Unit \ Assert =
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", rectArea(0.0f32, 0.0f32, 4.0f32, 4.0f32))
        |> Scene.addNode("b", rectArea(100.0f32, 100.0f32, 4.0f32, 4.0f32));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 0, List.length(overlaps))

/// monitoring=false の場合、その側のイベントは生成されない
@Test
def testDetectOverlapsMonitoringOff(): Unit \ Assert =
    let a = rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32) |> Area2D.setMonitoring(false);
    let b = rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32);
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", a)
        |> Scene.addNode("b", b);
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 1, List.length(overlaps))

/// monitorable=false の場合、相手からの検出対象にならない
@Test
def testDetectOverlapsMonitorableOff(): Unit \ Assert =
    let a = rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32);
    let b = rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32) |> Area2D.setMonitorable(false);
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", a)
        |> Scene.addNode("b", b);
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 1, List.length(overlaps))

/// 両方 monitoring=false, monitorable=false なら検出ゼロ
@Test
def testDetectOverlapsBothOff(): Unit \ Assert =
    let a = rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32)
            |> Area2D.setMonitoring(false) |> Area2D.setMonitorable(false);
    let b = rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32)
            |> Area2D.setMonitoring(false) |> Area2D.setMonitorable(false);
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", a)
        |> Scene.addNode("b", b);
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 0, List.length(overlaps))

/// 3 ノードで A-B 重なり、A-C 重なり、B-C 離れの場合
@Test
def testDetectOverlapsThreeNodes(): Unit \ Assert =
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32))
        |> Scene.addNode("b", rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32))
        |> Scene.addNode("c", rectArea(3.0f32, 0.0f32, 4.0f32, 4.0f32));
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 6, List.length(overlaps))

/// 衝突形状なしの Area2D は検出に参加しない
@Test
def testDetectOverlapsNoShape(): Unit \ Assert =
    let a = rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32);
    let b = rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32)
            |> Area2D.setCollisionShape(None);
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", a)
        |> Scene.addNode("b", b);
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertEq(expected = 0, List.length(overlaps))

/// 親子配置で globalPosition が考慮される
@Test
def testDetectOverlapsWithParentChild(): Unit \ Assert =
    let parent = rectArea(100.0f32, 0.0f32, 4.0f32, 4.0f32);
    let child = rectArea(0.0f32, 0.0f32, 4.0f32, 4.0f32);
    let other = rectArea(101.0f32, 0.0f32, 4.0f32, 4.0f32);
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("parent", parent)
        |> Scene.addChild("parent", "child", child)
        |> Scene.addNode("other", other);
    let overlaps = AreaEvent.detectOverlaps(scene);
    Assert.assertTrue(List.length(overlaps) > 0)

// ========================================================================
// fireAreaEnteredAll（イベント発火カウント）
// ========================================================================

/// 発火されるイベント数を継続で数える
@Test
def testFireAreaEnteredAllCount(): Unit \ Assert =
    let overlaps: List[AreaOverlap] =
        {selfPath = "a" :: Nil, selfPos = Vec2.zero(), other = {path = "b" :: Nil, position = Vec2.zero()}} ::
        {selfPath = "b" :: Nil, selfPos = Vec2.zero(), other = {path = "a" :: Nil, position = Vec2.zero()}} :: Nil;
    let count = run {
        AreaEvent.fireAreaEnteredAll(overlaps);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 2, count)

/// 空リストでは発火なし
@Test
def testFireAreaEnteredAllEmpty(): Unit \ Assert =
    let count = run {
        AreaEvent.fireAreaEnteredAll(Nil);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 0, count)

// ========================================================================
// runWithNoopAreaEvent
// ========================================================================

/// noop ハンドラでイベントが無視される
@Test
def testRunWithNoopAreaEvent(): Unit \ Assert =
    let result = AreaEvent.runWithNoopAreaEvent(() -> {
        OnAreaEvent.areaEntered("a" :: Nil, Vec2.zero(), {path = "b" :: Nil, position = Vec2.zero()});
        42
    });
    Assert.assertEq(expected = 42, result)

// ========================================================================
// emitOverlapEvents（統合テスト）
// ========================================================================

/// 検出 + 発火の統合テスト
@Test
def testEmitOverlapEventsIntegration(): Unit \ Assert =
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32))
        |> Scene.addNode("b", rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32));
    let count = run {
        AreaEvent.emitOverlapEvents(scene);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 2, count)

/// 重なりのない Scene では発火なし
@Test
def testEmitOverlapEventsNoOverlap(): Unit \ Assert =
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", rectArea(0.0f32, 0.0f32, 4.0f32, 4.0f32))
        |> Scene.addNode("b", rectArea(100.0f32, 0.0f32, 4.0f32, 4.0f32));
    let count = run {
        AreaEvent.emitOverlapEvents(scene);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 0, count)

// ========================================================================
// processAndEmit（エンジン統合テスト）
// ========================================================================

/// processAll + イベント発火が一括で行われる
@Test
def testProcessAndEmitFiresEvents(): Unit \ Assert =
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32))
        |> Scene.addNode("b", rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32));
    let count = run {
        let _s = AreaEvent.processAndEmit(0.016, false, scene);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 2, count)

/// 重なりがなければ processAndEmit でもイベント発火なし
@Test
def testProcessAndEmitNoEvents(): Unit \ Assert =
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("a", rectArea(0.0f32, 0.0f32, 4.0f32, 4.0f32))
        |> Scene.addNode("b", rectArea(100.0f32, 0.0f32, 4.0f32, 4.0f32));
    let count = run {
        let _s = AreaEvent.processAndEmit(0.016, false, scene);
        0
    } with handler OnAreaEvent {
        def areaEntered(_selfPath, _selfPos, _other, k) =
            k(()) + 1
    };
    Assert.assertEq(expected = 0, count)

/// ハンドラで戻り値を変換するパターン（旧エンジン stepAndCollide 相当）
@Test
def testProcessAndEmitHandlerTransform(): Unit \ Assert =
    let scene: Scene[Area2D] = Scene.empty()
        |> Scene.addNode("player", rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32))
        |> Scene.addNode("enemy", rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32));
    let hitPaths: List[NodePath] = run {
        let _s = AreaEvent.processAndEmit(0.016, false, scene);
        Nil
    } with handler OnAreaEvent {
        def areaEntered(selfPath, _selfPos, _other, k) =
            selfPath :: k(())
    };
    Assert.assertEq(expected = 2, List.length(hitPaths))

// ========================================================================
// processAndEmitHandled（AreaHandler 統合テスト）
// ========================================================================

/// RedNode が BlueNode と衝突すると modulate が赤になる
@Test
def testProcessAndEmitHandledChangesModulate(): Unit \ Assert =
    let red = TestAreaNode.RedNode(rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32));
    let blue = TestAreaNode.BlueNode(rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32));
    let scene: Scene[TestAreaNode] = Scene.empty()
        |> Scene.addNode("red", red)
        |> Scene.addNode("blue", blue);
    let (result, _overlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene);
    match Scene.get("red", result) {
        case Some(n) =>
            let c = CanvasItem.getModulate(n);
            Assert.assertEq(expected = 1.0f32, c#r);
            Assert.assertEq(expected = 0.0f32, c#g);
            Assert.assertEq(expected = 0.0f32, c#b)
        case None => Assert.assertEq(expected = "red node exists", "red node missing")
    }

/// BlueNode 側は AreaHandler で何もしないので modulate は白のまま
@Test
def testProcessAndEmitHandledBlueUnchanged(): Unit \ Assert =
    let red = TestAreaNode.RedNode(rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32));
    let blue = TestAreaNode.BlueNode(rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32));
    let scene: Scene[TestAreaNode] = Scene.empty()
        |> Scene.addNode("red", red)
        |> Scene.addNode("blue", blue);
    let (result, _overlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene);
    match Scene.get("blue", result) {
        case Some(n) =>
            let c = CanvasItem.getModulate(n);
            Assert.assertEq(expected = 1.0f32, c#r);
            Assert.assertEq(expected = 1.0f32, c#g);
            Assert.assertEq(expected = 1.0f32, c#b)
        case None => Assert.assertEq(expected = "blue node exists", "blue node missing")
    }

/// 重なりがなければ processAndEmitHandled でも変更なし
@Test
def testProcessAndEmitHandledNoOverlap(): Unit \ Assert =
    let red = TestAreaNode.RedNode(rectArea(0.0f32, 0.0f32, 4.0f32, 4.0f32));
    let blue = TestAreaNode.BlueNode(rectArea(100.0f32, 0.0f32, 4.0f32, 4.0f32));
    let scene: Scene[TestAreaNode] = Scene.empty()
        |> Scene.addNode("red", red)
        |> Scene.addNode("blue", blue);
    let (result, _overlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene);
    match Scene.get("red", result) {
        case Some(n) =>
            let c = CanvasItem.getModulate(n);
            Assert.assertEq(expected = 1.0f32, c#g)
        case None => Assert.assertEq(expected = "red node exists", "red node missing")
    }

/// 同じバリアント同士 (RedNode vs RedNode) では AreaHandler は何もしない
@Test
def testProcessAndEmitHandledSameVariant(): Unit \ Assert =
    let r1 = TestAreaNode.RedNode(rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32));
    let r2 = TestAreaNode.RedNode(rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32));
    let scene: Scene[TestAreaNode] = Scene.empty()
        |> Scene.addNode("r1", r1)
        |> Scene.addNode("r2", r2);
    let (result, _overlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene);
    match Scene.get("r1", result) {
        case Some(n) =>
            let c = CanvasItem.getModulate(n);
            Assert.assertEq(expected = 1.0f32, c#g)
        case None => Assert.assertEq(expected = "r1 exists", "r1 missing")
    }

// ========================================================================
// onAreaExited（離脱イベントテスト）
// ========================================================================

/// 前フレームで重なっていたペアが離れると onAreaExited が発火される
///
///  フレーム1:  [red]<--重なり-->[blue]  → 赤くなる
///  フレーム2:  [red]          [blue]    → 離脱 → modulate は白のまま
@Test
def testProcessAndEmitHandledFiresExitOnSeparation(): Unit \ Assert =
    // フレーム1: 重なりあり → prevOverlaps を取得
    let red = TestAreaNode.RedNode(rectArea(0.0f32, 0.0f32, 10.0f32, 10.0f32));
    let blue = TestAreaNode.BlueNode(rectArea(5.0f32, 0.0f32, 10.0f32, 10.0f32));
    let scene: Scene[TestAreaNode] = Scene.empty()
        |> Scene.addNode("red", red)
        |> Scene.addNode("blue", blue);
    let (_sceneAfterEnter, prevOverlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene);
    // フレーム2: 離す → 前フレームのペアセットを渡す
    let redFar = TestAreaNode.RedNode(rectArea(0.0f32, 0.0f32, 4.0f32, 4.0f32));
    let blueFar = TestAreaNode.BlueNode(rectArea(100.0f32, 0.0f32, 4.0f32, 4.0f32));
    let separatedScene: Scene[TestAreaNode] = Scene.empty()
        |> Scene.addNode("red", redFar)
        |> Scene.addNode("blue", blueFar);
    let (result, newOverlaps) = AreaEvent.processAndEmitHandled(0.016, false, prevOverlaps, separatedScene);
    // 離脱後のペアセットは空
    Assert.assertEq(expected = 0, Set.size(newOverlaps));
    // RedNode の modulate が白に戻っている（onAreaExited で戻した）
    match Scene.get("red", result) {
        case Some(n) =>
            let c = CanvasItem.getModulate(n);
            Assert.assertEq(expected = (1.0f32, 1.0f32, 1.0f32), (c#r, c#g, c#b))
        case None => Assert.assertEq(expected = "red node exists", "red node missing")
    }

/// prevOverlaps が空なら離脱イベントは発火しない
@Test
def testProcessAndEmitHandledNoExitWithEmptyPrev(): Unit \ Assert =
    let red = TestAreaNode.RedNode(rectArea(0.0f32, 0.0f32, 4.0f32, 4.0f32));
    let blue = TestAreaNode.BlueNode(rectArea(100.0f32, 0.0f32, 4.0f32, 4.0f32));
    let scene: Scene[TestAreaNode] = Scene.empty()
        |> Scene.addNode("red", red)
        |> Scene.addNode("blue", blue);
    let (result, overlaps) = AreaEvent.processAndEmitHandled(0.016, false, Set.empty(), scene);
    Assert.assertEq(expected = 0, Set.size(overlaps));
    match Scene.get("red", result) {
        case Some(n) =>
            let c = CanvasItem.getModulate(n);
            Assert.assertEq(expected = 1.0f32, c#g)
        case None => Assert.assertEq(expected = "red node exists", "red node missing")
    }
