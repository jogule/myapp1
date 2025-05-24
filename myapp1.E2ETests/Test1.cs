using Microsoft.Playwright;
using Microsoft.Playwright.MSTest;
using Microsoft.Extensions.Hosting;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.AspNetCore.Hosting;

namespace myapp1.E2ETests;

/// <summary>
/// End-to-end tests for the home page functionality.
/// These tests start a real server and use Playwright to interact with the web application.
/// </summary>
[TestClass]
public sealed class HomePageTests : PageTest
{
    private IHost? _host;
    private string? _baseUrl;

    [TestInitialize]
    public async Task SetUp()
    {
        // Find an available port for the test server
        var port = GetAvailablePort();
        _baseUrl = $"http://localhost:{port}";
        
        // Create a WebApplication builder with the same configuration as the main app
        var builder = WebApplication.CreateBuilder();
        
        // Add services exactly like the main application
        builder.Services.AddRazorComponents()
            .AddInteractiveServerComponents();
        
        // Configure the web host to listen on our test port
        builder.WebHost.UseUrls(_baseUrl);
        builder.Environment.EnvironmentName = "Testing";
        
        // Build the application
        var app = builder.Build();
        
        // Configure the pipeline (simplified for testing)
        if (!app.Environment.IsDevelopment())
        {
            app.UseExceptionHandler("/Error", createScopeForErrors: true);
            app.UseHsts();
        }

        // Skip HTTPS redirection and static assets for testing simplicity
        app.UseAntiforgery();
        app.MapRazorComponents<myapp1.Components.App>()
            .AddInteractiveServerRenderMode();

        // Start the host
        _host = app;
        await _host.StartAsync();
        
        Console.WriteLine($"Test server started at: {_baseUrl}");
        
        // Wait for the server to be ready
        await WaitForServerReady();
    }

    [TestCleanup]
    public async Task TearDown()
    {
        if (_host != null)
        {
            await _host.StopAsync();
            _host.Dispose();
        }
    }

    /// <summary>
    /// Waits for the test server to become ready to accept requests.
    /// </summary>
    private async Task WaitForServerReady()
    {
        const int maxRetries = 10;
        const int delayMs = 100;
        
        using var httpClient = new HttpClient();
        
        for (int i = 0; i < maxRetries; i++)
        {
            try
            {
                var response = await httpClient.GetAsync(_baseUrl);
                if (response.IsSuccessStatusCode)
                {
                    Console.WriteLine($"Server is ready after {i + 1} attempts");
                    return;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Attempt {i + 1}: {ex.Message}");
            }
            
            await Task.Delay(delayMs);
        }
        
        throw new TimeoutException("Server did not become ready within the expected time");
    }

    /// <summary>
    /// Gets an available port for the test server.
    /// </summary>
    private static int GetAvailablePort()
    {
        using var socket = new System.Net.Sockets.TcpListener(System.Net.IPAddress.Loopback, 0);
        socket.Start();
        var port = ((System.Net.IPEndPoint)socket.LocalEndpoint).Port;
        socket.Stop();
        return port;
    }

    /// <summary>
    /// Tests that the home page loads successfully and contains the expected content.
    /// </summary>
    [TestMethod]
    public async Task HomePageLoadsSuccessfully()
    {
        Console.WriteLine($"Testing home page at: {_baseUrl}");
        
        // Navigate to the home page
        await Page.GotoAsync(_baseUrl!);

        // Check that the page title is correct
        await Expect(Page).ToHaveTitleAsync("Home");

        // Check that the main heading is present
        await Expect(Page.Locator("h1")).ToContainTextAsync("Hello, world!");

        // Check that the welcome message is present
        await Expect(Page.Locator("body")).ToContainTextAsync("Welcome to your new app.");
        
        Console.WriteLine("✅ Home page test passed successfully!");
    }
}
