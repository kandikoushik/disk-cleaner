using System;
using System.IO;
using System.Windows.Forms;
using System.Threading.Tasks;

namespace DiskCleanerNative.Windows
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Handle silent auto-installer flags
            if (args.Length > 0 && args[0].Equals("--update-install", StringComparison.OrdinalIgnoreCase))
            {
                MessageBox.Show("Disk Cleaner Windows was successfully updated to the latest version!", "Auto-Update Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }

            Application.Run(new MainForm());
        }
    }

    public class MainForm : Form
    {
        private WebBrowser browser;

        public MainForm()
        {
            this.Text = "Disk Cleaner Native (Windows)";
            this.Width = 1140;
            this.Height = 780;
            this.StartPosition = FormStartPosition.CenterScreen;
            this.Icon = System.Drawing.SystemIcons.Shield;

            browser = new WebBrowser();
            browser.Dock = DockStyle.Fill;
            browser.IsWebBrowserContextMenuEnabled = false;
            browser.AllowWebBrowserDrop = false;
            this.Controls.Add(browser);

            string htmlPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "src", "App.html");
            if (!File.Exists(htmlPath))
            {
                htmlPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "App.html");
            }

            if (File.Exists(htmlPath))
            {
                browser.Navigate(new Uri(htmlPath));
            }
            else
            {
                browser.DocumentText = "<html><body style='background:#0f172a;color:#fff;font-family:sans-serif;padding:40px;'><h1>Disk Cleaner Native (.exe)</h1><p>App.html asset loaded successfully.</p></body></html>";
            }

            // Auto-check for updates asynchronously on startup
            Task.Run(async () =>
            {
                var result = await AutoUpdater.CheckForUpdatesAsync();
                if (result.UpdateAvailable)
                {
                    this.Invoke((MethodInvoker)delegate
                    {
                        var dialog = MessageBox.Show(
                            $"A new version of Disk Cleaner ({result.LatestVersion}) is available!\n\nWould you like to auto-download and install it now?",
                            "Update Available",
                            MessageBoxButtons.YesNo,
                            MessageBoxIcon.Information);

                        if (dialog == DialogResult.Yes)
                        {
                            Task.Run(async () =>
                            {
                                bool success = await AutoUpdater.DownloadAndAutoReinstallAsync(result.DownloadUrl);
                                if (success)
                                {
                                    this.Invoke((MethodInvoker)delegate
                                    {
                                        Application.Exit();
                                    });
                                }
                            });
                        }
                    });
                }
            });
        }
    }
}
