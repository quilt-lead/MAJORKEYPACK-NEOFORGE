using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

internal static class Program
{
    [STAThread]
    static int Main()
    {
        try
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

            return exitCode;
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
}
