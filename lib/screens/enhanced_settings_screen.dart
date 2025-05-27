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

  Map<String, bool> _apiStatus = {};
  bool _isLoading = true;
  bool _showApiKeys = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);

    final googleApiKey = await ApiConfigService.getGoogleApiKey();
    final openAiApiKey = await ApiConfigService.getOpenAiApiKey();
    final searchEngineId = await ApiConfigService.getGoogleSearchEngineId();

    _googleApiKeyController.text = googleApiKey ?? '';
    _openAiApiKeyController.text = openAiApiKey ?? '';
    _searchEngineIdController.text = searchEngineId ?? '';

    final status = await ApiConfigService.getApiStatus();

    setState(() {
      _apiStatus = status;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      await ApiConfigService.setGoogleApiKey(_googleApiKeyController.text.trim());
      await ApiConfigService.setOpenAiApiKey(_openAiApiKeyController.text.trim());
      await ApiConfigService.setGoogleSearchEngineId(_searchEngineIdController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadCurrentSettings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enhanced Analysis Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _isLoading ? null : _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(),
            SizedBox(height: 16),
            _buildApiStatusCard(),
            SizedBox(height: 16),
            _buildApiConfigurationCard(),
            SizedBox(height: 16),
            _buildUsageGuidelinesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Enhanced Analysis System',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'The enhanced analysis system uses targeted searches to find official product documentation, specifications, and pricing data. This provides much more accurate and comprehensive results than basic web scraping.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. OCR extracts manufacturer + model from your images'),
                  Text('2. Targeted searches find official datasheets and manuals'),
                  Text('3. Content is scraped from high-value sources'),
                  Text('4. AI generates comprehensive product summaries'),
                  Text('5. Pricing data is collected from multiple retailers'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiStatusCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Status',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 12),
            _buildStatusRow(
              'Google Vision API (OCR)',
              _apiStatus['googleVisionApi'] ?? false,
              'Required for text extraction from images',
            ),
            _buildStatusRow(
              'OpenAI API (AI Summaries)',
              _apiStatus['openAiApi'] ?? false,
              'Optional: Enables AI-generated summaries',
            ),
            _buildStatusRow(
              'Google Search API',
              _apiStatus['googleSearchApi'] ?? false,
              'Required for targeted product searches',
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _apiStatus['allConfigured'] == true
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _apiStatus['allConfigured'] == true
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _apiStatus['allConfigured'] == true
                        ? Icons.check_circle
                        : Icons.warning,
                    color: _apiStatus['allConfigured'] == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _apiStatus['allConfigured'] == true
                          ? 'All APIs configured! Enhanced analysis is ready.'
                          : 'Configure missing APIs to enable enhanced analysis.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String title, bool configured, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            configured ? Icons.check_circle : Icons.radio_button_unchecked,
            color: configured ? Colors.green : Colors.grey,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiConfigurationCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'API Configuration',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_showApiKeys ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showApiKeys = !_showApiKeys),
                      tooltip: _showApiKeys ? 'Hide API keys' : 'Show API keys',
                    ),
                    IconButton(
                      icon: Icon(Icons.info_outline),
                      onPressed: _showSetupInstructions,
                      tooltip: 'Setup instructions',
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),

            // Google API Key
            _buildApiKeyField(
              controller: _googleApiKeyController,
              label: 'Google API Key',
              hint: 'AIza...',
              validator: ApiConfigService.validateGoogleApiKey,
              description: 'Used for Vision API (OCR) and Search API',
            ),

            SizedBox(height: 16),

            // OpenAI API Key
            _buildApiKeyField(
              controller: _openAiApiKeyController,
              label: 'OpenAI API Key (Optional)',
              hint: 'sk-...',
              validator: ApiConfigService.validateOpenAiApiKey,
              description: 'Enables AI-generated summaries (has usage costs)',
            ),

            SizedBox(height: 16),

            // Google Search Engine ID
            _buildApiKeyField(
              controller: _searchEngineIdController,
              label: 'Google Search Engine ID',
              hint: 'Custom Search Engine ID',
              validator: ApiConfigService.validateGoogleSearchEngineId,
              description: 'Custom Search Engine for targeted searches',
            ),

            SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveSettings,
              icon: Icon(Icons.save),
              label: Text('Save Configuration'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool Function(String) validator,
    required String description,
  }) {
    final isValid = controller.text.isEmpty || validator(controller.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: !_showApiKeys,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(),
            suffixIcon: controller.text.isNotEmpty
                ? Icon(
              isValid ? Icons.check_circle : Icons.error,
              color: isValid ? Colors.green : Colors.red,
            )
                : null,
            errorText: !isValid ? 'Invalid format' : null,
          ),
          onChanged: (value) => setState(() {}),
        ),
        SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildUsageGuidelinesCard() {
    final guidelines = ApiConfigService.getUsageGuidelines();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Guidelines & Costs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 12),

            // Google Vision API
            _buildUsageSection(
              'Google Vision API',
              guidelines['googleVisionApi']!,
              Icons.visibility,
              Colors.blue,
            ),

            SizedBox(height: 12),

            // OpenAI API
            _buildUsageSection(
              'OpenAI API',
              guidelines['openAiApi']!,
              Icons.psychology,
              Colors.green,
            ),

            SizedBox(height: 12),

            // Google Search API
            _buildUsageSection(
              'Google Search API',
              guidelines['googleSearchApi']!,
              Icons.search,
              Colors.orange,
            ),

            SizedBox(height: 16),

            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.amber.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'These APIs have usage limits and costs. Monitor your usage in the respective dashboards to avoid unexpected charges.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageSection(
      String title,
      Map<String, dynamic> guidelines,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          if (guidelines['freeQuota'] != null)
            Text('Free quota: ${guidelines['freeQuota']}'),

          if (guidelines['costAfterQuota'] != null)
            Text('Cost after quota: ${guidelines['costAfterQuota']}'),

          if (guidelines['pricing'] != null)
            Text('Pricing: ${guidelines['pricing']}'),

          if (guidelines['gpt4Cost'] != null)
            Text('GPT-4 cost: ${guidelines['gpt4Cost']}'),

          if (guidelines['tips'] != null) ...[
            SizedBox(height: 8),
            Text(
              'Tips:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            ...List<String>.from(guidelines['tips']).map(
                  (tip) => Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Text('• $tip', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSetupInstructions() {
    final instructions = ApiConfigService.getSetupInstructions();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('API Setup Instructions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInstructionSection(
                'Google Vision & Search APIs',
                instructions['googleVisionApi']!,
              ),
              SizedBox(height: 16),
              _buildInstructionSection(
                'Google Custom Search Engine',
                instructions['googleSearchApi']!,
              ),
              SizedBox(height: 16),
              _buildInstructionSection(
                'OpenAI API (Optional)',
                instructions['openAiApi']!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'Google Cloud Console: https://console.cloud.google.com\n'
                    'Google Custom Search: https://cse.google.com\n'
                    'OpenAI Platform: https://platform.openai.com',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Links copied to clipboard')),
              );
            },
            child: Text('Copy Links'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            instructions.trim(),
            style: TextStyle(fontSize: 13),
          ),
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