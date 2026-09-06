using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Forms;

internal static class Program
{
    private const string Repository =
        "quilt-lead/MAJORKEYPACK";

    private const string InstallerAsset =
        "MajorKeyPack-Installer.exe";

    [STAThread]
    static int Main()
    {
        try
        {
            string currentVersion =
                Assembly.GetExecutingAssembly()
                    .GetName()
                    .Version?
                    .ToString() ?? "0.0.0";

            if (Environment.GetEnvironmentVariable(
                    "MAJORKEYPACK_SKIP_UPDATE") != "1")
            {
                if (TryUpdate(currentVersion))
                    return 0;
            }

            return RunInstaller();
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Major Key Pack installer failed.\n\n" +
                ex.ToString(),
                "Major Key Pack",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);

            return 1;
        }
    }

    private static bool TryUpdate(string currentVersion)
    {
        try
        {
            using HttpClient client = new HttpClient();

            client.DefaultRequestHeaders.UserAgent.ParseAdd(
                "MajorKeyPackInstaller");

            string apiUrl =
                "https://api.github.com/repos/" +
                Repository +
                "/releases/latest";

            string json =
                client.GetStringAsync(apiUrl)
                    .GetAwaiter()
                    .GetResult();

            using JsonDocument document =
                JsonDocument.Parse(json);

            string tag =
                document.RootElement
                    .GetProperty("tag_name")
                    .GetString() ?? "";

            if (!tag.StartsWith("v",
                    StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            if (!int.TryParse(
                    tag.Substring(1),
                    out int latestVersion))
            {
                return false;
            }

            int currentRelease = 0;

            string[] currentParts =
                currentVersion.Split('.');

            if (currentParts.Length > 0)
            {
                int.TryParse(
                    currentParts[0],
                    out currentRelease);
            }

            if (latestVersion <= currentRelease)
                return false;

            JsonElement assets =
                document.RootElement
                    .GetProperty("assets");

            string? downloadUrl = null;

            foreach (JsonElement asset in assets.EnumerateArray())
            {
                string name =
                    asset.GetProperty("name").GetString() ?? "";

                if (name.Equals(
                        InstallerAsset,
                        StringComparison.OrdinalIgnoreCase))
                {
                    downloadUrl =
                        asset.GetProperty("browser_download_url")
                            .GetString();

                    break;
                }
            }

            if (string.IsNullOrWhiteSpace(downloadUrl))
            {
                return false;
            }

            DialogResult result = MessageBox.Show(
                "A newer Major Key Pack installer is available.\n\n" +
                "Current version: v" + currentRelease + "\n" +
                "Latest version: v" + latestVersion + "\n\n" +
                "Download and install the update now?",
                "Major Key Pack - Update Available",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information);

            if (result != DialogResult.Yes)
                return false;

            string tempDirectory =
                Path.Combine(
                    Path.GetTempPath(),
                    "MajorKeyPackUpdate-" +
                    Guid.NewGuid().ToString("N"));

            Directory.CreateDirectory(tempDirectory);

            string newExe =
                Path.Combine(
                    tempDirectory,
                    InstallerAsset);

            using HttpResponseMessage response =
                client.GetAsync(
                    downloadUrl,
                    HttpCompletionOption.ResponseHeadersRead)
                    .GetAwaiter()
                    .GetResult();

            response.EnsureSuccessStatusCode();

            using Stream input =
                response.Content.ReadAsStream();

            using FileStream output =
                File.Create(newExe);

            input.CopyTo(output);

            if (!File.Exists(newExe) ||
                new FileInfo(newExe).Length < 1000000)
            {
                throw new Exception(
                    "The downloaded installer is invalid.");
            }

            MessageBox.Show(
                "Installer update downloaded successfully.\n\n" +
                "Starting v" + latestVersion + "...",
                "Major Key Pack",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);

            ProcessStartInfo psi =
                new ProcessStartInfo
                {
                    FileName = newExe,
                    UseShellExecute = true
                };

            Process? process =
                Process.Start(psi);

            if (process == null)
                throw new Exception(
                    "Could not start the updated installer.");

            return true;
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Could not check for installer updates.`n`n" +
                ex.Message,
                "Major Key Pack - Update Check",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);

            return false;
        }
    }

    private static int RunInstaller()
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
            Path.Combine(minecraftDirectory, "versions");

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

            DialogResult result =
                MessageBox.Show(
                    "Forge 1.20.1 was not found.\n\n" +
                    "Please install Forge 1.20.1 before installing Major Key Pack.\n\n" +
                    "Click Yes to open the official Forge download page.\n" +
                    "Click No to exit.",
                    "Major Key Pack - Forge Required",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning);

            if (result == DialogResult.Yes)
            {
                Process.Start(
                    new ProcessStartInfo
                    {
                        FileName = forgeUrl,
                        UseShellExecute = true
                    });
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