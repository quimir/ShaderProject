using UnityEditor;
using UnityEngine;

/// <summary>
/// T0.3 · 切线空间可视化工具（Scene 视图）
///
/// 把「选中物体」每个顶点的三条轴画成三根小箭头，**三条轴可以分别开关**：
///     红 = T（切线，贴图 U 方向）
///     绿 = B（副切线，贴图 V 方向）
///     蓝 = N（表面法线）
///
/// 数据来自 mesh 自带的 normals / tangents —— 也就是说：
/// 这把「小坐标尺」是长在**每个顶点**上的，跟物体当前朝向、跟贴图内容都无关。
/// 移动/旋转物体时箭头跟着表面一起走，这就是「切线空间」和「世界空间」的区别。
///
/// 菜单（都在 Tools ▸ Shader Learning ▸ Vertex Frames 下）：
///     总开关                      %&0   —— 整个工具的总闸
///     显示 T · 切线（红）          %&1
///     显示 B · 副切线（绿）        %&2
///     显示 N · 法线（蓝）          %&3
/// （%&1 = Ctrl+Alt+1。想「只看一根轴」就把另外两个关掉。）
///
/// 用法：选中一个带 MeshFilter 的物体（Sphere / Cube / 任意模型）即可。
///
/// 实现说明：走 SceneView.duringSceneGui + Handles 这条通道，而不是 [DrawGizmo]——
/// 后者在 MCP 的 Scene 视图截图里不会被渲染出来，验证不了。（实测 2026-10-15）
///
/// 两个已知限制：
///   · 非均匀缩放下三条轴不再严格垂直——本工具用来「看方向」，不是做数学验证；
///   · 箭头长度是世界单位，不跟随物体缩放（ArrowLength 可运行时调）。
/// </summary>
[InitializeOnLoad]
public static class VertexFrameGizmos
{
    const string Root = "Tools/Shader Learning/Vertex Frames/";
    const string MasterPath = Root + "总开关";
    const string PathT = Root + "显示 T · 切线（红） %&1";
    const string PathB = Root + "显示 B · 副切线（绿） %&2";
    const string PathN = Root + "显示 N · 法线（蓝） %&3";

    const string PrefMaster = "ShaderLearning.VertexFrameGizmos";
    const string PrefT = "ShaderLearning.VertexFrameGizmos.T";
    const string PrefB = "ShaderLearning.VertexFrameGizmos.B";
    const string PrefN = "ShaderLearning.VertexFrameGizmos.N";

    const float LineThickness = 2f;

    /// <summary>箭头长度（世界单位），默认 0.15。</summary>
    public static float ArrowLength = 0.15f;

    /// <summary>每隔几个顶点画一组。默认 6——515 个顶点全画会糊成一团，采样后能看清每一组。</summary>
    public static int VertexStride = 6;

    /// <summary>画过多少次（排查用）。</summary>
    public static int DrawCalls;

    static VertexFrameGizmos()
    {
        SceneView.duringSceneGui += OnSceneGui;
    }

    // ── 四个开关的状态（EditorPrefs 持久化，重启编辑器不丢） ──
    static bool Master
    {
        get { return EditorPrefs.GetBool(PrefMaster, false); }
        set { EditorPrefs.SetBool(PrefMaster, value); }
    }

    static bool ShowT
    {
        get { return EditorPrefs.GetBool(PrefT, true); }
        set { EditorPrefs.SetBool(PrefT, value); }
    }

    static bool ShowB
    {
        get { return EditorPrefs.GetBool(PrefB, true); }
        set { EditorPrefs.SetBool(PrefB, value); }
    }

    static bool ShowN
    {
        get { return EditorPrefs.GetBool(PrefN, true); }
        set { EditorPrefs.SetBool(PrefN, value); }
    }

    // ── 菜单 ──
    [MenuItem(MasterPath)]
    static void ToggleMaster()
    {
        Master = !Master;
        SceneView.RepaintAll();
        Debug.Log("[ShaderLearning] Vertex Frames: " + (Master ? "总开关 ON" : "总开关 OFF")
                  + "（T=" + ShowT + " B=" + ShowB + " N=" + ShowN + "）");
    }

    [MenuItem(MasterPath, true)]
    static bool ToggleMasterValidate()
    {
        Menu.SetChecked(MasterPath, Master);
        return true;
    }

    [MenuItem(PathT)]
    static void ToggleT()
    {
        ShowT = !ShowT;
        SceneView.RepaintAll();
    }

    [MenuItem(PathT, true)]
    static bool ToggleTValidate()
    {
        Menu.SetChecked(PathT, ShowT);
        return true;
    }

    [MenuItem(PathB)]
    static void ToggleB()
    {
        ShowB = !ShowB;
        SceneView.RepaintAll();
    }

    [MenuItem(PathB, true)]
    static bool ToggleBValidate()
    {
        Menu.SetChecked(PathB, ShowB);
        return true;
    }

    [MenuItem(PathN)]
    static void ToggleN()
    {
        ShowN = !ShowN;
        SceneView.RepaintAll();
    }

    [MenuItem(PathN, true)]
    static bool ToggleNValidate()
    {
        Menu.SetChecked(PathN, ShowN);
        return true;
    }

    static void OnSceneGui(SceneView view)
    {
        if (!Master) return;
        if (Event.current == null || Event.current.type != EventType.Repaint) return;
        if (!ShowT && !ShowB && !ShowN) return;   // 三根都关了就别白跑循环

        foreach (GameObject go in Selection.gameObjects)
        {
            if (go == null) continue;
            MeshFilter filter = go.GetComponent<MeshFilter>();
            if (filter == null) continue;
            DrawFrames(filter);
        }
    }

    static void DrawFrames(MeshFilter filter)
    {
        Mesh mesh = filter.sharedMesh;
        if (mesh == null) return;

        Vector3[] vertices;
        Vector3[] normals;
        Vector4[] tangents;
        try
        {
            vertices = mesh.vertices;
            normals = mesh.normals;
            tangents = mesh.tangents;
        }
        catch (UnityException)
        {
            return;   // mesh 不可读（Read/Write 关掉）就安静退出，别在 Scene 视图刷报错
        }

        if (vertices == null || normals == null || tangents == null) return;
        if (normals.Length != vertices.Length || tangents.Length != vertices.Length) return;

        if ((DrawCalls++ % 60) == 0)
            Debug.Log("[ShaderLearning] DrawFrames: 顶点数=" + vertices.Length
                      + "，T=" + ShowT + " B=" + ShowB + " N=" + ShowN);

        bool drawT = ShowT;
        bool drawB = ShowB;
        bool drawN = ShowN;

        Transform tr = filter.transform;
        Color colorT = new Color(1f, 0.25f, 0.25f);
        Color colorB = new Color(0.25f, 1f, 0.3f);
        Color colorN = new Color(0.35f, 0.55f, 1f);

        int stride = Mathf.Max(1, VertexStride);
        for (int i = 0; i < vertices.Length; i += stride)
        {
            Vector3 p = tr.TransformPoint(vertices[i]);

            Vector3 n = normals[i].sqrMagnitude > 1e-8f
                ? tr.TransformDirection(normals[i]).normalized
                : Vector3.zero;

            Vector3 t = new Vector3(tangents[i].x, tangents[i].y, tangents[i].z);
            t = t.sqrMagnitude > 1e-8f ? tr.TransformDirection(t).normalized : Vector3.zero;

            if (n == Vector3.zero || t == Vector3.zero) continue;

            if (drawT)
            {
                Handles.color = colorT;
                Handles.DrawLine(p, p + t * ArrowLength, LineThickness);
            }

            if (drawB)
            {
                // B = cross(N, T) * w —— w 就是 tangent 的第四个分量（Unity 用它表达左右手）
                Vector3 b = Vector3.Cross(n, t) * Mathf.Sign(tangents[i].w);
                if (b.sqrMagnitude > 1e-8f) b.Normalize();

                Handles.color = colorB;
                Handles.DrawLine(p, p + b * ArrowLength, LineThickness);
            }

            if (drawN)
            {
                Handles.color = colorN;
                Handles.DrawLine(p, p + n * ArrowLength, LineThickness);
            }
        }
    }
}
