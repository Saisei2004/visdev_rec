using Microsoft.Win32;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Forms = System.Windows.Forms;

namespace OneFPSRecorder.WindowsApp;

public sealed partial class MonitorService
{
    private const int EddGetDeviceInterfaceName = 0x00000001;

    public IReadOnlyList<MonitorDescriptor> GetMonitors()
    {
        var values = new List<MonitorDescriptor>();
        foreach (var screen in Forms.Screen.AllScreens)
        {
            var adapter = NewDisplayDevice();
            var monitor = NewDisplayDevice();
            _ = EnumDisplayDevices(screen.DeviceName, 0, ref monitor, EddGetDeviceInterfaceName);
            _ = EnumDisplayDevices(null, Math.Max(0, ParseDisplayNumber(screen.DeviceName) - 1), ref adapter, 0);
            var devicePath = FirstNonEmpty(monitor.DeviceID, monitor.DeviceKey, screen.DeviceName);
            var edid = ReadEdid(monitor.DeviceID);
            var edidIdentity = ParseEdidIdentity(edid);
            var identityMaterial = string.IsNullOrEmpty(edidIdentity)
                ? $"path:{devicePath.ToUpperInvariant()}"
                : $"edid:{edidIdentity}";
            var stableId = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(identityMaterial))).ToLowerInvariant();
            var displayNumber = ParseDisplayNumber(screen.DeviceName);
            values.Add(new MonitorDescriptor(
                stableId,
                FirstNonEmpty(monitor.DeviceString, $"ディスプレイ {displayNumber}"),
                screen.DeviceName,
                devicePath,
                edidIdentity,
                Math.Max(0, displayNumber - 1),
                screen.Bounds.Left,
                screen.Bounds.Top,
                screen.Bounds.Width,
                screen.Bounds.Height,
                screen.Primary));
        }
        var duplicates = values.GroupBy(value => value.StableId, StringComparer.OrdinalIgnoreCase)
            .Where(group => group.Count() > 1)
            .SelectMany(group => group)
            .ToHashSet();
        if (duplicates.Count > 0)
        {
            for (var index = 0; index < values.Count; index++)
            {
                if (!duplicates.Contains(values[index])) continue;
                var material = $"{values[index].EdidIdentity}|{values[index].DevicePath.ToUpperInvariant()}";
                values[index] = values[index] with
                {
                    StableId = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(material))).ToLowerInvariant(),
                };
            }
        }
        return values.OrderBy(value => value.DdaOutputIndex).ToArray();
    }

    private static DISPLAY_DEVICE NewDisplayDevice() => new() { cb = Marshal.SizeOf<DISPLAY_DEVICE>() };

    private static string FirstNonEmpty(params string?[] values) =>
        values.FirstOrDefault(value => !string.IsNullOrWhiteSpace(value))?.Trim() ?? "";

    private static int ParseDisplayNumber(string value)
    {
        var match = DisplayNumberRegex().Match(value);
        return match.Success && int.TryParse(match.Groups[1].Value, out var number) ? number : 1;
    }

    private static byte[] ReadEdid(string deviceId)
    {
        try
        {
            // \\?\DISPLAY#ABC123#instance#{guid} -> DISPLAY\ABC123\instance\Device Parameters
            var trimmed = deviceId.Replace("\\\\?\\", "", StringComparison.OrdinalIgnoreCase);
            var parts = trimmed.Split('#');
            if (parts.Length < 3 || !parts[0].Equals("DISPLAY", StringComparison.OrdinalIgnoreCase)) return [];
            var registryPath = $@"SYSTEM\CurrentControlSet\Enum\DISPLAY\{parts[1]}\{parts[2]}\Device Parameters";
            using var key = Registry.LocalMachine.OpenSubKey(registryPath);
            return key?.GetValue("EDID") as byte[] ?? [];
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or System.Security.SecurityException)
        {
            return [];
        }
    }

    private static string ParseEdidIdentity(byte[] edid)
    {
        if (edid.Length < 16) return "";
        var manufacturerWord = (edid[8] << 8) | edid[9];
        var manufacturer = new string([
            (char)(((manufacturerWord >> 10) & 31) + 64),
            (char)(((manufacturerWord >> 5) & 31) + 64),
            (char)((manufacturerWord & 31) + 64),
        ]);
        var product = BitConverter.ToUInt16(edid, 10).ToString("X4");
        var serial = BitConverter.ToUInt32(edid, 12);
        if (serial != 0) return $"{manufacturer}-{product}-{serial:X8}";
        return $"{manufacturer}-{product}-{Convert.ToHexString(SHA256.HashData(edid))[..16]}";
    }

    [GeneratedRegex(@"DISPLAY(\d+)$", RegexOptions.IgnoreCase)]
    private static partial Regex DisplayNumberRegex();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool EnumDisplayDevices(string? lpDevice, int iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, int dwFlags);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct DISPLAY_DEVICE
    {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }
}
