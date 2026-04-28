pub type alias NodeName = String

/// ノードエントリ: ノード本体 + 親子関係を保持する
pub type alias SceneEntry[n] = {
    node = n,
    parent = Option[NodeName],
    children = List[NodeName]
}

/// シーン: フラット Map でノードを管理しつつ、各エントリに親子参照を持たせる。
/// roots にツリーのルートノード名を保持する。
pub enum Scene[n] {
    case Scene({
        entries = Map[NodeName, SceneEntry[n]],
        roots = List[NodeName]
    })
}

pub mod Scene {

    // ========================================================================
    // 内部ヘルパー
    // ========================================================================

    /// Scene の entries マップを取り出す
    def entries(scene: Scene[n]): Map[NodeName, SceneEntry[n]] =
        let Scene.Scene(r) = scene;
        r#entries

    /// Scene の roots リストを取り出す
    def getRoots(scene: Scene[n]): List[NodeName] =
        let Scene.Scene(r) = scene;
        r#roots

    /// entries を差し替えた新しい Scene を返す
    def withEntries(newEntries: Map[NodeName, SceneEntry[n]], scene: Scene[n]): Scene[n] =
        let Scene.Scene(r) = scene;
        Scene.Scene({ entries = newEntries | r })

    /// 指定ノードから深さ優先（preorder）で名前リストを返す
    def preorderFrom(name: NodeName, entryMap: Map[NodeName, SceneEntry[n]]): List[NodeName] =
        match Map.get(name, entryMap) {
            case None       => Nil
            case Some(entry) =>
                name :: List.flatMap(child -> preorderFrom(child, entryMap), entry#children)
        }

    /// 指定ノードとその子孫を entries から再帰的に削除する。
    /// 親の children リストは更新しない（呼び出し元で処理する）。
    def removeSubtree(name: NodeName, sceneRef: Ref[Scene[n], rc]): Unit \ rc with Order[n] =
        match Map.get(name, entries(Ref.get(sceneRef))) {
            case None => ()
            case Some(entry) =>
                List.forEach(child -> removeSubtree(child, sceneRef), entry#children);
                let scene = Ref.get(sceneRef);
                Ref.put(withEntries(Map.remove(name, entries(scene)), scene), sceneRef)
        }

    // ========================================================================
    // 基本操作（既存 API 互換）
    // ========================================================================

    /// 空のシーンを返す
    pub def empty(): Scene[n] =
        Scene.Scene({ entries = Map.empty(), roots = Nil })

    /// ルートノードとして追加する。
    /// 同名のノードが既にある場合は上書きされる。
    pub def addNode(name: NodeName, node: n, scene: Scene[n]): Scene[n] with Order[n] =
        let entry: SceneEntry[n] = { node = node, parent = None, children = Nil };
        let newEntries = Map.insert(name, entry, entries(scene));
        let newRoots = if (List.exists(r -> r == name, getRoots(scene)))
                           getRoots(scene)
                       else
                           List.append(getRoots(scene), name :: Nil);
        Scene.Scene({ entries = newEntries, roots = newRoots })

    /// ノードの値を取得する（O(log n)）
    pub def get(name: NodeName, scene: Scene[n]): Option[n] with Order[n] =
        Map.get(name, entries(scene)) |> Option.map(entry -> entry#node)

    /// ノードの値を更新する。ツリー構造（親子関係）は変更しない。
    pub def set(name: NodeName, node: n, scene: Scene[n]): Scene[n] with Order[n] =
        match Map.get(name, entries(scene)) {
            case None        => scene
            case Some(entry) =>
                let updated = { node = node | entry };
                Map.insert(name, updated, entries(scene))
                    |> flip -> withEntries(flip, scene)
        }

    /// ノードを削除する。子ノードも再帰的に削除し、親の children リストからも除去する。
    pub def remove(name: NodeName, scene: Scene[n]): Scene[n] with Order[n] =
        match Map.get(name, entries(scene)) {
            case None => scene
            case Some(entry) =>
                region rc {
                    let sceneRef = Ref.fresh(rc, scene);
                    // 子孫を再帰的に entries から削除
                    List.forEach(child -> removeSubtree(child, sceneRef), entry#children);
                    // 自身を entries から削除
                    let s1 = Ref.get(sceneRef);
                    let s2 = withEntries(Map.remove(name, entries(s1)), s1);
                    // 親の children リストから自分を除去
                    match entry#parent {
                        case None =>
                            let newRoots = List.filter(rootName -> rootName != name, getRoots(s2));
                            let Scene.Scene(rec) = s2;
                            Scene.Scene({ roots = newRoots | rec })
                        case Some(parentName) =>
                            match Map.get(parentName, entries(s2)) {
                                case None => s2
                                case Some(parentEntry) =>
                                    let newChildren = List.filter(c -> c != name, parentEntry#children);
                                    let updatedParent = { children = newChildren | parentEntry };
                                    withEntries(Map.insert(parentName, updatedParent, entries(s2)), s2)
                            }
                    }
                }
        }

    /// 後方互換: 全ノードを Map[NodeName, n] として返す
    pub def nodes(scene: Scene[n]): Map[NodeName, n] =
        Map.map(entry -> entry#node, entries(scene))

    // ========================================================================
    // ツリー操作（新規）
    // ========================================================================

    /// 親ノードの子としてノードを追加する。
    /// 親が存在しない場合はシーンをそのまま返す。
    pub def addChild(parentName: NodeName, childName: NodeName, node: n, scene: Scene[n]): Scene[n] with Order[n] =
        match Map.get(parentName, entries(scene)) {
            case None => scene
            case Some(parentEntry) =>
                let childEntry: SceneEntry[n] = { node = node, parent = Some(parentName), children = Nil };
                let updatedParent = { children = List.append(parentEntry#children, childName :: Nil) | parentEntry };
                entries(scene)
                    |> Map.insert(childName, childEntry)
                    |> Map.insert(parentName, updatedParent)
                    |> flip -> withEntries(flip, scene)
        }

    /// 指定ノードの親の名前を返す
    pub def getParent(name: NodeName, scene: Scene[n]): Option[NodeName] =
        Map.get(name, entries(scene)) |> Option.flatMap(entry -> entry#parent)

    /// 指定ノードの子の名前リストを返す
    pub def getChildren(name: NodeName, scene: Scene[n]): List[NodeName] =
        match Map.get(name, entries(scene)) {
            case None        => Nil
            case Some(entry) => entry#children
        }

    // ========================================================================
    // 座標（新規）
    // ========================================================================

    /// 祖先の位置を合算したグローバル座標を返す。
    /// parent チェーンを辿り、各ノードの position を加算する。
    pub def globalPosition(name: NodeName, scene: Scene[n]): Vec2.Vec2 with Node2D[n], Order[n] =
        match Map.get(name, entries(scene)) {
            case None        => Vec2.zero()
            case Some(entry) =>
                let localPos = Node2D.getPosition(entry#node);
                match entry#parent {
                    case None            => localPos
                    case Some(parentName) => Vec2.add(localPos, globalPosition(parentName, scene))
                }
        }

    /// グローバル座標を指定して、ローカル座標を逆算して設定する。
    /// globalPos - 親のグローバル座標 = 新しいローカル座標
    pub def setGlobalPosition(name: NodeName, globalPos: Vec2.Vec2, scene: Scene[n]): Scene[n] with Node2D[n], Order[n] =
        match Map.get(name, entries(scene)) {
            case None => scene
            case Some(entry) =>
                let parentGlobal = match entry#parent {
                    case None            => Vec2.zero()
                    case Some(parentName) => globalPosition(parentName, scene)
                };
                let newLocal = Vec2.sub(globalPos, parentGlobal);
                let updatedNode = Node2D.setPosition(newLocal, entry#node);
                let updatedEntry = { node = updatedNode | entry };
                Map.insert(name, updatedEntry, entries(scene))
                    |> flip -> withEntries(flip, scene)
        }

    // ========================================================================
    // 走査順序
    // ========================================================================

    /// ツリーを preorder（深さ優先・親が先）で走査した名前リストを返す
    pub def preorderNames(scene: Scene[n]): List[NodeName] =
        let entryMap = entries(scene);
        List.flatMap(root -> preorderFrom(root, entryMap), getRoots(scene))

    // ========================================================================
    // ライフサイクル
    // ========================================================================

    /// 全ノードの ready を preorder（親→子）の順で呼び出す
    pub def readyAll(scene: Scene[n]): Scene[n] with Node[n] =
        let names = preorderNames(scene);
        region rc {
            let sceneRef = Ref.fresh(rc, scene);
            List.forEach(name -> {
                match get(name, Ref.get(sceneRef)) {
                    case None => ()
                    case Some(current) =>
                        let (updated, s1) = Node.ready(current, name, Ref.get(sceneRef));
                        Ref.put(set(name, updated, s1), sceneRef)
                }
            }, names);
            Ref.get(sceneRef)
        }

    /// 全ノードの process を preorder（親→子）の順で呼び出す
    pub def processAll(delta: Float64, paused: Bool, scene: Scene[n]): Scene[n] with Node[n] =
        let names = preorderNames(scene);
        region rc {
            let sceneRef = Ref.fresh(rc, scene);
            List.forEach(name -> {
                match get(name, Ref.get(sceneRef)) {
                    case None => ()
                    case Some(current) =>
                        let mode = Node.getProcessMode(current);
                        if (ProcessMode.shouldProcess(paused, mode))
                            let (updated, s1) = Node.process(delta, current, name, Ref.get(sceneRef));
                            Ref.put(set(name, updated, s1), sceneRef)
                        else
                            ()
                }
            }, names);
            Ref.get(sceneRef)
        }
}
