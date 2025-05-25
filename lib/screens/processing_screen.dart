// ========================================
// lib/screens/processing_screen.dart
// ========================================
import 'package:flutter/material.dart';
import '../models/item_job.dart';
import '../services/analysis_service.dart';
import '../services/storage_service.dart';
import 'results_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final ItemJob job;

  const ProcessingScreen({Key? key, required this.job}) : super(key: key);

  @override
  _ProcessingScreenState createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  String _currentStep = 'Initializing...';
  double _progress = 0.0;
  bool _isCompleted = false;
  bool _hasError = false;

  final List<String> _steps = [
    'Initializing analysis...',
    'Processing images...',
    'Extracting features...',
    'Searching databases...',
    'Analyzing market data...',
    'Generating report...',
    'Finalizing results...',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.repeat();

    _startProcessing();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startProcessing() async {
    try {
      // Save initial job
      await StorageService.saveJob(widget.job);

      // Simulate processing steps
      for (int i = 0; i < _steps.length; i++) {
        if (mounted) {
          setState(() {
            _currentStep = _steps[i];
            _progress = (i + 1) / _steps.length;
          });
        }
        await Future.delayed(Duration(milliseconds: 800));
      }

      // Perform actual analysis
      final result = await AnalysisService.analyzeItem(widget.job);

      // Update job with results
      final updatedJob = ItemJob(
        id: widget.job.id,
        description: widget.job.description,
        imagePaths: widget.job.imagePaths,
        createdAt: widget.job.createdAt,
        completedAt: DateTime.now(),
        analysisResult: result,
      );

      await StorageService.saveJob(updatedJob);

      if (mounted) {
        setState(() {
          _isCompleted = true;
          _currentStep = 'Analysis complete!';
          _progress = 1.0;
        });

        _animationController.stop();

        // Navigate to results after a short delay
        await Future.delayed(Duration(seconds: 1));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResultsScreen(job: updatedJob),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _currentStep = 'Error occurred: $e';
        });
        _animationController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Processing Animation
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue[400]!,
                          Colors.blue[600]!,
                        ],
                        stops: [_animation.value - 0.3, _animation.value],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _isCompleted
                            ? Icons.check
                            : _hasError
                            ? Icons.error
                            : Icons.search,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 32),

              // Title
              Text(
                _isCompleted
                    ? 'Analysis Complete!'
                    : _hasError
                    ? 'Processing Error'
                    : 'Analyzing Item...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 16),

              // Current Step
              Text(
                _currentStep,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 32),

              // Progress Indicator
              if (!_hasError) ...[
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                Text(
                  '${(_progress * 100).toInt()}% Complete',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],

              SizedBox(height: 48),

              // Job Info Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Processing Job',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text('Description: ${widget.job.description}'),
                      SizedBox(height: 8),
                      Text('Images: ${widget.job.imagePaths.length}'),
                    ],
                  ),
                ),
              ),

              if (_hasError) ...[
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
