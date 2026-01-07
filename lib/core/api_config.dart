class ApiConfig {
  // Base URL API
  static const String baseUrl = "https://albirr.web.id/api";
  
  // API Key Header
  static const String apiKey = "prod_Uo0j5rtuOcRH3vDPvgAfHHuQspJfMNOEfooSKOhZt7E";

  // Header default untuk setiap request
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-API-KEY': apiKey.trim(),
  };
}