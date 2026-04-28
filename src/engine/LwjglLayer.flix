// LWJGL rendering backend — handles Engine.Game effect with OpenGL (minimal)

mod LwjglLayer {
    import org.lwjgl.glfw.GLFW
    import org.lwjgl.glfw.Callbacks
    import org.lwjgl.opengl.GL
    import org.lwjgl.opengl.GL11
    import org.lwjgl.opengl.GL13
    import org.lwjgl.opengl.GL15
    import org.lwjgl.opengl.GL20
    import org.lwjgl.opengl.GL30
    import org.lwjgl.stb.STBImage
    import org.lwjgl.system.MemoryStack
    import org.lwjgl.system.MemoryUtil
    import java.lang.System

    // ========================================================================
    // Shader Sources
    // ========================================================================

    def vertexShaderSource(): String =
        "#version 330 core\n" +
        "layout (location = 0) in vec4 vertex;\n" +
        "out vec2 TexCoords;\n" +
        "uniform mat4 model;\n" +
        "uniform mat4 projection;\n" +
        "uniform vec2 uvOffset;\n" +
        "uniform vec2 uvScale;\n" +
        "void main() {\n" +
        "    TexCoords = vertex.zw * uvScale + uvOffset;\n" +
        "    gl_Position = projection * model * vec4(vertex.xy, 0.0, 1.0);\n" +
        "}\n"

    def fragmentShaderSource(): String =
        "#version 330 core\n" +
        "in vec2 TexCoords;\n" +
        "out vec4 color;\n" +
        "uniform sampler2D image;\n" +
        "uniform vec3 spriteColor;\n" +
        "void main() {\n" +
        "    color = vec4(spriteColor, 1.0) * texture(image, TexCoords);\n" +
        "}\n"

    // ========================================================================
    // Shader Compilation
    // ========================================================================

    def compileShader(source: String, shaderType: Int32): Int32 \ IO =
        let shader = GL20.glCreateShader(shaderType);
        GL20.glShaderSource(shader, source);
        GL20.glCompileShader(shader);
        let success = GL20.glGetShaderi(shader, GL20.GL_COMPILE_STATUS);
        if (success == GL11.GL_FALSE) {
            let log = GL20.glGetShaderInfoLog(shader, 1024);
            println("Shader compilation error: ${log}");
            bug!("Shader failed")
        } else ();
        shader

    def createShaderProgram(vertexSrc: String, fragmentSrc: String): Int32 \ IO =
        let vs = compileShader(vertexSrc, GL20.GL_VERTEX_SHADER);
        let fs = compileShader(fragmentSrc, GL20.GL_FRAGMENT_SHADER);
        let program = GL20.glCreateProgram();
        GL20.glAttachShader(program, vs);
        GL20.glAttachShader(program, fs);
        GL20.glLinkProgram(program);
        let success = GL20.glGetProgrami(program, GL20.GL_LINK_STATUS);
        if (success == GL11.GL_FALSE) {
            let log = GL20.glGetProgramInfoLog(program, 1024);
            println("Shader linking error: ${log}");
            bug!("Linking failed")
        } else ();
        GL20.glDeleteShader(vs);
        GL20.glDeleteShader(fs);
        program

    // ========================================================================
    // Texture Loading
    // ========================================================================

    def loadTexture(path: String, alpha: Bool): Engine.TextureInfo \ IO =
        let stack = MemoryStack.stackPush();
        let w = stack.mallocInt(1);
        let h = stack.mallocInt(1);
        let c = stack.mallocInt(1);
        STBImage.stbi_set_flip_vertically_on_load(false);
        let channels = if (alpha) 4 else 3;
        let data = STBImage.stbi_load(path, w, h, c, channels);
        if (Object.isNull(data)) {
            discard MemoryStack.stackPop();
            bug!("Failed to load texture: ${path}")
        } else {
            let texWidth = w.get(0);
            let texHeight = h.get(0);
            let textureID = GL11.glGenTextures();
            GL11.glBindTexture(GL11.GL_TEXTURE_2D, textureID);
            let format = if (alpha) GL11.GL_RGBA else GL11.GL_RGB;
            GL11.glTexImage2D(GL11.GL_TEXTURE_2D, 0, format, texWidth, texHeight, 0, format, GL11.GL_UNSIGNED_BYTE, data);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_WRAP_S, GL11.GL_REPEAT);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_WRAP_T, GL11.GL_REPEAT);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MIN_FILTER, GL11.GL_NEAREST);
            GL11.glTexParameteri(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MAG_FILTER, GL11.GL_NEAREST);
            STBImage.stbi_image_free(data);
            discard MemoryStack.stackPop();
            { id = textureID, width = Int32.toFloat32(texWidth), height = Int32.toFloat32(texHeight) }
        }

    def loadTextureRegistry(manifest: List[Engine.TextureEntry]): Engine.TextureRegistry \ IO =
        List.foldLeft((registry, entry) -> {
            let texInfo = loadTexture(entry#path, entry#hasAlpha);
            println("  ${entry#path} loaded (${texInfo#width}x${texInfo#height})");
            Map.insert(entry#name, texInfo, registry)
        }, Map.empty(), manifest)

    // ========================================================================
    // Sprite Renderer
    // ========================================================================

    def initSpriteRenderer(): (Int32, Int32) \ IO =
        let vao = GL30.glGenVertexArrays();
        let vbo = GL15.glGenBuffers();
        let vertices = Array#{
            0.0f32, 1.0f32, 0.0f32, 1.0f32,
            1.0f32, 0.0f32, 1.0f32, 0.0f32,
            0.0f32, 0.0f32, 0.0f32, 0.0f32,
            0.0f32, 1.0f32, 0.0f32, 1.0f32,
            1.0f32, 1.0f32, 1.0f32, 1.0f32,
            1.0f32, 0.0f32, 1.0f32, 0.0f32
        } @ Static;
        GL30.glBindVertexArray(vao);
        GL15.glBindBuffer(GL15.GL_ARRAY_BUFFER, vbo);
        GL15.glBufferData(GL15.GL_ARRAY_BUFFER, vertices, GL15.GL_STATIC_DRAW);
        GL20.glEnableVertexAttribArray(0);
        GL20.glVertexAttribPointer(0, 4, GL11.GL_FLOAT, false, 16, 0i64);
        GL15.glBindBuffer(GL15.GL_ARRAY_BUFFER, 0);
        GL30.glBindVertexArray(0);
        (vao, vbo)

    def setProjectionMatrix(shader: Int32, width: Float32, height: Float32): Unit \ IO =
        GL20.glUseProgram(shader);
        let left = 0.0f32;
        let right = width;
        let bottom = height;
        let top = 0.0f32;
        let proj = Array#{
            2.0f32 / (right - left), 0.0f32, 0.0f32, 0.0f32,
            0.0f32, 2.0f32 / (top - bottom), 0.0f32, 0.0f32,
            0.0f32, 0.0f32, -1.0f32, 0.0f32,
            -1.0f32 * (right + left) / (right - left), -1.0f32 * (top + bottom) / (top - bottom), 0.0f32, 1.0f32
        } @ Static;
        let loc = GL20.glGetUniformLocation(shader, "projection");
        GL20.glUniformMatrix4fv(loc, false, proj)

    def drawSprite(shader: Int32, texture: Int32, vao: Int32,
                   pos: Vec2.Vec2, size: Vec2.Vec2, color: Color,
                   uvOff: Vec2.Vec2, uvSc: Vec2.Vec2, rot: Float32): Unit \ IO =
        GL20.glUseProgram(shader);
        let c = Vec2.cos32(rot);
        let s = Vec2.sin32(rot);
        let sx = size#x;
        let sy = size#y;
        let tx = pos#x + sx / 2.0f32 - c * sx / 2.0f32 + s * sy / 2.0f32;
        let ty = pos#y + sy / 2.0f32 - s * sx / 2.0f32 - c * sy / 2.0f32;
        let model = Array#{
            c * sx, s * sx, 0.0f32, 0.0f32,
            -1.0f32 * s * sy, c * sy, 0.0f32, 0.0f32,
            0.0f32, 0.0f32, 1.0f32, 0.0f32,
            tx, ty, 0.0f32, 1.0f32
        } @ Static;
        let modelLoc = GL20.glGetUniformLocation(shader, "model");
        GL20.glUniformMatrix4fv(modelLoc, false, model);
        let colorLoc = GL20.glGetUniformLocation(shader, "spriteColor");
        GL20.glUniform3f(colorLoc, color#r, color#g, color#b);
        let uvOffsetLoc = GL20.glGetUniformLocation(shader, "uvOffset");
        GL20.glUniform2f(uvOffsetLoc, uvOff#x, uvOff#y);
        let uvScaleLoc = GL20.glGetUniformLocation(shader, "uvScale");
        GL20.glUniform2f(uvScaleLoc, uvSc#x, uvSc#y);
        GL13.glActiveTexture(GL13.GL_TEXTURE0);
        GL11.glBindTexture(GL11.GL_TEXTURE_2D, texture);
        GL30.glBindVertexArray(vao);
        GL11.glDrawArrays(GL11.GL_TRIANGLES, 0, 6);
        GL30.glBindVertexArray(0)

    // ========================================================================
    // LWJGL Handler for Engine.Game effect
    // ========================================================================

    pub def withLwjgl(config: Engine.EngineConfig, f: Unit -> a \ ef): a \ ef - Engine.Game + IO =
        if (not GLFW.glfwInit()) {
            println("GLFW init failed");
            bug!("GLFW failed")
        } else ();

        GLFW.glfwWindowHint(GLFW.GLFW_CONTEXT_VERSION_MAJOR, 3);
        GLFW.glfwWindowHint(GLFW.GLFW_CONTEXT_VERSION_MINOR, 3);
        GLFW.glfwWindowHint(GLFW.GLFW_OPENGL_PROFILE, GLFW.GLFW_OPENGL_CORE_PROFILE);
        GLFW.glfwWindowHint(GLFW.GLFW_OPENGL_FORWARD_COMPAT, GL11.GL_TRUE);
        GLFW.glfwWindowHint(GLFW.GLFW_RESIZABLE, GL11.GL_FALSE);

        let window = GLFW.glfwCreateWindow(config#screenWidth, config#screenHeight, config#title, MemoryUtil.NULL, MemoryUtil.NULL);
        GLFW.glfwMakeContextCurrent(window);
        GLFW.glfwSwapInterval(1);
        discard GL.createCapabilities();

        let fbStack = MemoryStack.stackPush();
        let fbWidthBuf = fbStack.mallocInt(1);
        let fbHeightBuf = fbStack.mallocInt(1);
        GLFW.glfwGetFramebufferSize(window, fbWidthBuf, fbHeightBuf);
        let fbWidth = fbWidthBuf.get(0);
        let fbHeight = fbHeightBuf.get(0);
        discard MemoryStack.stackPop();
        println("Framebuffer size: ${fbWidth}x${fbHeight}");

        GL11.glViewport(0, 0, fbWidth, fbHeight);
        GL11.glEnable(GL11.GL_BLEND);
        GL11.glBlendFunc(GL11.GL_SRC_ALPHA, GL11.GL_ONE_MINUS_SRC_ALPHA);

        let screenW = Int32.toFloat32(config#screenWidth);
        let screenH = Int32.toFloat32(config#screenHeight);

        let shader = createShaderProgram(vertexShaderSource(), fragmentShaderSource());
        setProjectionMatrix(shader, screenW, screenH);

        let (vao, _vbo) = initSpriteRenderer();

        println("Loading textures...");
        let registry = loadTextureRegistry(config#textureManifest);

        let timeHolder = Array#{System.nanoTime()} @ Static;

        let result = run {
            f()
        } with handler Engine.Game {
            def render(drawables, k) = {
                GL11.glClearColor(config#clearColor#r, config#clearColor#g, config#clearColor#b, 1.0f32);
                GL11.glClear(GL11.GL_COLOR_BUFFER_BIT);
                List.forEach(d -> {
                    match Map.get(d#texture, registry) {
                        case Some(texInfo) =>
                            let displayW = texInfo#width * d#scale#x;
                            let displayH = texInfo#height * d#scale#y;
                            let displaySize: Vec2.Vec2 = {x = displayW, y = displayH};
                            let pos: Vec2.Vec2 = if (d#centered)
                                {x = d#position#x - displayW / 2.0f32, y = d#position#y - displayH / 2.0f32}
                            else
                                d#position;
                            drawSprite(shader, texInfo#id, vao, pos, displaySize, d#color, d#uvOffset, d#uvScale, d#rotation)
                        case None => ()
                    }
                }, drawables);
                GLFW.glfwSwapBuffers(window);
                k(())
            }
            def shouldClose(k) = {
                GLFW.glfwPollEvents();
                k(GLFW.glfwWindowShouldClose(window))
            }
            def getDeltaTime(k) = {
                let currentTime = System.nanoTime();
                let prev = Array.get(0, timeHolder);
                Array.put(currentTime, 0, timeHolder);
                let dtNanos = currentTime - prev;
                let dtf = Int64.toFloat32(dtNanos) / 1000000000.0f32;
                k(dtf)
            }
        };

        Callbacks.glfwFreeCallbacks(window);
        GLFW.glfwDestroyWindow(window);
        GLFW.glfwTerminate();
        result
}
