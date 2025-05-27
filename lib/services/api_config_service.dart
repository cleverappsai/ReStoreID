// ========================================
// lib/services/api_config_service.dart (Updated)
// ========================================
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfigService {
  static const String _googleApiKeyKey = 'google_api_key';
  static const String _openAiApiKeyKey = 'openai_api_key';
  static const String _googleSearchEngineIdKey = 'google_search_engine_id';

  // Google Vision API key (for OCR and image analysis)
  static Future<String?> getGoogleApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_googleApiKeyKey);
  }

  static Future<void> setGoogleApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_googleApiKeyKey, apiKey);
  }

  // OpenAI API key (for AI summary generation)
  static Future<String?> getOpenAiApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_openAiApiKeyKey);
  }

  static Future<void> setOpenAiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_openAiApiKeyKey, apiKey);
  }

  // Google Custom Search Engine ID (for targeted searches)
  static Future<String?> getGoogleSearchEngineId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_googleSearchEngineIdKey);
  }

  static Future<void> setGoogleSearchEngineId(String searchEngineId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_googleSearchEngineIdKey, searchEngineId);
  }

  // Clear all API keys
  static Future<void> clearAllApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_googleApiKeyKey);
    await prefs.remove(_openAiApiKeyKey);
    await prefs.remove(_googleSearchEngineIdKey);
  }

  // Check if all required APIs are configured
  static Future<Map<String, bool>> getApiStatus() async {
    final googleApiKey = await getGoogleApiKey();
    final openAiApiKey = await getOpenAiApiKey();
    final searchEngineId = await getGoogleSearchEngineId();

    return {
      'googleVisionApi': googleApiKey != null && googleApiKey.isNotEmpty,
      'openAiApi': openAiApiKey != null && openAiApiKey.isNotEmpty,
      'googleSearchApi': (googleApiKey != null && googleApiKey.isNotEmpty) &&
          (searchEngineId != null && searchEngineId.isNotEmpty),
      'allConfigured': (googleApiKey != null && googleApiKey.isNotEmpty) &&
          (openAiApiKey != null && openAiApiKey.isNotEmpty) &&
          (searchEngineId != null && searchEngineId.isNotEmpty),
    };
  }

  // Get setup instructions for APIs
  static Map<String, String> getSetupInstructions() {
    return {
      'googleVisionApi': '''
1. Go to Google Cloud Console (console.cloud.google.com)
2. Create a new project or select existing project
3. Enable the Vision API
4. Go to Credentials and create an API Key
5. Restrict the key to Vision API for security
6. Copy the API key and paste it in the app settings
      ''',
      'openAiApi': '''
1. Go to platform.openai.com
2. Sign up or log in to your account
3. Go to API section and create a new API key
4. Copy the key and paste it in the app settings
Note: OpenAI API usage has costs based on usage
      ''',
      'googleSearchApi': '''
1. Go to Google Cloud Console (console.cloud.google.com)
2. Enable the Custom Search API
3. Create a Custom Search Engine at cse.google.com
4. Configure your search engine settings
5. Copy the Search Engine ID (cx parameter)
6. Use the same Google API key from Vision API
Note: Google Search has daily quotas and may have costs
      ''',
    };
  }

  // Test API connections
  static Future<Map<String, dynamic>> testApiConnections() async {
    Map<String, dynamic> results = {};

    // Test Google Vision API
    final googleApiKey = await getGoogleApiKey();
    if (googleApiKey != null && googleApiKey.isNotEmpty) {
      try {
        // Import CloudServices for testing
        // final testResult = await CloudServices.testApiKey(googleApiKey);
        results['googleVisionApi'] = {
          'configured': true,
          'tested': false, // Set to true after implementing test
          'message': 'API key configured (test not implemented yet)'
        };
      } catch (e) {
        results['googleVisionApi'] = {
          'configured': true,
          'tested': false,
          'error': e.toString()
        };
      }
    } else {
      results['googleVisionApi'] = {
        'configured': false,
        'message': 'API key not configured'
      };
    }

    // Test OpenAI API
    final openAiApiKey = await getOpenAiApiKey();
    if (openAiApiKey != null && openAiApiKey.isNotEmpty) {
      results['openAiApi'] = {
        'configured': true,
        'tested': false, // Would need to implement a test call
        'message': 'API key configured'
      };
    } else {
      results['openAiApi'] = {
        'configured': false,
        'message': 'API key not configured'
      };
    }

    // Test Google Search API
    final searchEngineId = await getGoogleSearchEngineId();
    if (googleApiKey != null && googleApiKey.isNotEmpty &&
        searchEngineId != null && searchEngineId.isNotEmpty) {
      results['googleSearchApi'] = {
        'configured': true,
        'tested': false, // Would need to implement a test search
        'message': 'API key and Search Engine ID configured'
      };
    } else {
      results['googleSearchApi'] = {
        'configured': false,
        'message': 'Missing API key or Search Engine ID'
      };
    }

    return results;
  }

  // Get API usage guidelines
  static Map<String, Map<String, dynamic>> getUsageGuidelines() {
    return {
      'googleVisionApi': {
        'freeQuota': '1,000 requests/month',
        'costAfterQuota': '\$1.50 per 1,000 requests',
        'tips': [
          'OCR requests count toward quota',
          'Batch multiple images when possible',
          'Consider image size optimization'
        ]
      },
      'openAiApi': {
        'pricing': 'Pay-per-use (varies by model)',
        'gpt4Cost': '~\$0.03 per 1K tokens',
        'tips': [
          'GPT-3.5 is cheaper than GPT-4',
          'Shorter prompts reduce costs',
          'Set usage limits in OpenAI dashboard'
        ]
      },
      'googleSearchApi': {
        'freeQuota': '100 searches/day',
        'costAfterQuota': '\$5 per 1,000 queries',
        'tips': [
          'Target searches for better results',
          'Cache results when possible',
          'Use specific search terms to reduce queries'
        ]
      }
    };
  }

  // Validate API key format
  static bool validateGoogleApiKey(String apiKey) {
    // Google API keys typically start with AIza and are 39 characters
    return apiKey.startsWith('AIza') && apiKey.length == 39;
  }

  static bool validateOpenAiApiKey(String apiKey) {
    // OpenAI API keys start with sk- and are around 51 characters
    return apiKey.startsWith('sk-') && apiKey.length > 40;
  }

  static bool validateGoogleSearchEngineId(String searchEngineId) {
    // Google Search Engine IDs are typically alphanumeric and around 20+ characters
    return searchEngineId.length > 10 && RegExp(r'^[a-zA-Z0-9:]+$').hasMatch(searchEngineId);
  }
}