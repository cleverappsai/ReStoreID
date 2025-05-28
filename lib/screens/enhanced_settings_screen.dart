// ========================================
// lib/screens/enhanced_settings_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_config_service.dart';

class EnhancedSettingsScreen extends StatefulWidget {
  @override
  _EnhancedSettingsScreenState createState() => _EnhancedSettingsScreenState();
}

class _EnhancedSettingsScreenState extends State<EnhancedSettingsScreen> {
  final _googleApiKeyController = TextEditingController();
  final _openAiApiKeyController = TextEditingController();
  final _searchEngineIdController = TextEditingController();

  bool _googleApiKeyVisible = false;
  bool _openAiApiKeyVisible = false;
  bool _searchEngineIdVisible = false;

  bool _isLoading = false;
  bool _isTesting = false;
  Map<String, bool> _apiStatus = {};
  Map<String, dynamic> _testResults = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _checkApiStatus();
  }

  Future<void> _loadCurrentSettings() async {
    final googleApiKey = await ApiConfigService.getGoogleApiKey();
    final openAiApiKey = await ApiConfigService.getOpenAiApiKey();
    final searchEngineId = await ApiConfigService.getGoogleSearchEngineId();

    setState(() {
      _googleApiKeyController.text = googleApiKey ?? '';
      _openAiApiKeyController.text = openAiApiKey ?? '';
      _searchEngineIdController.text = searchEngineId ?? '';
    });
  }

  Future<void> _checkApiStatus() async {
    final status = await ApiConfigService.getApiStatus();
    setState(() {
      _apiStatus = status;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ApiConfigService.setGoogleApiKey(_googleApiKeyController.text.trim());
      await ApiConfigService.setOpenAiApiKey(_openAiApiKeyController.text.trim());
      await ApiConfigService.setGoogleSearchEngineId(_searchEngineIdController.text.trim());

      await _checkApiStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Return true to indicate settings were saved
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testApiConnections() async {
    setState(() {
      _isTesting = true;
      _testResults = {};
    });

    try {
      final results = await ApiConfigService.testApiConnections();
      setState(() {
        _testResults = results;
      });

      // Show test results dialog
      _showTestResultsDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error testing APIs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  void _showTestResultsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🧪 API Test Results'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTestResultItem('Google Vision API', _testResults['googleVisionApi']),
              SizedBox(height: 12),
              _buildTestResultItem('OpenAI API', _testResults['openAiApi']),
              SizedBox(height: 12),
              _buildTestResultItem('Google Search API', _testResults['googleSearchApi']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultItem(String apiName, Map<String, dynamic>? result) {
    if (result == null) {
      return Row(
        children: [
          Icon(Icons.help, color: Colors.grey),
          SizedBox(width: 8),
          Text('$apiName: No data'),
        ],
      );
    }

    final isConfigured = result['configured'] ?? false;
    final message = result['message'] ?? 'Unknown status';
    final hasError = result['error'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isConfigured
                  ? (hasError ? Icons.warning : Icons.check_circle)
                  : Icons.error,
              color: isConfigured
                  ? (hasError ? Colors.orange : Colors.green)
                  : Colors.red,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '$apiName:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(left: 32),
          child: Text(
            message,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(left: 32),
            child: Text(
              'Error: ${result['error']}',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildApiKeyField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggleVisibility,
                  tooltip: isVisible ? 'Hide key' : 'Show key',
                ),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: controller.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('📋 Copied to clipboard')),
                    );
                  },
                  tooltip: 'Copy to clipboard',
                ),
              ],
            ),
          ),
          maxLines: 1,
        ),
        SizedBox(height: 4),
        Text(
          _getKeyValidationStatus(controller.text, validator),
          style: TextStyle(
            fontSize: 12,
            color: _getKeyValidationColor(controller.text, validator),
          ),
        ),
      ],
    );
  }

  String _getKeyValidationStatus(String value, String? Function(String?)? validator) {
    if (value.isEmpty) return 'Not configured';
    if (validator != null) {
      final error = validator(value);
      if (error != null) return error;
    }
    return '✅ Valid format';
  }

  Color _getKeyValidationColor(String value, String? Function(String?)? validator) {
    if (value.isEmpty) return Colors.grey;
    if (validator != null) {
      final error = validator(value);
      if (error != null) return Colors.red;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🔧 Enhanced Settings'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          if (!_isTesting)
            IconButton(
              icon: Icon(Icons.science),
              onPressed: _testApiConnections,
              tooltip: 'Test API Connections',
            ),
          if (_isTesting)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // API Status Summary
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (_apiStatus['allConfigured'] ?? false)
                      ? Colors.green[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_apiStatus['allConfigured'] ?? false)
                        ? Colors.green[300]!
                        : Colors.orange[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (_apiStatus['allConfigured'] ?? false)
                              ? Icons.check_circle
                              : Icons.warning,
                          color: (_apiStatus['allConfigured'] ?? false)
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                        SizedBox(width: 8),
                        Text(
                          (_apiStatus['allConfigured'] ?? false)
                              ? 'All APIs Configured'
                              : 'API Configuration Needed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: (_apiStatus['allConfigured'] ?? false)
                                ? Colors.green[800]
                                : Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Google Vision: ${(_apiStatus['googleVisionApi'] ?? false) ? "✅" : "❌"}',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      'OpenAI API: ${(_apiStatus['openAiApi'] ?? false) ? "✅" : "❌"}',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Google Search: ${(_apiStatus['googleSearchApi'] ?? false) ? "✅" : "❌"}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Google API Key
              _buildApiKeyField(
                label: '🔍 Google API Key',
                hint: 'AIzaSyC...',
                controller: _googleApiKeyController,
                isVisible: _googleApiKeyVisible,
                onToggleVisibility: () {
                  setState(() {
                    _googleApiKeyVisible = !_googleApiKeyVisible;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required for Vision & Search APIs';
                  if (!ApiConfigService.validateGoogleApiKey(value)) {
                    return 'Invalid format (should start with AIza and be 39 chars)';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // OpenAI API Key
              _buildApiKeyField(
                label: '🤖 OpenAI API Key',
                hint: 'sk-...',
                controller: _openAiApiKeyController,
                isVisible: _openAiApiKeyVisible,
                onToggleVisibility: () {
                  setState(() {
                    _openAiApiKeyVisible = !_openAiApiKeyVisible;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required for AI product identification';
                  if (!ApiConfigService.validateOpenAiApiKey(value)) {
                    return 'Invalid format (should start with sk- and be 40+ chars)';
                  }
                  return null;
                },
              ),

              SizedBox(height: 20),

              // Search Engine ID
              _buildApiKeyField(
                label: '🔎 Google Search Engine ID',
                hint: 'abc123...',
                controller: _searchEngineIdController,
                isVisible: _searchEngineIdVisible,
                onToggleVisibility: () {
                  setState(() {
                    _searchEngineIdVisible = !_searchEngineIdVisible;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required for product searches';
                  if (!ApiConfigService.validateGoogleSearchEngineId(value)) {
                    return 'Invalid format (should be 10+ alphanumeric chars)';
                  }
                  return null;
                },
              ),

              SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testApiConnections,
                      icon: _isTesting
                          ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Icon(Icons.science),
                      label: Text(_isTesting ? 'Testing...' : 'Test APIs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveSettings,
                      icon: _isLoading
                          ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Icon(Icons.save),
                      label: Text(_isLoading ? 'Saving...' : 'Save Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),

              // Setup Instructions Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showSetupInstructions,
                  icon: Icon(Icons.help_outline),
                  label: Text('Setup Instructions'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetupInstructions() {
    final instructions = ApiConfigService.getSetupInstructions();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📖 API Setup Instructions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInstructionSection('Google Vision API', instructions['googleVisionApi']!),
              SizedBox(height: 16),
              _buildInstructionSection('OpenAI API', instructions['openAiApi']!),
              SizedBox(height: 16),
              _buildInstructionSection('Google Search API', instructions['googleSearchApi']!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionSection(String title, String instructions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          instructions,
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _googleApiKeyController.dispose();
    _openAiApiKeyController.dispose();
    _searchEngineIdController.dispose();
    super.dispose();
  }
}