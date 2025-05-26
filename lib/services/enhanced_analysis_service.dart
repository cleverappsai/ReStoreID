// ========================================
// lib/services/enhanced_analysis_service.dart
// ========================================
import 'dart:async';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import '../services/targeted_search_service.dart';

class EnhancedAnalysisService {
  static final Map<String, StreamController<AnalysisProgress>> _progressControllers = {};
  static final Map<String, bool> _cancelRequests = {};

  /// Start targeted search analysis for a job
  static Future<void> startTargetedAnalysis(String jobId) async {
    final progressController = StreamController<AnalysisProgress>.broadcast();
    _progressControllers[jobId] = progressController;
    _cancelRequests[jobId] = false;

    try {
      // Get the job
      final job = await StorageService.getJob(jobId);
      if (job == null) {
        throw Exception('Job not found');
      }

      // Check if already has targeted search results
      if (job.hasTargetedSearchResults) {
        progressController.add(AnalysisProgress(
          step: 'Analysis already completed',
          progress: 1.0,
          isComplete: true,
        ));
        return;
      }

      // Step 1: Verify prerequisites
      progressController.add(AnalysisProgress(
        step: 'Checking prerequisites...',
        progress: 0.1,
      ));

      if (job.images.isEmpty) {
        throw Exception('No images available for analysis');
      }

      if (_cancelRequests[jobId] == true) return;

      // Step 2: Ensure OCR is completed
      if (!job.ocrCompleted) {
        progressController.add(AnalysisProgress(
          step: 'Waiting for OCR completion...',
          progress: 0.2,
        ));

        // Wait for OCR to complete or timeout after 30 seconds
        int attempts = 0;
        while (!job.ocrCompleted && attempts < 30) {
          if (_cancelRequests[jobId] == true) return;

          await Future.delayed(Duration(seconds: 1));
          final updatedJob = await StorageService.getJob(jobId);
          if (updatedJob?.ocrCompleted == true) break;
          attempts++;
        }

        // Re-fetch job to get latest OCR results
        final latestJob = await StorageService.getJob(jobId);
        if (latestJob?.ocrCompleted != true) {
          throw Exception('OCR analysis not completed. Please wait for OCR to finish first.');
        }
      }

      if (_cancelRequests[jobId] == true) return;

      // Step 3: Start targeted search
      progressController.add(AnalysisProgress(
        step: 'Analyzing product information...',
        progress: 0.3,
      ));

      await Future.delayed(Duration(milliseconds: 500)); // Show progress

      if (_cancelRequests[jobId] == true) return;

      // Step 4: Perform targeted search
      progressController.add(AnalysisProgress(
        step: 'Searching for product matches...',
        progress: 0.5,
      ));

      final targetedResults = await TargetedSearchService.performTargetedSearch(job);

      if (_cancelRequests[jobId] == true) return;

      // Step 5: Save results
      progressController.add(AnalysisProgress(
        step: 'Saving analysis results...',
        progress: 0.8,
      ));

      await StorageService.updateJobWithTargetedSearch(jobId, targetedResults);

      if (_cancelRequests[jobId] == true) return;

      // Step 6: Complete
      progressController.add(AnalysisProgress(
        step: 'Analysis complete!',
        progress: 1.0,
        isComplete: true,
        results: targetedResults,
      ));

    } catch (e) {
      progressController.add(AnalysisProgress(
        step: 'Analysis failed',
        progress: 0.0,
        isComplete: true,
        error: e.toString(),
      ));
    } finally {
      // Cleanup
      await Future.delayed(Duration(seconds: 2));
      _progressControllers.remove(jobId);
      _cancelRequests.remove(jobId);
      progressController.close();
    }
  }

  /// Get analysis progress stream for a job
  static Stream<AnalysisProgress>? getAnalysisProgress(String jobId) {
    return _progressControllers[jobId]?.stream;
  }

  /// Cancel analysis for a job
  static void cancelAnalysis(String jobId) {
    _cancelRequests[jobId] = true;
    _progressControllers[jobId]?.add(AnalysisProgress(
      step: 'Analysis cancelled',
      progress: 0.0,
      isComplete: true,
      error: 'Cancelled by user',
    ));
  }

  /// Check if analysis is in progress
  static bool isAnalysisInProgress(String jobId) {
    return _progressControllers.containsKey(jobId);
  }

  /// Re-analyze a job (clear existing results and start fresh)
  static Future<void> reAnalyzeJob(String jobId) async {
    // Cancel any existing analysis
    if (isAnalysisInProgress(jobId)) {
      cancelAnalysis(jobId);
      await Future.delayed(Duration(seconds: 1));
    }

    // Clear existing targeted search results
    await StorageService.clearJobTargetedSearch(jobId);

    // Start new analysis
    await startTargetedAnalysis(jobId);
  }

  /// Get analysis statistics for all jobs
  static Future<Map<String, dynamic>> getAnalysisStatistics() async {
    return await StorageService.getTargetedSearchStats();
  }

  /// Get jobs that need analysis
  static Future<List<ItemJob>> getJobsPendingAnalysis() async {
    return await StorageService.getJobsPendingTargetedSearch();
  }

  /// Bulk analyze multiple jobs
  static Future<void> bulkAnalyzeJobs(List<String> jobIds, {
    Function(String jobId, String status)? onJobUpdate,
  }) async {
    for (final jobId in jobIds) {
      try {
        onJobUpdate?.call(jobId, 'Starting analysis...');

        // Check if job still needs analysis
        final job = await StorageService.getJob(jobId);
        if (job?.hasTargetedSearchResults == true) {
          onJobUpdate?.call(jobId, 'Already analyzed');
          continue;
        }

        await startTargetedAnalysis(jobId);

        // Wait for completion
        final progressStream = getAnalysisProgress(jobId);
        if (progressStream != null) {
          await for (final progress in progressStream) {
            onJobUpdate?.call(jobId, progress.step);
            if (progress.isComplete) break;
          }
        }

        onJobUpdate?.call(jobId, 'Complete');

        // Small delay between jobs to prevent API rate limiting
        await Future.delayed(Duration(seconds: 2));

      } catch (e) {
        onJobUpdate?.call(jobId, 'Error: ${e.toString()}');
      }
    }
  }

  /// Enhanced analysis with additional context
  static Future<TargetedSearchResults> performEnhancedAnalysis(
      ItemJob job, {
        Map<String, dynamic>? additionalContext,
      }) async {
    // Add any additional context to the job for analysis
    final enhancedJob = job.copyWith(
      searchDescription: job.searchDescription.isEmpty
          ? (additionalContext?['userGuidance'] ?? job.userDescription)
          : job.searchDescription,
    );

    return await TargetedSearchService.performTargetedSearch(enhancedJob);
  }

  /// Get analysis confidence insights
  static Future<Map<String, dynamic>> getConfidenceInsights() async {
    final stats = await getAnalysisStatistics();
    final analyzedJobs = await StorageService.getJobsWithTargetedSearch();

    final confidenceDistribution = <String, int>{
      'Very High (90-100%)': 0,
      'High (80-89%)': 0,
      'Medium (60-79%)': 0,
      'Low (40-59%)': 0,
      'Very Low (0-39%)': 0,
    };

    for (final job in analyzedJobs) {
      final avgConfidence = job.targetedSearchResults!.averageConfidence;
      if (avgConfidence >= 0.9) {
        confidenceDistribution['Very High (90-100%)'] =
            (confidenceDistribution['Very High (90-100%)'] ?? 0) + 1;
      } else if (avgConfidence >= 0.8) {
        confidenceDistribution['High (80-89%)'] =
            (confidenceDistribution['High (80-89%)'] ?? 0) + 1;
      } else if (avgConfidence >= 0.6) {
        confidenceDistribution['Medium (60-79%)'] =
            (confidenceDistribution['Medium (60-79%)'] ?? 0) + 1;
      } else if (avgConfidence >= 0.4) {
        confidenceDistribution['Low (40-59%)'] =
            (confidenceDistribution['Low (40-59%)'] ?? 0) + 1;
      } else {
        confidenceDistribution['Very Low (0-39%)'] =
            (confidenceDistribution['Very Low (0-39%)'] ?? 0) + 1;
      }
    }

    return {
      'totalAnalyzed': analyzedJobs.length,
      'averageConfidence': stats['averageConfidence'],
      'successRate': stats['successRate'],
      'confidenceDistribution': confidenceDistribution,
      'recommendations': _generateRecommendations(stats, confidenceDistribution),
    };
  }

  /// Generate recommendations based on analysis patterns
  static List<String> _generateRecommendations(
      Map<String, dynamic> stats,
      Map<String, int> confidenceDistribution,
      ) {
    final recommendations = <String>[];
    final successRate = stats['successRate'] as double;
    final avgConfidence = stats['averageConfidence'] as double;

    if (successRate < 0.6) {
      recommendations.add('Consider adding more detailed descriptions to improve product identification');
    }

    if (avgConfidence < 0.7) {
      recommendations.add('Include brand names and model numbers in your photos for better results');
    }

    final lowConfidenceCount = (confidenceDistribution['Low (40-59%)'] ?? 0) +
        (confidenceDistribution['Very Low (0-39%)'] ?? 0);

    if (lowConfidenceCount > 0) {
      recommendations.add('$lowConfidenceCount items have low confidence - consider re-photographing with clearer text visibility');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Your analysis results are performing well! Keep up the good photography practices.');
    }

    return recommendations;
  }

  /// Analyze specific aspects of a job for debugging
  static Future<Map<String, dynamic>> analyzeJobReadiness(String jobId) async {
    final job = await StorageService.getJob(jobId);
    if (job == null) {
      return {'error': 'Job not found'};
    }

    return {
      'jobId': jobId,
      'hasImages': job.images.isNotEmpty,
      'imageCount': job.images.length,
      'ocrCompleted': job.ocrCompleted,
      'ocrTextCount': job.ocrResults?.length ?? 0,
      'hasBarcodes': job.barcodes?.isNotEmpty ?? false,
      'barcodeCount': job.barcodes?.length ?? 0,
      'hasTargetedResults': job.hasTargetedSearchResults,
      'readinessScore': _calculateReadinessScore(job),
      'recommendations': _getReadinessRecommendations(job),
    };
  }

  /// Calculate how ready a job is for analysis
  static double _calculateReadinessScore(ItemJob job) {
    double score = 0.0;

    if (job.images.isNotEmpty) score += 0.3;
    if (job.ocrCompleted) score += 0.3;
    if (job.ocrResults?.isNotEmpty == true) score += 0.2;
    if (job.userDescription.isNotEmpty) score += 0.1;
    if (job.barcodes?.isNotEmpty == true) score += 0.1;

    return score;
  }

  /// Get recommendations for improving analysis readiness
  static List<String> _getReadinessRecommendations(ItemJob job) {
    final recommendations = <String>[];

    if (job.images.isEmpty) {
      recommendations.add('Take photos of the item');
    }

    if (!job.ocrCompleted) {
      recommendations.add('Wait for text recognition to complete');
    }

    if (job.userDescription.isEmpty) {
      recommendations.add('Add a description of the item');
    }

    if (job.ocrResults?.isEmpty == true) {
      recommendations.add('Ensure photos contain visible text or labels');
    }

    return recommendations;
  }

  /// Get analysis performance metrics
  static Future<Map<String, dynamic>> getPerformanceMetrics() async {
    final allJobs = await StorageService.getAllJobs();
    final analyzedJobs = await StorageService.getJobsWithTargetedSearch();

    if (analyzedJobs.isEmpty) {
      return {
        'totalJobs': allJobs.length,
        'analyzedJobs': 0,
        'analysisRate': 0.0,
        'averageConfidence': 0.0,
        'highConfidenceRate': 0.0,
      };
    }

    double totalConfidence = 0.0;
    int highConfidenceCount = 0;

    for (final job in analyzedJobs) {
      if (job.targetedSearchResults != null) {
        totalConfidence += job.targetedSearchResults!.averageConfidence;
        if (job.hasHighConfidenceProducts) {
          highConfidenceCount++;
        }
      }
    }

    return {
      'totalJobs': allJobs.length,
      'analyzedJobs': analyzedJobs.length,
      'analysisRate': analyzedJobs.length / allJobs.length,
      'averageConfidence': totalConfidence / analyzedJobs.length,
      'highConfidenceRate': highConfidenceCount / analyzedJobs.length,
      'manufacturerSourcesAvg': analyzedJobs.isEmpty ? 0.0 :
      analyzedJobs.map((j) => j.targetedSearchResults!.manufacturerSourcesCount)
          .reduce((a, b) => a + b) / analyzedJobs.length,
    };
  }
}

/// Progress tracking for analysis operations
class AnalysisProgress {
  final String step;
  final double progress;
  final bool isComplete;
  final String? error;
  final TargetedSearchResults? results;

  AnalysisProgress({
    required this.step,
    required this.progress,
    this.isComplete = false,
    this.error,
    this.results,
  });

  bool get hasError => error != null;
  bool get isSuccessful => isComplete && !hasError;

  @override
  String toString() {
    return 'AnalysisProgress(step: $step, progress: $progress, isComplete: $isComplete, hasError: $hasError)';
  }
}