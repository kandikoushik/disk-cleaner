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
}
