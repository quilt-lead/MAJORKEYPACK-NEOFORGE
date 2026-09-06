using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows.Forms;

internal static class Program
{
    [STAThread]
    static int Main()
    {
        try
        {
            string appData = Environment.GetFolderPath(
                Environment.SpecialFolder.ApplicationData);

            string minecraftDirectory =
                Path.Combine(appData, ".minecraft");

            string versionsDirectory =
                Path.Combine(minecraftDirectory, "versions");

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

            bool forgeFound =
                Directory.Exists(versionsDirectory) &&
                Directory.GetDirectories(versionsDirectory)
                    .Any(x =>
                        Path.GetFileName(x).StartsWith(
                            "1.20.1-forge-",
                            StringComparison.OrdinalIgnoreCase));

            if (!forgeFound)
            {
                const string forgeUrl =
                    "https://files.minecraftforge.net/net/minecraftforge/forge/index_1.20.1.html";

                DialogResult result = MessageBox.Show(
                    "Forge 1.20.1 was not found.\n\n" +
                    "Please install Forge 1.20.1 before installing Major Key Pack.\n\n" +
                    "Click Yes to open the official Forge download page.",
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
                }

                return 1;
            }

            string resourceName =
                "MajorKeyPackInstaller.Install-MajorKeyPack.ps1";

            using Stream? resource =
                Assembly.GetExecutingAssembly()
                    .GetManifestResourceStream(resourceName);

            if (resource == null)
            {
                MessageBox.Show(
                    "The installer script is missing from this EXE.",
                    "Major Key Pack",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);

                return 1;
            }

            string tempDirectory = Path.Combine(
                Path.GetTempPath(),
                "MajorKeyPack-" + Guid.NewGuid().ToString("N"));

            Directory.CreateDirectory(tempDirectory);

            string scriptPath =
                Path.Combine(tempDirectory, "Install-MajorKeyPack.ps1");

            using (FileStream output = File.Create(scriptPath))
            {
                resource.CopyTo(output);
            }

            ProcessStartInfo psi = new ProcessStartInfo
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

            using Process? process = Process.Start(psi);

            if (process == null)
            {
                MessageBox.Show(
                    "Failed to start the installer.",
                    "Major Key Pack",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);

                return 1;
            }

            process.WaitForExit();

            int exitCode = process.ExitCode;

            try
            {
                Directory.Delete(tempDirectory, true);
            }
            catch
            {
            }

            return exitCode;
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Major Key Pack installer failed.\n\n" +
                ex.Message,
                "Major Key Pack",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);

            return 1;
        }
    }
}

