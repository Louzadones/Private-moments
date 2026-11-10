using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Launcher
{
    [STAThread]
    private static void Main()
    {
        try
        {
            string folder = AppDomain.CurrentDomain.BaseDirectory;
            string script = Path.Combine(folder, "Sweet Sensation.ps1");
            if (!File.Exists(script))
                throw new FileNotFoundException("Extraia todos os arquivos do ZIP para a mesma pasta antes de abrir o aplicativo.");
            string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
            ProcessStartInfo info = new ProcessStartInfo();
            info.FileName = powershell;
            info.Arguments = "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"";
            info.WorkingDirectory = folder;
            info.UseShellExecute = false;
            info.CreateNoWindow = true;
            info.WindowStyle = ProcessWindowStyle.Hidden;
            Process.Start(info);
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "Sweet Sensation", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
