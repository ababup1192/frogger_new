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

instance Node[TNode] {
    pub def getSelf(name: NodeName, scene: Scene[TNode]): Option[TNode] =
        Scene.get(name, scene)
    pub def setSelf(name: NodeName, self: TNode, scene: Scene[TNode]): Scene[TNode] =
        Scene.set(name, self, scene)
}

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

/// nodes は全ノードを Map[NodeName, n] として返す
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
    let parent = Scene.getParent("child", scene);
    let children = Scene.getChildren("root", scene);
    Assert.assertEq(expected = (Some("root"), "child" :: Nil), (parent, children))

/// addChild で追加した子ノードを get で取得できる
@Test
def testSceneAddChildGet(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "child", tnode(10.0f32, 0.0f32));
    Assert.assertEq(expected = Some(tnode(10.0f32, 0.0f32)), Scene.get("child", scene))

/// 存在しない親への addChild はシーンを変更しない
@Test
def testSceneAddChildMissingParent(): Unit \ Assert =
    let scene: Scene[TNode] = Scene.empty()
        |> Scene.addChild("ghost", "child", tnode(0.0f32, 0.0f32));
    Assert.assertEq(expected = 0, Scene.nodes(scene) |> Map.size)

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
        |> Scene.addChild("a", "b", tnode(0.0f32, 0.0f32));
    let parentOfB = Scene.getParent("b", scene);
    let childrenOfA = Scene.getChildren("a", scene);
    Assert.assertEq(expected = (Some("a"), "b" :: Nil), (parentOfB, childrenOfA))

/// ルートノードの getParent は None を返す
@Test
def testSceneGetParentRoot(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32));
    Assert.assertEq(expected = (None: Option[NodeName]), Scene.getParent("root", scene))

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
        |> Scene.addChild("a", "b", tnode(0.0f32, 0.0f32))
        |> Scene.remove("root");
    Assert.assertEq(expected = 0, Scene.nodes(scene) |> Map.size)

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
        |> Scene.addChild("a", "b", tnode(0.0f32, 0.0f32))
        |> Scene.remove("a");
    let aExists = Scene.get("a", scene);
    let bExists = Scene.get("b", scene);
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
///    └─ a (50, 50)     → globalPosition("a") = (150, 150)
///        └─ b (10, 10) → globalPosition("b") = (160, 160)
///
@Test
def testSceneGlobalPositionChain(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(100.0f32, 100.0f32))
        |> Scene.addChild("root", "a", tnode(50.0f32, 50.0f32))
        |> Scene.addChild("a", "b", tnode(10.0f32, 10.0f32));
    let gpA = Scene.globalPosition("a", scene);
    let gpB = Scene.globalPosition("b", scene);
    Assert.assertEq(
        expected = (150.0f32, 150.0f32, 160.0f32, 160.0f32),
        (gpA#x, gpA#y, gpB#x, gpB#y)
    )

/// 親を移動すると、子・孫の globalPosition が連動して変わる
///
///   【移動前】                         【移動後: root を (100,100) → (200,200) に変更】
///   root (100, 100)                   root (200, 200)
///    └─ a (50, 50)                     └─ a (50, 50)
///        └─ b (10, 10)                     └─ b (10, 10)
///
///   a: (150, 150) → (250, 250)
///   b: (160, 160) → (260, 260)
///
@Test
def testSceneMovingParentMovesChildren(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(100.0f32, 100.0f32))
        |> Scene.addChild("root", "a", tnode(50.0f32, 50.0f32))
        |> Scene.addChild("a", "b", tnode(10.0f32, 10.0f32));
    // 移動前を確認
    let beforeA = Scene.globalPosition("a", scene);
    let beforeB = Scene.globalPosition("b", scene);
    // 親を移動
    let moved = Scene.set("root", tnode(200.0f32, 200.0f32), scene);
    let afterA = Scene.globalPosition("a", moved);
    let afterB = Scene.globalPosition("b", moved);
    Assert.assertEq(
        expected = (150.0f32, 150.0f32, 160.0f32, 160.0f32,
                    250.0f32, 250.0f32, 260.0f32, 260.0f32),
        (beforeA#x, beforeA#y, beforeB#x, beforeB#y,
         afterA#x,  afterA#y,  afterB#x,  afterB#y)
    )

/// 中間ノードを移動すると、その子だけが影響を受け、親は変わらない
///
///   root (100, 100)                          root (100, 100)  ← 変化なし
///    └─ a (50, 50)  → a を (200, 200) に →    └─ a (200, 200)
///        └─ b (10, 10)                            └─ b (10, 10)
///
///   root: (100, 100) → (100, 100)
///   a:    (150, 150) → (300, 300)
///   b:    (160, 160) → (310, 310)
///
@Test
def testSceneMovingMiddleNodeMovesDescendants(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(100.0f32, 100.0f32))
        |> Scene.addChild("root", "a", tnode(50.0f32, 50.0f32))
        |> Scene.addChild("a", "b", tnode(10.0f32, 10.0f32))
        |> Scene.set("a", tnode(200.0f32, 200.0f32));
    let gpRoot = Scene.globalPosition("root", scene);
    let gpA = Scene.globalPosition("a", scene);
    let gpB = Scene.globalPosition("b", scene);
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
///
///   root (100, 0)
///    └─ a (10, 0)   → setGlobalPosition("a", (200, 0))
///                    → a のローカル座標は (100, 0) になる
///
@Test
def testSceneSetGlobalPosition(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(100.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(10.0f32, 0.0f32))
        |> Scene.setGlobalPosition("a", {x = 200.0f32, y = 0.0f32});
    let localNode = Scene.get("a", scene);
    let gp = Scene.globalPosition("a", scene);
    Assert.assertEq(
        expected = (Some(tnode(100.0f32, 0.0f32)), 200.0f32, 0.0f32),
        (localNode, gp#x, gp#y)
    )

// ========================================================================
// preorderNames
// ========================================================================

/// preorder 順でノード名が返される（親→子、深さ優先）
///
///   root
///    ├─ a
///    │   └─ a1
///    └─ b
///
///   preorder: root → a → a1 → b
///
@Test
def testScenePreorderNames(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("a", "a1", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "b", tnode(0.0f32, 0.0f32));
    Assert.assertEq(expected = "root" :: "a" :: "a1" :: "b" :: Nil, Scene.preorderNames(scene))

/// 複数ルートの場合、roots の順で走査される
@Test
def testScenePreorderMultipleRoots(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("x", tnode(0.0f32, 0.0f32))
        |> Scene.addNode("y", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("x", "x1", tnode(0.0f32, 0.0f32));
    Assert.assertEq(expected = "x" :: "x1" :: "y" :: Nil, Scene.preorderNames(scene))

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
    Assert.assertEq(expected = Some(tnode(1.0f32, 0.0f32)), Scene.get("a", scene))

/// processAll はエラーなく全ノードを走査できる
@Test
def testSceneProcessAll(): Unit \ Assert =
    let scene = Scene.empty()
        |> Scene.addNode("root", tnode(0.0f32, 0.0f32))
        |> Scene.addChild("root", "a", tnode(1.0f32, 0.0f32))
        |> Scene.processAll(0.016f64, false);
    Assert.assertEq(expected = Some(tnode(1.0f32, 0.0f32)), Scene.get("a", scene))