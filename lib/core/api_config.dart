class ApiConfig {
  // Base URL API
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: "https://albirr.web.id/api",
  );

  // API Key Header
  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: "prod_Uo0j5rtuOcRH3vDPvgAfHHuQspJfMNOEfooSKOhZt7E",
  );

  // Header default untuk setiap request
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-API-KEY': apiKey.trim(),
  };
}