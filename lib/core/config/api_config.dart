/// API Configuration
///
/// Centralized configuration for backend API base URL.
/// Update this value when your backend server IP changes.
class ApiConfig {
  // Change this to your backend server's IP address
  // Common options:
  // - "http://localhost:8000" (if running on same machine)
  // - "http://127.0.0.1:8000" (if running on same machine)
  // - "http://192.168.1.14:8000" (your current IP - update if it changes)
  // - "http://10.0.2.2:8000" (Android emulator - maps to host's localhost)
  //static const String baseUrl = "http://192.168.1.16:8000";
  static const String baseUrl = "https://render-mendlify.onrender.com";

  // Helper method to get full endpoint URL
  static String getEndpoint(String path) {
    // Remove leading slash if present to avoid double slashes
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return "$baseUrl/$cleanPath";
  }
}
