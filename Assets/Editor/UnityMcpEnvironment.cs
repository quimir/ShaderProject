#if UNITY_EDITOR_WIN
using System;
using System.Diagnostics;
using System.Linq;
using UnityEditor;

// Refresh inherited Windows environment after installing MCP dependencies.
[InitializeOnLoad]
internal static class UnityMcpEnvironment
{
    static UnityMcpEnvironment()
    {
        RefreshPath();
    }

    [MenuItem("Tools/Unity MCP/Refresh Python and uv paths")]
    private static void RefreshPath()
    {
        string userPath = Environment.GetEnvironmentVariable("PATH", EnvironmentVariableTarget.User);
        string machinePath = Environment.GetEnvironmentVariable("PATH", EnvironmentVariableTarget.Machine);
        string currentPath = Environment.GetEnvironmentVariable("PATH");
        string combined = userPath + ";" + machinePath + ";" + currentPath;
        Environment.SetEnvironmentVariable("PATH", string.Join(";", combined.Split(';').Where(p => !string.IsNullOrWhiteSpace(p)).Distinct(StringComparer.OrdinalIgnoreCase)));
        EditorApplication.delayCall += Verify;
    }

    private static void Verify()
    {
        foreach (string command in new[] { "python.exe", "uv.exe" })
        {
            try
            {
                using (var process = Process.Start(new ProcessStartInfo(command, "--version")
                {
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }))
                {
                    if (!process.WaitForExit(5000))
                    {
                        process.Kill();
                        UnityEngine.Debug.LogWarning("[UnityMcpEnvironment] Timeout: " + command);
                        continue;
                    }
                    string output = process.StandardOutput.ReadToEnd().Trim();
                    string error = process.StandardError.ReadToEnd().Trim();
                    UnityEngine.Debug.Log("[UnityMcpEnvironment] " + command + " exit=" + process.ExitCode + " " + output + " " + error);
                }
            }
            catch (Exception exception)
            {
                UnityEngine.Debug.LogWarning("[UnityMcpEnvironment] " + command + ": " + exception.Message);
            }
        }
    }
}
#endif

