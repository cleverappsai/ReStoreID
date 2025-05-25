// ========================================
// lib/screens/settings_screen.dart
// ========================================
import 'package:flutter/material.dart';
import '../services/api_config_service.dart';
import '../services/cloud_services.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _googleApiController = TextEditingController();
  bool _isLoading = true;
  bool _showApiKey = false;
  bool _isTestingApi = false;

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  Future<void> _loadApiKeys() async {
    setState(() => _isLoading = true);
    final googleKey = await ApiConfigService.getGoogleApiKey();
    _googleApiController.text = googleKey ?? '';
    setState(() => _isLoading = false);
  }

  Future<void> _saveGoogleApiKey() async {
    final key = _googleApiController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an API key')),
      );
      return;
    }

    await ApiConfigService.setGoogleApiKey(key);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Google API key saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _testApiKey() async {
    final key = _googleApiController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an API key first')),
      );
      return;
    }

    setState(() => _isTestingApi = true);

    try {
      final result = await CloudServices.testApiKey(key);

      setState(() => _isTestingApi = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                result['valid'] ? Icons.check_circle : Icons.error,
                color: result['valid'] ? Colors.green : Colors.red,
              ),
              SizedBox(width: 8),
              Text(result['valid'] ? 'API Key Valid' : 'API Key Invalid'),
            ],
          ),
          content: Text(result['message']),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isTestingApi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error testing API key: $e')),
      );
    }
  }

  String _maskApiKey(String key) {
    if (key.length <= 8) return key;
    return '${key.substring(0, 4)}${'•' * (key.length - 8)}${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Configuration'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Google Cloud Vision API',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Required for image processing, OCR, and object detection.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),

            // API Key Input
            TextFormField(
              controller: _googleApiController,
              decoration: InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _showApiKey = !_showApiKey;
                        });
                      },
                      tooltip: _showApiKey ? 'Hide API Key' : 'Show API Key',
                    ),
                    IconButton(
                      icon: Icon(Icons.save),
                      onPressed: _saveGoogleApiKey,
                      tooltip: 'Save API Key',
                    ),
                  ],
                ),
              ),
              obscureText: !_showApiKey,
              maxLines: 1,
            ),

            SizedBox(height: 16),

            // Test API Button
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTestingApi ? null : _testApiKey,
                icon: _isTestingApi
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(Icons.play_arrow),
                label: Text(_isTestingApi ? 'Testing...' : 'Test API Key'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            SizedBox(height: 24),

            // Current Status
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _googleApiController.text.isNotEmpty
                              ? Icons.check_circle
                              : Icons.warning,
                          color: _googleApiController.text.isNotEmpty
                              ? Colors.green
                              : Colors.orange,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _googleApiController.text.isNotEmpty
                                ? 'API Key configured: ${_maskApiKey(_googleApiController.text)}'
                                : 'No API key configured',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Setup Instructions
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Setup Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Go to Google Cloud Console\n'
                          '2. Create or select a project\n'
                          '3. Enable the Vision API\n'
                          '4. Create credentials (API Key)\n'
                          '5. Copy and paste the API key above\n'
                          '6. Test the API key to confirm it works',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Could open URL to Google Cloud Console
                      },
                      icon: Icon(Icons.open_in_new),
                      label: Text('Open Google Cloud Console'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _googleApiController.dispose();
    super.dispose();
  }
}