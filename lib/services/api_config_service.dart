// ========================================
// lib/services/api_config_service.dart
// ========================================
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfigService {
  static const String _googleApiKeyKey = 'google_api_key';
  static const String _openAiApiKeyKey = 'openai_api_key';
  static const String _ebayApiKeyKey = 'ebay_api_key';
  static const String _amazonApiKeyKey = 'amazon_api_key';

  // Google Services API Key
  static Future<void> setGoogleApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_googleApiKeyKey, apiKey);
  }

  static Future<String?> getGoogleApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_googleApiKeyKey);
  }

  // OpenAI API Key (for GPT-4 Vision and text processing)
  static Future<void> setOpenAiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openAiApiKeyKey, apiKey);
  }

  static Future<String?> getOpenAiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_openAiApiKeyKey);
  }

  // eBay API Key (for pricing lookups)
  static Future<void> setEbayApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ebayApiKeyKey, apiKey);
  }

  static Future<String?> getEbayApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ebayApiKeyKey);
  }

  // Amazon API Key (for pricing lookups)
  static Future<void> setAmazonApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_amazonApiKeyKey, apiKey);
  }

  static Future<String?> getAmazonApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_amazonApiKeyKey);
  }

  // Check if essential APIs are configured
  static Future<bool> isConfigured() async {
    final googleKey = await getGoogleApiKey();
    return googleKey != null && googleKey.isNotEmpty;
  }

  // Get all configured APIs status
  static Future<Map<String, bool>> getConfigurationStatus() async {
    return {
      'google': (await getGoogleApiKey())?.isNotEmpty ?? false,
      'openai': (await getOpenAiApiKey())?.isNotEmpty ?? false,
      'ebay': (await getEbayApiKey())?.isNotEmpty ?? false,
      'amazon': (await getAmazonApiKey())?.isNotEmpty ?? false,
    };
  }

  // Clear all API keys
  static Future<void> clearAllApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_googleApiKeyKey);
    await prefs.remove(_openAiApiKeyKey);
    await prefs.remove(_ebayApiKeyKey);
    await prefs.remove(_amazonApiKeyKey);
  }
}