using System;
using System.IO;
using System.Security.Cryptography;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace DiskCleanerNative.Windows
{
    public class TargetItem
    {
        public string Id { get; set; }
        public string Label { get; set; }
        public string Note { get; set; }
        public string Risk { get; set; }
        public string Category { get; set; }
        public string PathPattern { get; set; }
        public long MeasuredSize { get; set; }
    }

    public static class CleanerEngine
    {
        public static string ExpandEnvironmentVariables(string pathPattern)
        {
            return Environment.ExpandEnvironmentVariables(pathPattern);
        }

        public static long MeasureDirectorySize(string directoryPath)
        {
            if (!Directory.Exists(directoryPath)) return 0;
            long size = 0;
            try
            {
                var dirInfo = new DirectoryInfo(directoryPath);
                foreach (var file in dirInfo.GetFiles("*", SearchOption.AllDirectories))
                {
                    size += file.Length;
                }
            }
            catch { }
            return size;
        }

        public static async Task<long> CleanTargetAsync(TargetItem item)
        {
            long freed = 0;
            string expanded = ExpandEnvironmentVariables(item.PathPattern);
            string dir = expanded.Replace("*", "").TrimEnd('\\');

            if (Directory.Exists(dir))
            {
                await Task.Run(() =>
                {
                    try
                    {
                        foreach (var file in Directory.GetFiles(dir, "*", SearchOption.AllDirectories))
                        {
                            try
                            {
                                var fi = new FileInfo(file);
                                long len = fi.Length;
                                File.Delete(file);
                                freed += len;
                            }
                            catch { }
                        }
                    }
                    catch { }
                });
            }
            return freed;
        }

        public static async Task ShredFileAsync(string filePath)
        {
            if (!File.Exists(filePath)) return;
            await Task.Run(() =>
            {
                try
                {
                    long length = new FileInfo(filePath).Length;
                    using (var stream = new FileStream(filePath, FileMode.Open, FileAccess.Write))
                    {
                        byte[] zeroData = new byte[Math.Min(length, 4096)];
                        long remaining = length;
                        while (remaining > 0)
                        {
                            int count = (int)Math.Min(remaining, zeroData.Length);
                            stream.Write(zeroData, 0, count);
                            remaining -= count;
                        }
                    }
                    File.Delete(filePath);
                }
                catch { }
            });
        }

        public static string RunMaintenanceTask(string taskId)
        {
            switch (taskId)
            {
                case "dns":
                    System.Diagnostics.Process.Start("ipconfig", "/flushdns");
                    return "Windows DNS Resolver Cache flushed.";
                case "dism":
                    System.Diagnostics.Process.Start("Dism.exe", "/Online /Cleanup-Image /StartComponentCleanup");
                    return "DISM component store cleanup started.";
                case "iconcache":
                    System.Diagnostics.Process.Start("ie4uinit.exe", "-show");
                    return "Windows Icon Cache refreshed.";
                default:
                    return "Task executed.";
            }
        }
    }

    public class UpdateCheckResult
    {
        public bool UpdateAvailable { get; set; }
        public string LatestVersion { get; set; }
        public string DownloadUrl { get; set; }
        public string ReleaseNotes { get; set; }
    }

    public static class AutoUpdater
    {
        public const string CurrentVersion = "2.0.0";
        public const string DefaultUpdateServerUrl = "https://raw.githubusercontent.com/dyuthitech/disk-cleaner-windows/main/version.json";

        public static async Task<UpdateCheckResult> CheckForUpdatesAsync(string serverUrl = null)
        {
            string url = string.IsNullOrEmpty(serverUrl) ? DefaultUpdateServerUrl : serverUrl;
            try
            {
                using (var client = new System.Net.Http.HttpClient())
                {
                    client.Timeout = TimeSpan.FromSeconds(8);
                    string json = await client.GetStringAsync(url);
                    // Simple parse version JSON
                    if (json.Contains("\"version\""))
                    {
                        int vStart = json.IndexOf("\"version\"") + 10;
                        int q1 = json.IndexOf('"', vStart);
                        int q2 = json.IndexOf('"', q1 + 1);
                        string latestVer = json.Substring(q1 + 1, q2 - q1 - 1);

                        int uStart = json.IndexOf("\"downloadUrl\"");
                        string dlUrl = "";
                        if (uStart > 0)
                        {
                            int uq1 = json.IndexOf('"', uStart + 13);
                            int uq2 = json.IndexOf('"', uq1 + 1);
                            dlUrl = json.Substring(uq1 + 1, uq2 - uq1 - 1);
                        }

                        bool hasNewer = String.Compare(latestVer, CurrentVersion, StringComparison.OrdinalIgnoreCase) > 0;
                        return new UpdateCheckResult
                        {
                            UpdateAvailable = hasNewer,
                            LatestVersion = latestVer,
                            DownloadUrl = dlUrl,
                            ReleaseNotes = "New features, performance enhancements, and bug fixes."
                        };
                    }
                }
            }
            catch { }
            return new UpdateCheckResult { UpdateAvailable = false, LatestVersion = CurrentVersion };
        }

        public static async Task<bool> DownloadAndAutoReinstallAsync(string downloadUrl)
        {
            if (string.IsNullOrEmpty(downloadUrl)) return false;
            try
            {
                string tempFile = Path.Combine(Path.GetTempPath(), "DiskCleanerSetup.exe");
                using (var client = new System.Net.Http.HttpClient())
                {
                    byte[] data = await client.GetByteArrayAsync(downloadUrl);
                    File.WriteAllBytes(tempFile, data);
                }

                // Launch silent background setup installer and auto-restart
                var psi = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = tempFile,
                    Arguments = "/SILENT /NORESTART",
                    UseShellExecute = true
                };
                System.Diagnostics.Process.Start(psi);
                return true;
            }
            catch
            {
                return false;
            }
        }
    }
}
