using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using UnityEditor;
using UnityEditor.Rendering;   // ShaderType / ShaderCompilerPlatform 在此命名空间（Unity 6）
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// Shader 学习检视器。
///
/// 这个工具存在的理由：手写 HLSL 时，编辑器只告诉你「编译过了」或「报错了」，
/// 而学习真正需要知道的是编译器**到底拿走了什么、生成了什么**。本窗口把这些暴露出来：
///
///   1. 生成的 HLSL   —— 预处理 + 展开之后，编译器实际看到的代码（能看清 #include 展开成了什么）
///   2. 逐 Pass 信息   —— 每个 Pass 的 shader stage、关键字数量
///   3. 变体编译       —— 指定关键字组合编译一次，看成功/失败与绑定统计
///   4. 编译消息       —— 该变体产生的 error / warning 原文
///
/// 用 Unity 官方 API：UnityEditor.ShaderUtil / ShaderData（Unity 6 起为公开 API）。
/// 菜单：Window ▸ Shader Learning ▸ Shader Inspector
/// </summary>
public sealed class ShaderLearningInspector : EditorWindow
{
    // ── 状态 ──
    private Shader _shader;
    private Vector2 _leftScroll;
    private Vector2 _rightScroll;
    private int _subshaderIndex;
    private int _passIndex;
    private ShaderType _shaderType = ShaderType.Vertex;
    // Unity 6 的枚举成员是 D3D（旧版本的 D3D11 已移除）
    private ShaderCompilerPlatform _platform = ShaderCompilerPlatform.D3D;
    private BuildTarget _buildTarget = BuildTarget.StandaloneWindows64;
    private string _keywordText = "";

    private string _generatedSource = "";
    private ShaderData.PreprocessedVariant? _preprocessed;
    private ShaderData.VariantCompileInfo? _compiled;
    private string _status = "选一个 shader 开始。";
    private MessageType _statusType = MessageType.Info;

    private ShaderData _data;
    private ShaderData.Subshader _subshader;
    private ShaderData.Pass _pass;

    [MenuItem("Window/Shader Learning/Shader Inspector")]
    public static void Open()
    {
        var w = GetWindow<ShaderLearningInspector>("Shader 学习检视器");
        w.minSize = new Vector2(900, 520);
    }

    private void OnEnable()
    {
        if (_shader == null)
        {
            var selected = Selection.activeObject as Shader;
            if (selected != null) SetShader(selected);
        }
    }

    private void OnSelectionChange()
    {
        var selected = Selection.activeObject as Shader;
        if (selected != null && selected != _shader) SetShader(selected);
        Repaint();
    }

    private void SetShader(Shader shader)
    {
        _shader = shader;
        _subshaderIndex = 0;
        _passIndex = 0;
        _generatedSource = "";
        _preprocessed = null;
        _compiled = null;
        RefreshRefs();
    }

    /// <summary>解析当前 shader / subshader / pass 的引用。任何失败都落到状态栏而不是抛异常。</summary>
    private void RefreshRefs()
    {
        _data = null;
        _subshader = null;
        _pass = null;
        _generatedSource = "";

        if (_shader == null) { SetStatus("没有选中 shader。", MessageType.Warning); return; }

        _data = ShaderUtil.GetShaderData(_shader);
        if (_data == null) { SetStatus($"{_shader.name}: 拿不到 ShaderData（可能编译失败）。", MessageType.Error); return; }

        if (_data.SubshaderCount == 0) { SetStatus($"{_shader.name}: 没有 SubShader。", MessageType.Error); return; }

        _subshaderIndex = Mathf.Clamp(_subshaderIndex, 0, _data.SubshaderCount - 1);
        _subshader = _data.GetSubshader(_subshaderIndex);
        if (_subshader == null || _subshader.PassCount == 0)
        {
            SetStatus($"{_shader.name}: SubShader {_subshaderIndex} 没有 Pass。", MessageType.Warning);
            return;
        }

        _passIndex = Mathf.Clamp(_passIndex, 0, _subshader.PassCount - 1);
        _pass = _subshader.GetPass(_passIndex);
        if (_pass == null) { SetStatus("拿不到 Pass。", MessageType.Error); return; }

        try { _generatedSource = _pass.SourceCode ?? ""; }
        catch (Exception e) { _generatedSource = ""; SetStatus($"读取生成代码失败：{e.Message}", MessageType.Error); return; }

        SetStatus($"{_shader.name} · SubShader {_subshaderIndex} · Pass {_passIndex}（{_pass.Name}）", MessageType.Info);
    }

    private void SetStatus(string text, MessageType type) { _status = text; _statusType = type; }

    private string[] GetKeywords()
    {
        if (string.IsNullOrWhiteSpace(_keywordText)) return Array.Empty<string>();
        return _keywordText
            .Split(new[] { ',', ';', '\n', '\r', ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(k => k.Trim().ToUpperInvariant())
            .Distinct()
            .ToArray();
    }

    /// <summary>
    /// 取某个 Pass 的关键字列表。
    ///
    /// 为什么不直接调 ShaderUtil.GetPassKeywords：它的有效重载带有 ref 参数，
    /// 而 Unity 2020.3 对应的语言版本是 C# 9 —— 在 C# 9 里把 ref 传给 in 参数
    /// 会直接编译失败（CS9194）。走反射就能绕开语言版本限制：
    /// 取 4 参数重载 (Shader, ref PassIdentifier, ShaderType, ShaderCompilerPlatform)，
    /// 用 object[] 传参，运行时自然按引用语义传递。
    /// </summary>
    private static LocalKeyword[] GetPassKeywordsCompat(
        Shader shader, PassIdentifier passId, ShaderType stage, ShaderCompilerPlatform platform)
    {
        try
        {
            var methods = typeof(ShaderUtil).GetMethods(
                System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static);
            foreach (var m in methods)
            {
                if (m.Name != "GetPassKeywords") continue;
                var ps = m.GetParameters();
                if (ps.Length != 4) continue;
                if (ps[0].ParameterType != typeof(Shader)) continue;
                if (ps[1].ParameterType != typeof(PassIdentifier).MakeByRefType()) continue;
                if (ps[2].ParameterType != typeof(ShaderType)) continue;
                if (ps[3].ParameterType != typeof(ShaderCompilerPlatform)) continue;

                var args = new object[] { shader, passId, stage, platform };
                return m.Invoke(null, args) as LocalKeyword[];
            }
        }
        catch { /* 反射失败视为查不到关键字，不影响其他信息 */ }
        return Array.Empty<LocalKeyword>();
    }

    private void OnGUI()
    {
        // 工具栏必须先画：那个 ObjectField 是用户拖入 Shader 的入口，
        // 提前返回会把它一起吃掉，人就卡死了。
        DrawToolbar();

        // 选中对象被删除后，Unity 的 == 重载会把 _shader 判为 null；
        // 此时任何触及它的调用都会抛异常，并打断布局的 Begin/End 配对。
        if (_shader == null)
        {
            EditorGUILayout.Space(4);
            EditorGUILayout.HelpBox("把一个 Shader 资产拖到上面的槽位，或先在 Project 窗口里选中它。", MessageType.Info);
            return;
        }

        EditorGUILayout.BeginHorizontal();
        DrawLeftPane();
        DrawRightPane();
        EditorGUILayout.EndHorizontal();

        EditorGUILayout.Space(2);
        EditorGUILayout.HelpBox(_status, _statusType);
    }

    private void DrawToolbar()
    {
        EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);

        EditorGUI.BeginChangeCheck();
        var newShader = (Shader)EditorGUILayout.ObjectField(_shader, typeof(Shader), false, GUILayout.Width(240));
        if (EditorGUI.EndChangeCheck() && newShader != null) SetShader(newShader);

        GUILayout.Space(8);
        if (_data != null && _data.SubshaderCount > 0)
        {
            var labels = Enumerable.Range(0, _data.SubshaderCount).Select(i => $"SubShader {i}").ToArray();
            EditorGUI.BeginChangeCheck();
            var si = EditorGUILayout.Popup(_subshaderIndex, labels, EditorStyles.toolbarPopup, GUILayout.Width(120));
            if (EditorGUI.EndChangeCheck()) { _subshaderIndex = si; RefreshRefs(); }
        }

        if (_subshader != null && _subshader.PassCount > 0)
        {
            var labels = Enumerable.Range(0, _subshader.PassCount)
                .Select(i => { var p = _subshader.GetPass(i); return $"Pass {i}: {p?.Name ?? "?"}"; }).ToArray();
            EditorGUI.BeginChangeCheck();
            var pi = EditorGUILayout.Popup(_passIndex, labels, EditorStyles.toolbarPopup, GUILayout.Width(180));
            if (EditorGUI.EndChangeCheck()) { _passIndex = pi; RefreshRefs(); }
        }

        GUILayout.FlexibleSpace();

        if (GUILayout.Button("重新读取", EditorStyles.toolbarButton, GUILayout.Width(70))) RefreshRefs();
        if (GUILayout.Button("复制生成代码", EditorStyles.toolbarButton, GUILayout.Width(90)))
        {
            EditorGUIUtility.systemCopyBuffer = _generatedSource;
            SetStatus($"已复制 {_generatedSource.Length} 字符到剪贴板。", MessageType.Info);
        }
        if (GUILayout.Button("导出到 Temp", EditorStyles.toolbarButton, GUILayout.Width(90))) ExportToTemp();

        EditorGUILayout.EndHorizontal();
    }

    // ── 左栏：操作 + 概览 ──
    private void DrawLeftPane()
    {
        EditorGUILayout.BeginVertical(GUILayout.Width(330));
        _leftScroll = EditorGUILayout.BeginScrollView(_leftScroll);

        EditorGUILayout.LabelField("编译设置", EditorStyles.boldLabel);
        _shaderType = (ShaderType)EditorGUILayout.EnumPopup("Stage", _shaderType);
        _platform = (ShaderCompilerPlatform)EditorGUILayout.EnumPopup("编译器平台", _platform);
        _buildTarget = (BuildTarget)EditorGUILayout.EnumPopup("目标平台", _buildTarget);

        EditorGUILayout.Space(4);
        EditorGUILayout.LabelField("关键字（逗号分隔，留空即无关键字变体）", EditorStyles.miniLabel);
        _keywordText = EditorGUILayout.TextField(_keywordText);

        var kws = GetKeywords();
        if (kws.Length > 0)
            EditorGUILayout.LabelField($"将使用 {kws.Length} 个关键字：{string.Join(", ", kws)}", EditorStyles.miniLabel);

        EditorGUILayout.Space(8);
        EditorGUILayout.LabelField("Pass 概览", EditorStyles.boldLabel);
        DrawPassOverview();

        EditorGUILayout.Space(8);
        if (GUILayout.Button("① 预处理该变体")) DoPreprocess();
        if (GUILayout.Button("② 编译该变体")) DoCompile();

        if (_preprocessed.HasValue)
        {
            var pp = _preprocessed.Value;
            EditorGUILayout.Space(6);
            EditorGUILayout.LabelField("预处理结果", EditorStyles.boldLabel);
            EditorGUILayout.LabelField($"状态：{(pp.Success ? "成功" : "失败")}");
            EditorGUILayout.LabelField($"代码长度：{pp.PreprocessedCode?.Length ?? 0} 字符");
            EditorGUILayout.LabelField($"消息数：{pp.Messages?.Length ?? 0}");
        }

        if (_compiled.HasValue)
        {
            var c = _compiled.Value;
            EditorGUILayout.Space(6);
            EditorGUILayout.LabelField("编译结果", EditorStyles.boldLabel);
            EditorGUILayout.LabelField($"状态：{(c.Success ? "成功" : "失败")}");
            EditorGUILayout.LabelField($"消息数：{c.Messages?.Length ?? 0}");
            EditorGUILayout.LabelField($"常量缓冲：{c.ConstantBuffers?.Length ?? 0}");
            EditorGUILayout.LabelField($"纹理绑定：{c.TextureBindings?.Length ?? 0}");
        }

        EditorGUILayout.EndScrollView();
        EditorGUILayout.EndVertical();
    }

    private void DrawPassOverview()
    {
        if (_subshader == null) { EditorGUILayout.LabelField("（无）"); return; }

        for (var i = 0; i < _subshader.PassCount; i++)
        {
            var p = _subshader.GetPass(i);
            if (p == null) continue;

            var stages = new List<string>();
            if (p.HasShaderStage(ShaderType.Vertex)) stages.Add("VS");
            if (p.HasShaderStage(ShaderType.Fragment)) stages.Add("FS");
            if (p.HasShaderStage(ShaderType.Geometry)) stages.Add("GS");
            if (p.HasShaderStage(ShaderType.Hull)) stages.Add("HS");
            if (p.HasShaderStage(ShaderType.Domain)) stages.Add("DS");

            LocalKeyword[] kws = null;
            try
            {
                // PassIdentifier 只有 (uint, uint) 构造函数，且属性是只读的，
                // 不能用对象初始化器。
                var id = new PassIdentifier((uint)_subshaderIndex, (uint)i);
                kws = GetPassKeywordsCompat(_shader, id, ShaderType.Fragment, _platform);
            }
            catch { /* 关键字查询失败不影响其他信息 */ }

            var isCurrent = i == _passIndex;
            var style = isCurrent ? EditorStyles.boldLabel : EditorStyles.label;
            EditorGUILayout.LabelField(
                $"Pass {i}  {p.Name}   [{string.Join("/", stages)}]   关键字 {(kws?.Length ?? 0)}",
                style);
        }
    }

    // ── 右栏：代码与消息 ──
    private void DrawRightPane()
    {
        EditorGUILayout.BeginVertical();
        _rightScroll = EditorGUILayout.BeginScrollView(_rightScroll);

        DrawMessages();

        EditorGUILayout.Space(6);
        EditorGUILayout.LabelField("预处理后的代码（编译器实际看到的）", EditorStyles.boldLabel);
        if (_preprocessed.HasValue && !string.IsNullOrEmpty(_preprocessed.Value.PreprocessedCode))
        {
            EditorGUILayout.TextArea(_preprocessed.Value.PreprocessedCode, GUILayout.ExpandHeight(true));
        }
        else
        {
            EditorGUILayout.HelpBox("点左栏「① 预处理该变体」生成。", MessageType.None);
        }

        EditorGUILayout.Space(6);
        EditorGUILayout.LabelField("编译器生成的 HLSL（含 #include 展开结果）", EditorStyles.boldLabel);
        if (string.IsNullOrEmpty(_generatedSource))
        {
            EditorGUILayout.HelpBox("该 Pass 没有可读的生成代码。", MessageType.Warning);
        }
        else
        {
            EditorGUILayout.LabelField($"{_generatedSource.Length} 字符", EditorStyles.miniLabel);
            EditorGUILayout.TextArea(_generatedSource, GUILayout.ExpandHeight(true));
        }

        EditorGUILayout.EndScrollView();
        EditorGUILayout.EndVertical();
    }

    private void DrawMessages()
    {
        var messages = new List<ShaderMessage>();

        if (_preprocessed.HasValue && _preprocessed.Value.Messages != null)
            messages.AddRange(_preprocessed.Value.Messages);
        if (_compiled.HasValue && _compiled.Value.Messages != null)
            messages.AddRange(_compiled.Value.Messages);

        // _shader 为 null 时必须跳过：ShaderUtil.GetShaderMessages(null) 内部会拆掉
        // 参数并抛 ArgumentNullException。窗口刚创建、或选中对象被删除时都会走到这里，
        // 而这个异常会打断 OnGUI 的布局配对，连带刷出 GUILayout 报错。
        if (_shader != null)
        {
            var shaderMsgs = ShaderUtil.GetShaderMessages(_shader);
            if (shaderMsgs != null) messages.AddRange(shaderMsgs);
        }

        var distinct = messages
            .GroupBy(m => $"{m.severity}|{m.message}|{m.line}|{m.file}")
            .Select(g => g.First())
            .ToList();

        EditorGUILayout.LabelField($"编译消息（去重后 {distinct.Count} 条）", EditorStyles.boldLabel);

        if (distinct.Count == 0)
        {
            EditorGUILayout.HelpBox("没有错误或警告。", MessageType.Info);
            return;
        }

        foreach (var m in distinct)
        {
            var type = m.severity switch
            {
                ShaderCompilerMessageSeverity.Error => MessageType.Error,
                ShaderCompilerMessageSeverity.Warning => MessageType.Warning,
                _ => MessageType.Info
            };
            var location = string.IsNullOrEmpty(m.file) ? "" : $"  @ {m.file}:{m.line}";
            EditorGUILayout.HelpBox($"[{m.severity}] {m.message}{location}", type);
        }
    }

    private void DoPreprocess()
    {
        if (_pass == null) { SetStatus("没有可处理的 Pass。", MessageType.Error); return; }
        try
        {
            // 第 5 个参数 stripLineDirectives：true 让返回的代码去掉 #line，
            // 学习时读起来干净得多。
            _preprocessed = _pass.PreprocessVariant(_shaderType, GetKeywords(), _platform, _buildTarget, true);
            var ok = _preprocessed.Value.Success;
            SetStatus(ok ? "预处理成功，见右栏。" : "预处理失败，见消息。", ok ? MessageType.Info : MessageType.Error);
        }
        catch (Exception e)
        {
            _preprocessed = null;
            SetStatus($"预处理异常：{e.Message}", MessageType.Error);
        }
        Repaint();
    }

    private void DoCompile()
    {
        if (_pass == null) { SetStatus("没有可编译的 Pass。", MessageType.Error); return; }
        try
        {
            _compiled = _pass.CompileVariant(_shaderType, GetKeywords(), _platform, _buildTarget, true);
            var ok = _compiled.Value.Success;
            SetStatus(ok ? "编译成功，见绑定统计与消息。" : "编译失败，见消息。", ok ? MessageType.Info : MessageType.Error);
        }
        catch (Exception e)
        {
            _compiled = null;
            SetStatus($"编译异常：{e.Message}", MessageType.Error);
        }
        Repaint();
    }

    private void ExportToTemp()
    {
        if (string.IsNullOrEmpty(_generatedSource)) { SetStatus("没有可导出的代码。", MessageType.Warning); return; }

        try
        {
            var name = _shader != null ? _shader.name.Replace('/', '_') : "shader";
            var dir = Path.Combine(Path.GetTempPath(), "ShaderLearning");
            Directory.CreateDirectory(dir);
            var file = Path.Combine(dir, $"{name}_sub{_subshaderIndex}_pass{_passIndex}.hlsl");
            File.WriteAllText(file, _generatedSource, new UTF8Encoding(false));
            SetStatus($"已导出：{file}", MessageType.Info);
            EditorUtility.RevealInFinder(file);
        }
        catch (Exception e)
        {
            SetStatus($"导出失败：{e.Message}", MessageType.Error);
        }
    }
}
