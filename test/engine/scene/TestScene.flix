// Tests for Scene module
//
// テスト用の軽量ノード型 TNode を定義して使用する。
// TNode は Eq, Order を実装し、x/y 座標だけを持つ最小構成。

/// テスト用ノード: x, y 座標だけを持つ最小のノード
enum TNode with Eq, Order, ToString {
    case TNode(Float32, Float32)
}

/// テスト用ヘルパー: 指定位置に TNode を作る
def tnode(x: Float32, y: Float32): TNode =
    TNode.TNode(x, y)

instance CanvasItem[TNode] {
    pub def isVisible(_node: TNode): Bool = true
    pub def setVisible(_visible: Bool, node: TNode): TNode = node
    pub def getModulate(_node: TNode): Color = {r = 1.0f32, g = 1.0f32, b = 1.0f32}
    pub def setModulate(_color: Color, node: TNode): TNode = node
    pub def getZIndex(_node: TNode): Int32 = 0i32
    pub def setZIndex(_zIndex: Int32, node: TNode): TNode = node
}

instance Node2D[TNode] {
    pub def getPosition(node: TNode): Vec2.Vec2 =
        let TNode.TNode(x, y) = node;
        {x = x, y = y}
    pub def setPosition(position: Vec2.Vec2, _node: TNode): TNode =
        TNode.TNode(position#x, position#y)
    pub def getRotation(_node: TNode): Float64 = 0.0f64
    pub def setRotation(_rotation: Float64, node: TNode): TNode = node
    pub def getScale(_node: TNode): Vec2.Vec2 = Vec2.one()
    pub def setScale(_scale: Vec2.Vec2, node: TNode): TNode = node
    pub def getSkew(_node: TNode): Float64 = 0.0f64
    pub def setSkew(_skew: Float64, node: TNode): TNode = node
}

instance Node[TNode] {}

// ========================================================================
// empty
// ========================================================================

/// 空のシーンにはノードがない
@Test
def testSceneEmpty(): Unit \ Assert =
    let scene: Scene[TNode] = Scene.empty();
    Assert.assertEq(expected = 0, Scene.nodes(scene) |> Map.size)

// ========================================================================
// addNode / get
// ========================================================================

/// addNode でルートとして追加し、get で取得できる
@Test
def testSceneAddNodeAndGet(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("player", tnode(10.0f32, 20.0f32));
    Assert.assertEq(expected = Some(tnode(10.0f32, 20.0f32)), Scene.get("player", scene))

/// 存在しないノードの get は None を返す
@Test
def testSceneGetNone(): Unit \ Assert =
    let scene: Scene[TNode] = Scene.empty();
    Assert.assertEq(expected = (None: Option[TNode]), Scene.get("missing", scene))

// ========================================================================
// set
// ========================================================================

/// set でノードの値を更新できる
@Test
def testSceneSet(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("a", tnode(0.0f32, 0.0f32))
        |> Scene.set("a", tnode(99.0f32, 99.0f32));
    Assert.assertEq(expected = Some(tnode(99.0f32, 99.0f32)), Scene.get("a", scene))

/// 存在しないノードへの set はシーンを変更しない
@Test
def testSceneSetMissing(): Unit \ Assert =
    let scene: Scene[TNode] = Scene.empty()
        |> Scene.set("ghost", tnode(1.0f32, 1.0f32));
    Assert.assertEq(expected = 0, Scene.nodes(scene) |> Map.size)

// ========================================================================
// remove（ルートノード）
// ========================================================================

/// ルートノードを remove で削除できる
@Test
def testSceneRemoveRoot(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("a", tnode(0.0f32, 0.0f32))
        |> Scene.remove("a");
    Assert.assertEq(expected = (None: Option[TNode]), Scene.get("a", scene))

// ========================================================================
// nodes（後方互換）
// ========================================================================

/// nodes はルートノードを Map[NodeName, n] として返す
@Test
def testSceneNodes(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("a", tnode(1.0f32, 0.0f32))
        |> Scene.addNode("b", tnode(2.0f32, 0.0f32));
    Assert.assertEq(expected = 2, Scene.nodes(scene) |> Map.size)

// ========================================================================
// addChild / getParent / getChildren
// ========================================================================

/// addChild で親子関係を構築し、getParent / getChildren で取得できる
///
///   root
///    └─ child
///
@Test
def testSceneAddChild(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "child", tnode(10.0f32, 0.0f32));
    let parent = Scene.getParent("root" :: "child" :: Nil, scene);
    let children = Scene.getChildren("root", scene);
    Assert.assertEq(expected = (Some("root" :: Nil), "child" :: Nil), (parent, children))

/// addChild で追加した子ノードを getAt で取得できる
@Test
def testSceneAddChildGet(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "child", tnode(10.0f32, 0.0f32));
    Assert.assertEq(expected = Some(tnode(10.0f32, 0.0f32)), Scene.getAt("root" :: "child" :: Nil, scene))

/// 存在しない親への addChild はシーンを変更しない
@Test
def testSceneAddChildMissingParent(): Unit \ Assert =
    let scene: Scene[TNode] = Scene.empty()
        |> Scene.addChild("ghost", "child", tnode(0.0f32, 0.0f32));
    Assert.assertEq(expected = 0, Scene.nodeCount(scene))

/// 深い階層の親子関係を構築できる
///
///   root
///    └─ a
///        └─ b
///
@Test
def testSceneDeepHierarchy(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(0.0f32, 0.0f32))
        |> Scene.addChildAt("root" :: "a" :: Nil, "b", tnode(0.0f32, 0.0f32));
    let parentOfB = Scene.getParent("root" :: "a" :: "b" :: Nil, scene);
    let childrenOfA = Scene.getChildrenAt("root" :: "a" :: Nil, scene);
    Assert.assertEq(expected = (Some("root" :: "a" :: Nil), "b" :: Nil), (parentOfB, childrenOfA))

/// ルートノードの getParent は None を返す
@Test
def testSceneGetParentRoot(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32));
    Assert.assertEq(expected = (None: Option[NodePath]), Scene.getParent("root" :: Nil, scene))

/// 存在しないノードの getChildren は空リストを返す
@Test
def testSceneGetChildrenMissing(): Unit \ Assert =
    let scene: Scene[TNode] = Scene.empty();
    Assert.assertEq(expected = (Nil: List[NodeName]), Scene.getChildren("missing", scene))

// ========================================================================
// remove（子ノードの再帰削除）
// ========================================================================

/// 親を削除すると子も再帰的に削除される
///
///   root            (remove "root")
///    └─ a       →   空のシーン
///        └─ b
///
@Test
def testSceneRemoveRecursive(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(0.0f32, 0.0f32))
        |> Scene.addChildAt("root" :: "a" :: Nil, "b", tnode(0.0f32, 0.0f32))
        |> Scene.remove("root");
    Assert.assertEq(expected = 0, Scene.nodeCount(scene))

/// 中間ノードを削除すると、その子も消え、親の children から除去される
///
///   root              root
///    └─ a     →      (children = [])
///        └─ b
///
@Test
def testSceneRemoveMiddle(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(0.0f32, 0.0f32))
        |> Scene.addChildAt("root" :: "a" :: Nil, "b", tnode(0.0f32, 0.0f32))
        |> Scene.removeAt("root" :: "a" :: Nil);
    let aExists = Scene.getAt("root" :: "a" :: Nil, scene);
    let bExists = Scene.getAt("root" :: "a" :: "b" :: Nil, scene);
    let rootChildren = Scene.getChildren("root", scene);
    Assert.assertEq(
        expected = ((None: Option[TNode]), (None: Option[TNode]), (Nil: List[NodeName])),
        (aExists, bExists, rootChildren)
    )

// ========================================================================
// globalPosition
// ========================================================================

/// ルートノードの globalPosition はローカル座標と同じ
@Test
def testSceneGlobalPositionRoot(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(100.0f32, 50.0f32));
    let gp = Scene.globalPosition("root", scene);
    Assert.assertEq(expected = (100.0f32, 50.0f32), (gp#x, gp#y))

/// 親子の position が合算される
///
///   root (100, 100)
///    └─ a (50, 50)     → globalPositionAt("root"::"a"::Nil) = (150, 150)
///        └─ b (10, 10) → globalPositionAt("root"::"a"::"b"::Nil) = (160, 160)
///
@Test
def testSceneGlobalPositionChain(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(100.0f32, 100.0f32))
        |> Scene.addChild("root", "a", tnode(50.0f32, 50.0f32))
        |> Scene.addChildAt("root" :: "a" :: Nil, "b", tnode(10.0f32, 10.0f32));
    let gpA = Scene.globalPositionAt("root" :: "a" :: Nil, scene);
    let gpB = Scene.globalPositionAt("root" :: "a" :: "b" :: Nil, scene);
    Assert.assertEq(
        expected = (150.0f32, 150.0f32, 160.0f32, 160.0f32),
        (gpA#x, gpA#y, gpB#x, gpB#y)
    )

/// 親を移動すると、子・孫の globalPosition が連動して変わる
@Test
def testSceneMovingParentMovesChildren(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(100.0f32, 100.0f32))
        |> Scene.addChild("root", "a", tnode(50.0f32, 50.0f32))
        |> Scene.addChildAt("root" :: "a" :: Nil, "b", tnode(10.0f32, 10.0f32));
    let beforeA = Scene.globalPositionAt("root" :: "a" :: Nil, scene);
    let beforeB = Scene.globalPositionAt("root" :: "a" :: "b" :: Nil, scene);
    let moved = Scene.set("root", tnode(200.0f32, 200.0f32), scene);
    let afterA = Scene.globalPositionAt("root" :: "a" :: Nil, moved);
    let afterB = Scene.globalPositionAt("root" :: "a" :: "b" :: Nil, moved);
    Assert.assertEq(
        expected = (150.0f32, 150.0f32, 160.0f32, 160.0f32,
                    250.0f32, 250.0f32, 260.0f32, 260.0f32),
        (beforeA#x, beforeA#y, beforeB#x, beforeB#y,
         afterA#x,  afterA#y,  afterB#x,  afterB#y)
    )

/// 中間ノードを移動すると、その子だけが影響を受け、親は変わらない
@Test
def testSceneMovingMiddleNodeMovesDescendants(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(100.0f32, 100.0f32))
        |> Scene.addChild("root", "a", tnode(50.0f32, 50.0f32))
        |> Scene.addChildAt("root" :: "a" :: Nil, "b", tnode(10.0f32, 10.0f32))
        |> Scene.setAt("root" :: "a" :: Nil, tnode(200.0f32, 200.0f32));
    let gpRoot = Scene.globalPosition("root", scene);
    let gpA = Scene.globalPositionAt("root" :: "a" :: Nil, scene);
    let gpB = Scene.globalPositionAt("root" :: "a" :: "b" :: Nil, scene);
    Assert.assertEq(
        expected = (100.0f32, 100.0f32, 300.0f32, 300.0f32, 310.0f32, 310.0f32),
        (gpRoot#x, gpRoot#y, gpA#x, gpA#y, gpB#x, gpB#y)
    )

/// 存在しないノードの globalPosition は zero を返す
@Test
def testSceneGlobalPositionMissing(): Unit \ Assert =
    let scene: Scene[TNode] = Scene.empty();
    let gp = Scene.globalPosition("missing", scene);
    Assert.assertEq(expected = (0.0f32, 0.0f32), (gp#x, gp#y))

// ========================================================================
// setGlobalPosition
// ========================================================================

/// setGlobalPosition でグローバル座標を指定すると、ローカル座標が逆算される
@Test
def testSceneSetGlobalPosition(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(100.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(10.0f32, 0.0f32))
        |> Scene.setGlobalPositionAt("root" :: "a" :: Nil, {x = 200.0f32, y = 0.0f32});
    let localNode = Scene.getAt("root" :: "a" :: Nil, scene);
    let gp = Scene.globalPositionAt("root" :: "a" :: Nil, scene);
    Assert.assertEq(
        expected = (Some(tnode(100.0f32, 0.0f32)), 200.0f32, 0.0f32),
        (localNode, gp#x, gp#y)
    )

// ========================================================================
// preorderPaths
// ========================================================================

/// preorder 順でパスが返される（親→子、深さ優先）
///
///   root
///    ├─ a
///    │   └─ a1
///    └─ b
///
@Test
def testScenePreorderPaths(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(0.0f32, 0.0f32))
        |> Scene.addChildAt("root" :: "a" :: Nil, "a1", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "b", tnode(0.0f32, 0.0f32));
    let paths = Scene.preorderPaths(scene);
    Assert.assertEq(
        expected = ("root" :: Nil) :: ("root" :: "a" :: Nil) :: ("root" :: "a" :: "a1" :: Nil) :: ("root" :: "b" :: Nil) :: Nil,
        paths
    )

/// 複数ルートの場合、roots のキー順で走査される
@Test
def testScenePreorderMultipleRoots(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("x", tnode(0.0f32, 0.0f32))
        |> Scene.addNode("y", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("x", "x1", tnode(0.0f32, 0.0f32));
    let paths = Scene.preorderPaths(scene);
    Assert.assertEq(
        expected = ("x" :: Nil) :: ("x" :: "x1" :: Nil) :: ("y" :: Nil) :: Nil,
        paths
    )

// ========================================================================
// nodeCount
// ========================================================================

/// nodeCount はツリー全体のノード数を返す
@Test
def testSceneNodeCount(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(0.0f32, 0.0f32))
        |> Scene.addChildAt("root" :: "a" :: Nil, "b", tnode(0.0f32, 0.0f32));
    Assert.assertEq(expected = 3, Scene.nodeCount(scene))

// ========================================================================
// readyAll / processAll（preorder 順で実行される）
// ========================================================================

/// readyAll はエラーなく全ノードを走査できる
@Test
def testSceneReadyAll(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(1.0f32, 0.0f32))
        |> Scene.readyAll;
    Assert.assertEq(expected = Some(tnode(1.0f32, 0.0f32)), Scene.getAt("root" :: "a" :: Nil, scene))

/// processAll はエラーなく全ノードを走査できる
@Test
def testSceneProcessAll(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(1.0f32, 0.0f32))
        |> Scene.processAll(0.016f64, false);
    Assert.assertEq(expected = Some(tnode(1.0f32, 0.0f32)), Scene.getAt("root" :: "a" :: Nil, scene))

// ========================================================================
// 同名子ノードの衝突テスト（新規）
// ========================================================================

/// 異なる親の下に同名の子ノードを追加しても衝突しない
@Test
def testSceneSameChildNameDifferentParents(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("frog", tnode(0.0f32, 0.0f32))
        |> Scene.addNode("turtle", tnode(10.0f32, 0.0f32))
        |> Scene.addChild("frog", "sprite", tnode(1.0f32, 1.0f32))
        |> Scene.addChild("turtle", "sprite", tnode(2.0f32, 2.0f32));
    let frogSprite = Scene.getAt("frog" :: "sprite" :: Nil, scene);
    let turtleSprite = Scene.getAt("turtle" :: "sprite" :: Nil, scene);
    Assert.assertEq(
        expected = (Some(tnode(1.0f32, 1.0f32)), Some(tnode(2.0f32, 2.0f32))),
        (frogSprite, turtleSprite)
    )
