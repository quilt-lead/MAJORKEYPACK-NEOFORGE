```csharp
using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Forms;

internal static class Program
{
    /*
     * GitHub Actions replaces this value when building a release.
     *
     * Example:
     * v1
     * v2
     * v3
     */
    private const string CurrentVersion = "__CURRENT_VERSION__";

    private const string GitHubOwner = "quilt-lead";
    private const string GitHubRepository = "MAJORKEYPACK-NEOFORGE";

    private const string InstallerScriptResource = "Install-MajorKeyPack.ps1";
    private const string ManifestResource = "modpack-manifest.json";

    [STAThread]
    private static int Main()
    {
        try
        {
            ApplicationConfiguration.Initialize();

            // ---------------------------------------------------------
            // CHECK FOR UPDATE FIRST
            // ---------------------------------------------------------

            bool updateCheckSucceeded;

            try
            {
                updateCheckSucceeded = CheckForUpdateAsync()
                    .GetAwaiter()
                    .GetResult();
            }
            catch
            {
                // GitHub being unavailable should NOT prevent installation.
                updateCheckSucceeded = false;
            }

            if (updateCheckSucceeded)
            {
                return 0;
            }

            // ---------------------------------------------------------
            // NO UPDATE NEEDED
            // RUN INSTALLER
            // ---------------------------------------------------------

            string tempDirectory = Path.Combine(
                Path.GetTempPath(),
                "MajorKeyPack",
                Guid.NewGuid().ToString("N")
            );

            Directory.CreateDirectory(tempDirectory);

            string scriptPath = Path.Combine(
                tempDirectory,
                "Install-MajorKeyPack.ps1"
            );

            string manifestPath = Path.Combine(
                tempDirectory,
                "modpack-manifest.json"
            );

            ExtractResource(
                InstallerScriptResource,
                scriptPath
            );

            ExtractResource(
                ManifestResource,
                manifestPath
            );

            /*
             * The manifest is embedded as a resource AND written beside
             * the PowerShell script.
             *
             * The current PS1 contains its own embedded copy, so this
             * file is also provided for compatibility/future changes.
             */

            string powershellArguments =
                "-NoProfile -ExecutionPolicy Bypass -File " +
                Quote(scriptPath);

            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = powershellArguments,
                UseShellExecute = false,
                WorkingDirectory = tempDirectory
            };

            using Process process = Process.Start(psi);

            if (process == null)
            {
                throw new Exception("Could not start PowerShell.");
            }

            process.WaitForExit();

            return process.ExitCode;
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                ex.Message,
                "Major Key Pack NeoForge Installer",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );

            return 1;
        }
    }

    private static async Task<bool> CheckForUpdateAsync()
    {
        int currentVersionNumber = ParseVersion(CurrentVersion);

        using HttpClient client = new HttpClient();

        client.DefaultRequestHeaders.UserAgent.ParseAdd(
            "MajorKeyPack-NeoForge-Installer"
        );

        string apiUrl =
            $"https://api.github.com/repos/{GitHubOwner}/{GitHubRepository}/releases/latest";

        string json = await client.GetStringAsync(apiUrl);

        using JsonDocument document = JsonDocument.Parse(json);

        if (!document.RootElement.TryGetProperty(
                "tag_name",
                out JsonElement tagElement))
        {
            return false;
        }

        string? latestTag = tagElement.GetString();

        if (string.IsNullOrWhiteSpace(latestTag))
        {
            return false;
        }

        int latestVersionNumber = ParseVersion(latestTag);

        /*
         * If the release on GitHub isn't newer, continue normally.
         */
        if (latestVersionNumber <= currentVersionNumber)
        {
            return false;
        }

        /*
         * Find the EXE in the release assets.
         */
        if (!document.RootElement.TryGetProperty(
                "assets",
                out JsonElement assets))
        {
            return false;
        }

        string? downloadUrl = null;

        foreach (JsonElement asset in assets.EnumerateArray())
        {
            if (!asset.TryGetProperty(
                    "name",
                    out JsonElement nameElement))
            {
                continue;
            }

            string? name = nameElement.GetString();

            if (!string.Equals(
                    name,
                    "MajorKeyPack-Installer.exe",
                    StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (asset.TryGetProperty(
                    "browser_download_url",
                    out JsonElement urlElement))
            {
                downloadUrl = urlElement.GetString();
            }

            break;
        }

        if (string.IsNullOrWhiteSpace(downloadUrl))
        {
            return false;
        }

        DialogResult result = MessageBox.Show(
            $"A newer version of Major Key Pack NeoForge is available.\n\n" +
            $"Current version: {CurrentVersion}\n" +
            $"Latest version:  {latestTag}\n\n" +
            $"Would you like to update now?",
            "Major Key Pack NeoForge Update",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Information
        );

        if (result != DialogResult.Yes)
        {
            return false;
        }

        string tempExe = Path.Combine(
            Path.GetTempPath(),
            $"MajorKeyPack-Installer-{latestTag}.exe"
        );

        if (File.Exists(tempExe))
        {
            File.Delete(tempExe);
        }

        using HttpResponseMessage response =
            await client.GetAsync(downloadUrl);

        response.EnsureSuccessStatusCode();

        await using Stream input =
            await response.Content.ReadAsStreamAsync();

        await using FileStream output =
            File.Create(tempExe);

        await input.CopyToAsync(output);

        output.Close();

        Process.Start(new ProcessStartInfo
        {
            FileName = tempExe,
            UseShellExecute = true
        });

        /*
         * Returning true tells Main() not to continue with the old
         * installer.
         */
        return true;
    }

    private static int ParseVersion(string version)
    {
        if (string.IsNullOrWhiteSpace(version))
        {
            return 0;
        }

        version = version.Trim();

        if (version.StartsWith(
                "v",
                StringComparison.OrdinalIgnoreCase))
        {
            version = version.Substring(1);
        }

        if (int.TryParse(
                version,
                out int result))
        {
            return result;
        }

        return 0;
    }

    private static void ExtractResource(
        string resourceName,
        string destination)
    {
        Assembly assembly =
            Assembly.GetExecutingAssembly();

        string? resource = null;

        foreach (string name in
                 assembly.GetManifestResourceNames())
        {
            if (name.EndsWith(
                    resourceName,
                    StringComparison.OrdinalIgnoreCase))
            {
                resource = name;
                break;
            }
        }

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
            throw new Exception(
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
}
```
