pub type alias NodeName = String
pub type alias NodePath = List[NodeName]

/// ノードエントリ: ノード本体 + 子ノードを再帰的に内包する
pub enum SceneEntry[n] {
    case SceneEntry({
        node = n,
        children = Map[NodeName, SceneEntry[n]]
    })
}

/// シーン: ルートノードのみを Map で保持し、各 SceneEntry が子を再帰的に内包する
pub enum Scene[n] {
    case Scene({
        nodes = Map[NodeName, SceneEntry[n]],
        readied = Bool,
        prevOverlaps = OverlapPairSet
    })
}

pub mod Scene {

    // ========================================================================
    // 内部ヘルパー
    // ========================================================================

    /// Scene のルート Map を取り出す
    def roots(scene: Scene[n]): Map[NodeName, SceneEntry[n]] =
        let Scene.Scene(r) = scene;
        r#nodes

    /// readied フラグを取り出す
    def isReady(scene: Scene[n]): Bool =
        let Scene.Scene(r) = scene;
        r#readied

    /// readied=true でシーンを再構築する
    def markReady(scene: Scene[n]): Scene[n] =
        let Scene.Scene(r) = scene;
        Scene.Scene({ readied = true | r })

    /// 前フレームの重なりペアセットを取り出す
    pub def getPrevOverlaps(scene: Scene[n]): OverlapPairSet =
        let Scene.Scene(r) = scene;
        r#prevOverlaps

    /// 前フレームの重なりペアセットを設定する
    pub def setPrevOverlaps(overlaps: OverlapPairSet, scene: Scene[n]): Scene[n] =
        let Scene.Scene(r) = scene;
        Scene.Scene({ prevOverlaps = overlaps | r })

    /// SceneEntry のノードを取り出す
    def entryNode(entry: SceneEntry[n]): n =
        let SceneEntry.SceneEntry(r) = entry;
        r#node

    /// SceneEntry の children を取り出す
    def entryChildren(entry: SceneEntry[n]): Map[NodeName, SceneEntry[n]] =
        let SceneEntry.SceneEntry(r) = entry;
        r#children

    /// パスをたどって SceneEntry を取得
    def getEntryAt(path: NodePath, scene: Scene[n]): Option[SceneEntry[n]] =
        match path {
            case Nil => None
            case name :: rest =>
                Map.get(name, roots(scene))
                    |> Option.flatMap(entry -> getEntryIn(rest, entry))
        }

    /// SceneEntry 内のパスをたどって子孫の SceneEntry を取得
    def getEntryIn(path: NodePath, entry: SceneEntry[n]): Option[SceneEntry[n]] =
        match path {
            case Nil => Some(entry)
            case name :: rest =>
                Map.get(name, entryChildren(entry))
                    |> Option.flatMap(child -> getEntryIn(rest, child))
        }

    /// パスをたどってノード値を取得
    pub def getAt(path: NodePath, scene: Scene[n]): Option[n] =
        getEntryAt(path, scene) |> Option.map(entryNode)

    // ========================================================================
    // ツリー変換（高階関数によるパス走査の共通化）
    // ========================================================================

    /// SceneEntry 内のパスをたどり、末端のエントリに f を適用して再構築する
    def modifyEntryIn(path: NodePath, f: SceneEntry[n] -> SceneEntry[n],
                      entry: SceneEntry[n]): SceneEntry[n] =
        let SceneEntry.SceneEntry(r) = entry;
        match path {
            case Nil => f(entry)
            case name :: rest =>
                match Map.get(name, r#children) {
                    case None => entry
                    case Some(child) =>
                        let updatedChild = modifyEntryIn(rest, f, child);
                        SceneEntry.SceneEntry({ children = Map.insert(name, updatedChild, r#children) | r })
                }
        }

    /// パスで指定されたエントリに f を適用し、Scene を再構築する
    def modifyAt(path: NodePath, f: SceneEntry[n] -> SceneEntry[n],
                 scene: Scene[n]): Scene[n] =
        match path {
            case Nil => scene
            case rootName :: rest =>
                let Scene.Scene(r) = scene;
                match Map.get(rootName, r#nodes) {
                    case None => scene
                    case Some(rootEntry) =>
                        let updated = modifyEntryIn(rest, f, rootEntry);
                        Scene.Scene({ nodes = Map.insert(rootName, updated, r#nodes) | r })
                }
        }

    /// パスの末尾を除いた親パスを返す（List.dropRight(1) の代替）
    def initPath(path: NodePath): NodePath =
        match List.reverse(path) {
            case Nil => Nil
            case _ :: rest => List.reverse(rest)
        }

    /// SceneEntry から深さ優先（preorder）でパスリストを返す
    def preorderFromEntry(prefix: NodePath, entry: SceneEntry[n]): List[NodePath] =
        let myPath = prefix;
        let childPaths = Map.foldLeftWithKey((acc, childName, childEntry) ->
            List.append(acc, preorderFromEntry(List.append(prefix, childName :: Nil), childEntry)),
            Nil,
            entryChildren(entry));
        myPath :: childPaths

    // ========================================================================
    // 基本操作（既存 API 互換）
    // ========================================================================

    /// 空のシーンを返す
    pub def empty(): Scene[n] =
        Scene.Scene({ nodes = Map.empty(), readied = false, prevOverlaps = Set.empty() })

    /// ルートノードとして追加する
    pub def addNode(name: NodeName, node: n, scene: Scene[n]): Scene[n] =
        let Scene.Scene(r) = scene;
        let entry = SceneEntry.SceneEntry({ node = node, children = Map.empty() });
        Scene.Scene({ nodes = Map.insert(name, entry, r#nodes) | r })

    /// 親がルートの子追加（既存互換）
    pub def addChild(parentName: NodeName, childName: NodeName, node: n, scene: Scene[n]): Scene[n] =
        addChildAt(parentName :: Nil, childName, node, scene)

    /// 任意深さの子追加
    pub def addChildAt(parentPath: NodePath, childName: NodeName, node: n, scene: Scene[n]): Scene[n] =
        match getEntryAt(parentPath, scene) {
            case None => scene
            case Some(_) =>
                let childEntry = SceneEntry.SceneEntry({ node = node, children = Map.empty() });
                modifyAt(parentPath, entry ->
                    let SceneEntry.SceneEntry(r) = entry;
                    SceneEntry.SceneEntry({ children = Map.insert(childName, childEntry, r#children) | r }),
                    scene)
        }

    /// パスをたどってノード値を更新
    pub def setAt(path: NodePath, node: n, scene: Scene[n]): Scene[n] =
        modifyAt(path, entry ->
            let SceneEntry.SceneEntry(r) = entry;
            SceneEntry.SceneEntry({ node = node | r }),
            scene)

    /// ルート取得（既存互換）
    pub def get(name: NodeName, scene: Scene[n]): Option[n] =
        getAt(name :: Nil, scene)

    /// ルート更新（既存互換）
    pub def set(name: NodeName, node: n, scene: Scene[n]): Scene[n] =
        setAt(name :: Nil, node, scene)

    /// パスで指定されたノードに関数を適用する（ノードが見つからない場合は変更なし）
    pub def mapAt(path: NodePath, f: n -> n, scene: Scene[n]): Scene[n] =
        modifyAt(path, entry ->
            let SceneEntry.SceneEntry(r) = entry;
            SceneEntry.SceneEntry({ node = f(r#node) | r }),
            scene)

    /// ルート削除（既存互換）
    pub def remove(name: NodeName, scene: Scene[n]): Scene[n] =
        removeAt(name :: Nil, scene)

    /// パスで削除
    pub def removeAt(path: NodePath, scene: Scene[n]): Scene[n] =
        let Scene.Scene(sr) = scene;
        match List.reverse(path) {
            case Nil => scene
            case childName :: Nil =>
                Scene.Scene({ nodes = Map.remove(childName, sr#nodes) | sr })
            case childName :: parentRev =>
                modifyAt(List.reverse(parentRev), entry ->
                    let SceneEntry.SceneEntry(r) = entry;
                    SceneEntry.SceneEntry({ children = Map.remove(childName, r#children) | r }),
                    scene)
        }

    /// 後方互換: ルートノードを Map[NodeName, n] として返す
    pub def nodes(scene: Scene[n]): Map[NodeName, n] =
        Map.map(entryNode, roots(scene))

    /// 全ノード数（ツリー全体の再帰カウント）
    pub def nodeCount(scene: Scene[n]): Int32 =
        Map.foldLeft((acc, entry) -> acc + countEntry(entry), 0, roots(scene))

    /// SceneEntry のノード数（自分 + 子孫）
    def countEntry(entry: SceneEntry[n]): Int32 =
        1 + Map.foldLeft((acc, child) -> acc + countEntry(child), 0, entryChildren(entry))

    // ========================================================================
    // ツリー操作
    // ========================================================================

    /// ルートの子名リスト
    pub def getChildren(name: NodeName, scene: Scene[n]): List[NodeName] =
        getChildrenAt(name :: Nil, scene)

    /// 任意ノードの子名リスト
    pub def getChildrenAt(path: NodePath, scene: Scene[n]): List[NodeName] =
        match getEntryAt(path, scene) {
            case None => Nil
            case Some(entry) => Map.keysOf(entryChildren(entry)) |> Set.toList
        }

    /// パスから親パスを返す
    pub def getParent(path: NodePath, scene: Scene[n]): Option[NodePath] =
        match path {
            case Nil => None
            case _ :: Nil =>
                // ルートノード → 親はいない
                // ただし、そのルートが存在するか確認
                match getEntryAt(path, scene) {
                    case None => None
                    case Some(_) => None
                }
            case _ =>
                let pp = initPath(path);
                match getEntryAt(pp, scene) {
                    case None => None
                    case Some(_) => Some(pp)
                }
        }

    // ========================================================================
    // 走査順序
    // ========================================================================

    /// 全ノードのパスを深さ優先順（preorder）で返す
    pub def preorderPaths(scene: Scene[n]): List[NodePath] =
        Map.foldLeftWithKey((acc, name, entry) ->
            List.append(acc, preorderFromEntry(name :: Nil, entry)),
            Nil,
            roots(scene))

    // ========================================================================
    // 座標
    // ========================================================================

    /// パスでグローバル座標を計算
    pub def globalPositionAt(path: NodePath, scene: Scene[n]): Vec2.Vec2 with Node2D[n] =
        match path {
            case Nil => Vec2.zero()
            case name :: Nil =>
                match getAt(name :: Nil, scene) {
                    case None => Vec2.zero()
                    case Some(node) => Node2D.getPosition(node)
                }
            case _ =>
                match getAt(path, scene) {
                    case None => Vec2.zero()
                    case Some(node) =>
                        let localPos = Node2D.getPosition(node);
                        Vec2.add(localPos, globalPositionAt(initPath(path), scene))
                }
        }

    /// ルートのグローバル座標（後方互換）
    pub def globalPosition(name: NodeName, scene: Scene[n]): Vec2.Vec2 with Node2D[n] =
        globalPositionAt(name :: Nil, scene)

    /// パスでグローバル座標を設定（ローカル座標を逆算）
    pub def setGlobalPositionAt(path: NodePath, globalPos: Vec2.Vec2, scene: Scene[n]): Scene[n] with Node2D[n] =
        match getAt(path, scene) {
            case None => scene
            case Some(node) =>
                let pp = initPath(path);
                let parentGlobal = if (List.length(pp) == 0)
                                       Vec2.zero()
                                   else
                                       globalPositionAt(pp, scene);
                let newLocal = Vec2.sub(globalPos, parentGlobal);
                let updatedNode = Node2D.setPosition(newLocal, node);
                setAt(path, updatedNode, scene)
        }

    /// ルートノードのグローバル座標設定（後方互換）
    pub def setGlobalPosition(name: NodeName, globalPos: Vec2.Vec2, scene: Scene[n]): Scene[n] with Node2D[n] =
        setGlobalPositionAt(name :: Nil, globalPos, scene)

    // ========================================================================
    // type-based 子ノード更新（GameNode 専用）
    // ========================================================================

    /// 親パス配下の最初の SpriteNode を探し f を適用する
    pub def updateSpriteChild(parentPath: NodePath, f: Sprite2D -> Sprite2D, scene: Scene[GameNode]): Scene[GameNode] =
        match getEntryAt(parentPath, scene) {
            case None => scene
            case Some(parentEntry) =>
                match Map.findLeft((_, childEntry) -> match entryNode(childEntry) {
                    case GameNode.SpriteNode(_) => true
                    case _ => false
                }, entryChildren(parentEntry)) {
                    case Some((childName, _)) =>
                        let childPath = List.append(parentPath, childName :: Nil);
                        match getAt(childPath, scene) {
                            case Some(GameNode.SpriteNode(sprite)) =>
                                setAt(childPath, GameNode.SpriteNode(f(sprite)), scene)
                            case _ => scene
                        }
                    case None => scene
                }
        }

    // ========================================================================
    // ライフサイクル
    // ========================================================================

    /// 全ノードを preorder で走査し、変換関数を順次適用する（Region で状態をスレッドする）
    def foldNodes(f: (n, NodePath, Scene[n]) -> (n, Scene[n]) \ ef,
                  scene: Scene[n]): Scene[n] \ ef =
        let paths = preorderPaths(scene);
        region rc {
            let sceneRef = Ref.fresh(rc, scene);
            List.forEach(path -> {
                match getAt(path, Ref.get(sceneRef)) {
                    case None => ()
                    case Some(current) =>
                        let (updated, s1) = f(current, path, Ref.get(sceneRef));
                        Ref.put(setAt(path, updated, s1), sceneRef)
                }
            }, paths);
            Ref.get(sceneRef)
        }

    /// 全ノードの ready を preorder（親→子）の順で呼び出し、readied フラグを立てる
    def readyAll(scene: Scene[n]): Scene[n] with Node[n] =
        foldNodes((node, path, sc) -> Node.ready(node, path, sc), scene)
            |> markReady

    /// 全ノードの process を preorder（親→子）の順で呼び出す
    /// 初回呼び出し時は自動で readyAll を実行する
    pub def processAll(delta: Float64, paused: Bool, scene: Scene[n]): Scene[n] \ Engine.Game with Node[n] =
        let scene1 = if (not isReady(scene)) readyAll(scene) else scene;
        foldNodes((node, path, sc) ->
            if (ProcessMode.shouldProcess(paused, Node.getProcessMode(node)))
                Node.process(delta, node, path, sc)
            else
                (node, sc),
            scene1)

    // ========================================================================
    // 描画
    // ========================================================================

    /// Node2D / CanvasItem のプロパティから Drawable を組み立てる
    pub def toDrawable(texture: String, node: n, globalPos: Vec2.Vec2): Engine.Drawable with Node2D[n] =
        {
            texture = texture,
            position = globalPos,
            scale = Node2D.getScale(node),
            rotation = Float64.truncateToFloat32(Node2D.getRotation(node)),
            color = CanvasItem.getModulate(node),
            centered = true,
            uvOffset = {x = 0.0f32, y = 0.0f32},
            uvScale = {x = 1.0f32, y = 1.0f32},
            zIndex = CanvasItem.getZIndex(node)
        }

    /// 可視ノードを Drawable のリストに変換する
    /// 各ノードが複数 Drawable を返せるよう flatMap ベースで処理する
    pub def toDrawables(scene: Scene[n]): List[Engine.Drawable] with Node2D[n], Engine.Renderable[n] =
        preorderPaths(scene)
            |> List.flatMap(path ->
                match getAt(path, scene) {
                    case Some(node) =>
                        if (CanvasItem.isVisible(node))
                            Engine.Renderable.toDrawables(node, globalPositionAt(path, scene))
                        else Nil
                    case None => Nil
                }
            )
            |> List.sortBy(d -> d#zIndex)
}
