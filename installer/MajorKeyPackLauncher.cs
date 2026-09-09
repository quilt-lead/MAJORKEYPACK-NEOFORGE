using System;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Windows.Forms;

internal static class Program
{
private const string CurrentVersion = "**CURRENT_VERSION**";

```
private const string GitHubOwner = "quilt-lead";
private const string GitHubRepository = "MAJORKEYPACK-NEOFORGE";

private const string InstallerScriptName = "Install-MajorKeyPack.ps1";
private const string ManifestName = "modpack-manifest.json";

[STAThread]
private static int Main()
{
    ApplicationConfiguration.Initialize();

    try
    {
        bool updated = CheckForUpdateAsync().GetAwaiter().GetResult();

        if (updated)
        {
            return 0;
        }

        return RunInstaller();
    }
    catch (Exception ex)
    {
        MessageBox.Show(
            ex.ToString(),
            "Major Key Pack Installer",
            MessageBoxButtons.OK,
            MessageBoxIcon.Error
        );

        return 1;
    }
}

private static int RunInstaller()
{
    string tempDirectory = Path.Combine(
        Path.GetTempPath(),
        "MajorKeyPack",
        Guid.NewGuid().ToString("N")
    );

    Directory.CreateDirectory(tempDirectory);

    string scriptPath = Path.Combine(
        tempDirectory,
        InstallerScriptName
    );

    string manifestPath = Path.Combine(
        tempDirectory,
        ManifestName
    );

    ExtractResource(
        InstallerScriptName,
        scriptPath
    );

    ExtractResource(
        ManifestName,
        manifestPath
    );

    var startInfo = new ProcessStartInfo
    {
        FileName = "powershell.exe",
        Arguments =
            "-NoProfile " +
            "-ExecutionPolicy Bypass " +
            "-File " +
            Quote(scriptPath),

        WorkingDirectory = tempDirectory,
        UseShellExecute = false,
        CreateNoWindow = false
    };

    using Process process = Process.Start(startInfo)
        ?? throw new InvalidOperationException(
            "Could not start PowerShell."
        );

    process.WaitForExit();

    return process.ExitCode;
}

private static async Task<bool> CheckForUpdateAsync()
{
    try
    {
        using var client = new HttpClient();

        client.DefaultRequestHeaders.UserAgent.ParseAdd(
            "MajorKeyPack-Launcher"
        );

        string url =
            $"https://api.github.com/repos/{GitHubOwner}/{GitHubRepository}/releases/latest";

        string json = await client.GetStringAsync(url);

        using JsonDocument document =
            JsonDocument.Parse(json);

        JsonElement root = document.RootElement;

        if (!root.TryGetProperty("tag_name", out JsonElement tagElement))
        {
            return false;
        }

        string tag = tagElement.GetString() ?? "";

        int latestVersion = ParseVersion(tag);
        int currentVersion = ParseVersion(CurrentVersion);

        if (latestVersion <= currentVersion)
        {
            return false;
        }

        string? downloadUrl = null;

        if (root.TryGetProperty("assets", out JsonElement assets))
        {
            foreach (JsonElement asset in assets.EnumerateArray())
            {
                if (!asset.TryGetProperty(
                        "name",
                        out JsonElement nameElement))
                {
                    continue;
                }

                string name =
                    nameElement.GetString() ?? "";

                if (!name.Equals(
                        "MajorKeyPack-Installer.exe",
                        StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                if (asset.TryGetProperty(
                        "browser_download_url",
                        out JsonElement urlElement))
                {
                    downloadUrl =
                        urlElement.GetString();

                    break;
                }
            }
        }

        if (string.IsNullOrWhiteSpace(downloadUrl))
        {
            return false;
        }

        DialogResult result = MessageBox.Show(
            $"A newer version of Major Key Pack is available.\n\n" +
            $"Current version: {CurrentVersion}\n" +
            $"New version:     {tag}\n\n" +
            "Would you like to update?",
            "Major Key Pack Update",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Information
        );

        if (result != DialogResult.Yes)
        {
            return false;
        }

        string newInstallerPath = Path.Combine(
            Path.GetTempPath(),
            $"MajorKeyPack-Installer-{Guid.NewGuid():N}.exe"
        );

        using HttpResponseMessage response =
            await client.GetAsync(downloadUrl);

        response.EnsureSuccessStatusCode();

        await using Stream source =
            await response.Content.ReadAsStreamAsync();

        await using FileStream destination =
            File.Create(newInstallerPath);

        await source.CopyToAsync(destination);

        Process.Start(new ProcessStartInfo
        {
            FileName = newInstallerPath,
            UseShellExecute = true
        });

        return true;
    }
    catch
    {
        // GitHub update checking must never prevent installation.
        return false;
    }
}

private static int ParseVersion(string value)
{
    if (string.IsNullOrWhiteSpace(value))
    {
        return 0;
    }

    value = value.Trim();

    if (value.StartsWith("v", StringComparison.OrdinalIgnoreCase))
    {
        value = value.Substring(1);
    }

    return int.TryParse(value, out int version)
        ? version
        : 0;
}

private static void ExtractResource(
    string resourceName,
    string destination)
{
    var assembly =
        typeof(Program).Assembly;

    string? resource = assembly
        .GetManifestResourceNames()
        .FirstOrDefault(name =>
            name.EndsWith(
                resourceName,
                StringComparison.OrdinalIgnoreCase
            )
        );

    if (resource == null)
    {
        throw new FileNotFoundException(
            $"Embedded resource not found: {resourceName}"
        );
    }

    using Stream? input =
        assembly.GetManifestResourceStream(resource);

    if (input == null)
    {
        throw new InvalidOperationException(
            $"Could not open embedded resource: {resourceName}"
        );
    }

    using FileStream output =
        File.Create(destination);

    input.CopyTo(output);
}

private static string Quote(string value)
{
    return "\"" +
           value.Replace("\"", "\\\"") +
           "\"";
}
```

}
