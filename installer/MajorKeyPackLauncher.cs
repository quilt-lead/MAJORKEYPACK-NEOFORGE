using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Forms;

internal static class Program
{
    // This is replaced by GitHub Actions when building the EXE.
    private const string CurrentVersion = "v${{ steps.version.outputs.number }}";

    // CHANGE THIS to your GitHub repository.
    private const string GitHubOwner = "YOUR_GITHUB_USERNAME";
    private const string GitHubRepository = "YOUR_REPOSITORY_NAME";

    private const string GitHubLatestReleaseUrl =
        "https://api.github.com/repos/" +
        GitHubOwner + "/" +
        GitHubRepository +
        "/releases/latest";

    [STAThread]
    static int Main()
    {
        try
        {
            // Check for a newer installer before doing anything else.
            int updateResult = CheckForUpdateAsync().GetAwaiter().GetResult();

            if (updateResult != 0)
                return updateResult;

            return Install();
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Major Key Pack installer failed.\n\n" +
                ex,
                "Major Key Pack",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);

            return 1;
        }
    }

    private static async Task<int> CheckForUpdateAsync()
    {
        try
        {
            using HttpClient client = new HttpClient();

            client.DefaultRequestHeaders.UserAgent.ParseAdd(
                "MajorKeyPack-Installer");

            client.Timeout = TimeSpan.FromSeconds(10);

            using HttpResponseMessage response =
                await client.GetAsync(GitHubLatestReleaseUrl);

            if (!response.IsSuccessStatusCode)
            {
                // If GitHub cannot be reached, don't prevent installation.
                return 0;
            }

            string json = await response.Content.ReadAsStringAsync();

            using JsonDocument document =
                JsonDocument.Parse(json);

            JsonElement root = document.RootElement;

            if (!root.TryGetProperty("tag_name", out JsonElement tagElement))
                return 0;

            string? latestVersion = tagElement.GetString();

            if (string.IsNullOrWhiteSpace(latestVersion))
                return 0;

            latestVersion = latestVersion.Trim();

            Console.WriteLine(
                $"Current version: {CurrentVersion}");

            Console.WriteLine(
                $"Latest version: {latestVersion}");

            if (!IsNewerVersion(latestVersion, CurrentVersion))
                return 0;

            DialogResult result = MessageBox.Show(
                "A newer version of Major Key Pack is available.\n\n" +
                "Installed installer: " + CurrentVersion + "\n" +
                "Latest installer: " + latestVersion + "\n\n" +
                "Would you like to update the installer now?",
                "Major Key Pack Update",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information);

            if (result != DialogResult.Yes)
                return 0;

            string? downloadUrl =
                FindInstallerDownloadUrl(root);

            if (string.IsNullOrWhiteSpace(downloadUrl))
            {
                MessageBox.Show(
                    "A newer release was found, but the installer " +
                    "download could not be located.\n\n" +
                    "Please download the latest release manually.",
                    "Major Key Pack",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);

                return 0;
            }

            string tempDirectory = Path.Combine(
                Path.GetTempPath(),
                "MajorKeyPackUpdater-" +
                Guid.NewGuid().ToString("N"));

            Directory.CreateDirectory(tempDirectory);

            string newInstallerPath =
                Path.Combine(
                    tempDirectory,
                    "MajorKeyPack-Installer.exe");

            using HttpResponseMessage downloadResponse =
                await client.GetAsync(downloadUrl);

            downloadResponse.EnsureSuccessStatusCode();

            await using Stream input =
                await downloadResponse.Content.ReadAsStreamAsync();

            await using FileStream output =
                File.Create(newInstallerPath);

            await input.CopyToAsync(output);

            output.Close();

            Process.Start(new ProcessStartInfo
            {
                FileName = newInstallerPath,
                UseShellExecute = true
            });

            // This installer is outdated.
            // Let the newly downloaded installer take over.
            return 0;
        }
        catch
        {
            // Updating is optional. If GitHub is unavailable,
            // continue with the installer we already have.
            return 0;
        }
    }

    private static string? FindInstallerDownloadUrl(
        JsonElement release)
    {
        if (!release.TryGetProperty(
                "assets",
                out JsonElement assets))
        {
            return null;
        }

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

            if (!asset.TryGetProperty(
                    "browser_download_url",
                    out JsonElement urlElement))
            {
                continue;
            }

            return urlElement.GetString();
        }

        return null;
    }

    private static bool IsNewerVersion(
        string latest,
        string current)
    {
        if (!TryGetVersionNumber(latest, out int latestNumber))
            return false;

        if (!TryGetVersionNumber(current, out int currentNumber))
            return false;

        return latestNumber > currentNumber;
    }

    private static bool TryGetVersionNumber(
        string version,
        out int number)
    {
        number = 0;

        version = version.Trim();

        if (version.StartsWith("v", StringComparison.OrdinalIgnoreCase))
            version = version.Substring(1);

        return int.TryParse(version, out number);
    }

    private static int Install()
    {
        string appData =
            Environment.GetFolderPath(
                Environment.SpecialFolder.ApplicationData);

        string minecraftDirectory =
            Path.Combine(appData, ".minecraft");

        string installDirectory =
            Path.Combine(appData, "MajorKeyPack");

        if (!Directory.Exists(minecraftDirectory))
        {
            MessageBox.Show(
                "Minecraft Java Edition was not found.\n\n" +
                "Please install Minecraft Java Edition first.",
                "Major Key Pack",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);

            return 1;
        }

        string versionsDirectory =
            Path.Combine(
                minecraftDirectory,
                "versions");

        bool forgeFound =
            Directory.Exists(versionsDirectory) &&
            Directory.GetDirectories(versionsDirectory)
                .Any(x =>
                    Path.GetFileName(x)
                        .StartsWith(
                            "1.20.1-forge-",
                            StringComparison.OrdinalIgnoreCase));

        if (!forgeFound)
        {
            const string forgeUrl =
                "https://files.minecraftforge.net/net/minecraftforge/forge/index_1.20.1.html";

            DialogResult result = MessageBox.Show(
                "Forge 1.20.1 was not found.\n\n" +
                "Please install Forge 1.20.1 before installing Major Key Pack.\n\n" +
                "Click Yes to open the official Forge download page.\n" +
                "Click No to exit.",
                "Major Key Pack - Forge Required",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Warning);

            if (result == DialogResult.Yes)
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = forgeUrl,
                    UseShellExecute = true
                });

                MessageBox.Show(
                    "Install Forge 1.20.1, then run the Major Key Pack installer again.",
                    "Major Key Pack",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }

            return 1;
        }

        const string resourceName =
            "MajorKeyPackInstaller.Install-MajorKeyPack.ps1";

        using Stream? resource =
            Assembly.GetExecutingAssembly()
                .GetManifestResourceStream(resourceName);

        if (resource == null)
        {
            MessageBox.Show(
                "The installer script could not be found inside the EXE.",
                "Major Key Pack",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);

            return 1;
        }

        string tempDirectory =
            Path.Combine(
                Path.GetTempPath(),
                "MajorKeyPack-" +
                Guid.NewGuid().ToString("N"));

        Directory.CreateDirectory(tempDirectory);

        string scriptPath =
            Path.Combine(
                tempDirectory,
                "Install-MajorKeyPack.ps1");

        using (FileStream output =
            File.Create(scriptPath))
        {
            resource.CopyTo(output);
        }

        ProcessStartInfo psi =
            new ProcessStartInfo
            {
                FileName = "powershell.exe",
                UseShellExecute = false,
                CreateNoWindow = false,
                WorkingDirectory = tempDirectory
            };

        psi.ArgumentList.Add("-NoProfile");
        psi.ArgumentList.Add("-ExecutionPolicy");
        psi.ArgumentList.Add("Bypass");
        psi.ArgumentList.Add("-File");
        psi.ArgumentList.Add(scriptPath);
        psi.ArgumentList.Add("-InstallDirectory");
        psi.ArgumentList.Add(installDirectory);

        using Process? process =
            Process.Start(psi);

        if (process == null)
        {
            MessageBox.Show(
                "Failed to start PowerShell.",
                "Major Key Pack",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);

            return 1;
        }

        process.WaitForExit();

        int exitCode = process.ExitCode;

        try
        {
            Directory.Delete(
                tempDirectory,
                true);
        }
        catch
        {
        }

        if (exitCode != 0)
        {
            MessageBox.Show(
                "Major Key Pack installation failed.\n\n" +
                "PowerShell exit code: " +
                exitCode,
                "Major Key Pack",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);

            return exitCode;
        }

        MessageBox.Show(
            "Major Key Pack was installed successfully!",
            "Major Key Pack",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);

        return 0;
    }
}