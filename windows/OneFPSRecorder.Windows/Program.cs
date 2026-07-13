using System.Threading;
using System.Windows;

namespace OneFPSRecorder.WindowsApp;

public static class Program
{
    [STAThread]
    public static void Main()
    {
        using var singleInstance = new Mutex(initiallyOwned: true, "Local\\OneFPSRecorder.Windows.Singleton", out var createdNew);
        if (!createdNew) return;
        var application = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        AppHost? host = null;
        application.DispatcherUnhandledException += (_, eventArgs) =>
        {
            MessageBox.Show(eventArgs.Exception.Message, "OneFPSRecorder", MessageBoxButton.OK, MessageBoxImage.Error);
            eventArgs.Handled = true;
        };
        application.Startup += async (_, _) =>
        {
            host = new AppHost();
            await host.InitializeAsync();
        };
        application.Exit += (_, _) => host?.Dispose();
        application.Run();
    }
}
