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
