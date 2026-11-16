using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

internal static class Launcher
{
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
    [STAThread]
    private static void Main()
    {
        try
        {
            string folder = AppDomain.CurrentDomain.BaseDirectory;
            string script = Path.Combine(folder, "Private Moments.ps1");
            if (!File.Exists(script))
                throw new FileNotFoundException("Extraia todos os arquivos do ZIP para a mesma pasta antes de abrir o aplicativo.");
            SetCurrentProcessExplicitAppUserModelID("Louzadones.PrivateMoments");
            Directory.SetCurrentDirectory(folder);
            // Own the actual UI process so Windows uses our executable icon, not powershell.exe.
            using (Runspace runspace = RunspaceFactory.CreateRunspace())
            {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                using (PowerShell shell = PowerShell.Create())
                {
                    shell.Runspace = runspace;
                    shell.AddCommand("Set-ExecutionPolicy").AddParameter("Scope", "Process")
                        .AddParameter("ExecutionPolicy", "Bypass").AddParameter("Force").Invoke();
                    shell.Commands.Clear();
                    shell.Streams.Error.Clear();
                    shell.AddCommand(script).Invoke();
                    if (shell.Streams.Error.Count > 0)
                        throw new InvalidOperationException(shell.Streams.Error[0].ToString());
                }
            }
        }
        catch (Exception error)
        {
            try { File.AppendAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"app-error.log"), DateTime.Now.ToString("s") + " " + error.ToString() + Environment.NewLine); } catch {}
            Environment.ExitCode = 1;
            if (Environment.GetEnvironmentVariable("PRIVATE_MOMENTS_TEST_MODE") == "1") return;
            MessageBox.Show(error.Message, "Private Moments", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
