using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Windows.Forms;

internal static class Program
{
    private const string Repository = "quilt-lead/MAJORKEYPACK";
    private const string InstallerAsset = "MajorKeyPack-Installer.exe";

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

            int currentRelease = GetReleaseNumber(currentVersion);

            if (Environment.GetEnvironmentVariable("MAJORKEYPACK_SKIP_UPDATE") != "1")
            {
                PrintUpdateCheck(currentRelease);

                if (TryUpdate(currentRelease))
                    return 0;
            }

            return RunInstaller(currentRelease);
        }
        catch (Exception ex)
        {
            Console.WriteLine();
            Console.WriteLine("========================================");
            Console.WriteLine(" INSTALLATION FAILED");
            Console.WriteLine("========================================");
            Console.WriteLine();
            Console.WriteLine(ex.Message);
            Console.WriteLine();

            MessageBox.Show(
                "Major Key Pack installer failed.\n\n" + ex,
                "Major Key Pack",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);

            return 1;
        }
    }

    private static int GetReleaseNumber(string version)
    {
        string[] parts = version.Split('.');

        if (parts.Length >= 3 &&
            int.TryParse(parts[2], out int release))
        {
            return release;
        }

        return 0;
    }

    private static void PrintUpdateCheck(int currentRelease)
    {
        Console.WriteLine();
        Console.WriteLine("========================================");
        Console.WriteLine("        CHECKING FOR UPDATES");
        Console.WriteLine("========================================");
        Console.WriteLine();
        Console.WriteLine("Checking GitHub latest release...");
        Console.WriteLine($"Current installer: v{currentRelease}");
        Console.WriteLine();
    }

    private static bool TryUpdate(int currentRelease)
    {
        try
        {
            using HttpClient client = new HttpClient();

            client.DefaultRequestHeaders.UserAgent.ParseAdd(
                "MajorKeyPackInstaller");

            string apiUrl =
                $"https://api.github.com/repos/{Repository}/releases/latest";

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

            if (!tag.StartsWith(
                    "v",
                    StringComparison.OrdinalIgnoreCase))
            {
                Console.WriteLine(
                    $"GitHub latest release tag was not recognized: {tag}");

                Console.WriteLine(
                    "Continuing with the current installer.");

                return false;
            }

            if (!int.TryParse(
                    tag.Substring(1),
                    out int latestRelease))
            {
                Console.WriteLine(
                    $"GitHub latest release tag was not recognized: {tag}");

                Console.WriteLine(
                    "Continuing with the current installer.");

                return false;
            }

            Console.WriteLine($"Latest installer:  v{latestRelease}");
            Console.WriteLine();

            if (latestRelease <= currentRelease)
            {
                Console.WriteLine(
                    "Installer is up to date.");

                Console.WriteLine();

                return false;
            }

            Console.WriteLine("========================================");
            Console.WriteLine("        UPDATE AVAILABLE");
            Console.WriteLine("========================================");
            Console.WriteLine();
            Console.WriteLine(
                "A newer Major Key Pack installer is available.");
            Console.WriteLine();
            Console.WriteLine(
                $"Current: v{currentRelease}");
            Console.WriteLine(
                $"Latest:  v{latestRelease}");
            Console.WriteLine();
            Console.WriteLine(
                "Stopping current installation...");
            Console.WriteLine(
                "Downloading latest installer...");
            Console.WriteLine();

            JsonElement assets =
                document.RootElement.GetProperty("assets");

            string? downloadUrl = null;

            foreach (JsonElement asset in assets.EnumerateArray())
            {
                string name =
                    asset.GetProperty("name")
                        .GetString() ?? "";

                if (name.Equals(
                        InstallerAsset,
                        StringComparison.OrdinalIgnoreCase))
                {
                    downloadUrl =
                        asset.GetProperty(
                            "browser_download_url")
                            .GetString();

                    break;
                }
            }

            if (string.IsNullOrWhiteSpace(downloadUrl))
            {
                Console.WriteLine(
                    "The latest release does not contain " +
                    InstallerAsset);

                Console.WriteLine(
                    "Continuing with the current installer.");

                return false;
            }

            string updateDirectory =
                Path.Combine(
                    Path.GetTempPath(),
                    "MajorKeyPackUpdate-" +
                    Guid.NewGuid().ToString("N"));

            Directory.CreateDirectory(updateDirectory);

            string newInstaller =
                Path.Combine(
                    updateDirectory,
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
                File.Create(newInstaller);

            input.CopyTo(output);

            if (!File.Exists(newInstaller))
            {
                throw new Exception(
                    "The updated installer could not be downloaded.");
            }

            FileInfo downloadedFile =
                new FileInfo(newInstaller);

            if (downloadedFile.Length < 1000000)
            {
                throw new Exception(
                    "The downloaded installer is invalid.");
            }

            Console.WriteLine();
            Console.WriteLine(
                "Latest installer downloaded successfully.");

            Console.WriteLine(
                $"Starting Major Key Pack v{latestRelease}...");

            Console.WriteLine();
            Console.WriteLine(
                "The current installer will now close.");

            Console.WriteLine();

            ProcessStartInfo processInfo =
                new ProcessStartInfo
                {
                    FileName = newInstaller,
                    UseShellExecute = true
                };

            processInfo.EnvironmentVariables[
                "MAJORKEYPACK_SKIP_UPDATE"] = "1";

            Process? process =
                Process.Start(processInfo);

            if (process == null)
            {
                throw new Exception(
                    "Could not start the updated installer.");
            }

            return true;
        }
        catch (Exception ex)
        {
            Console.WriteLine();
            Console.WriteLine(
                "Could not check for installer updates.");

            Console.WriteLine(
                ex.Message);

            Console.WriteLine();
            Console.WriteLine(
                "Continuing with the current installer.");

            Console.WriteLine();

            return false;
        }
    }

    private static int RunInstaller(int currentRelease)
    {
        string appData =
            Environment.GetFolderPath(
                Environment.SpecialFolder.ApplicationData);

        string minecraftDirectory =
            Path.Combine(
                appData,
                ".minecraft");

        string installDirectory =
            Path.Combine(
                appData,
                "MajorKeyPack");

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

            DialogResult result =
                MessageBox.Show(
                    "Forge 1.20.1 was not found.\n\n" +
                    "Please install Forge 1.20.1 before installing " +
                    "Major Key Pack.\n\n" +
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

        int exitCode =
            process.ExitCode;

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
