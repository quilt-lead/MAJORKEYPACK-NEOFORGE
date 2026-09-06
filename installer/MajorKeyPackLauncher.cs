using System;
using System.Diagnostics;
using System.IO;

class Program
{
    static int Main()
    {
        string baseDir = AppContext.BaseDirectory;
        string script = Path.Combine(baseDir, "Install-MajorKeyPack.ps1");

        if (!File.Exists(script))
        {
            Console.Error.WriteLine("Install-MajorKeyPack.ps1 was not found.");
            Console.WriteLine("Press any key to exit...");
            Console.ReadKey();
            return 1;
        }

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"",
            UseShellExecute = true,
            WorkingDirectory = baseDir
        };

        using var process = Process.Start(psi);
        process.WaitForExit();
        return process.ExitCode;
    }
}
