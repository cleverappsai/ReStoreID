// ========================================
// lib/services/storage_service.dart (Corrected)
// ========================================
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_job.dart';

class StorageService {
  static const String _jobsKey = 'item_jobs';

  static Future<void> saveJob(ItemJob job) async {
    final prefs = await SharedPreferences.getInstance();
    final jobs = await getAllJobs();

    final existingIndex = jobs.indexWhere((j) => j.id == job.id);
    if (existingIndex != -1) {
      jobs[existingIndex] = job;
    } else {
      jobs.add(job);
    }

    final jsonList = jobs.map((job) => job.toJson()).toList();
    await prefs.setString(_jobsKey, jsonEncode(jsonList));
  }

  // For backward compatibility
  static Future<void> updateItem(ItemJob item) async {
    await saveJob(item);
  }

  static Future<List<ItemJob>> getAllJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_jobsKey);

    if (jsonString == null) return [];

    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => ItemJob.fromJson(json)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<ItemJob?> getJob(String id) async {
    final jobs = await getAllJobs();
    try {
      return jobs.firstWhere((job) => job.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteJob(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final jobs = await getAllJobs();
    jobs.removeWhere((job) => job.id == id);

    final jsonList = jobs.map((job) => job.toJson()).toList();
    await prefs.setString(_jobsKey, jsonEncode(jsonList));
  }

  // Get jobs with enhanced analysis results
  static Future<List<ItemJob>> getJobsWithEnhancedAnalysis() async {
    final allJobs = await getAllJobs();
    return allJobs.where((job) =>
    job.analysisResult != null &&
        job.analysisResult!['analysisType'] == 'enhanced_targeted'
    ).toList();
  }

  // Get jobs that need enhanced analysis
  static Future<List<ItemJob>> getJobsNeedingAnalysis() async {
    final allJobs = await getAllJobs();
    return allJobs.where((job) =>
    job.analysisResult == null ||
        job.analysisResult!['analysisType'] != 'enhanced_targeted'
    ).toList();
  }

  // Get analysis statistics
  static Future<Map<String, dynamic>> getAnalysisStatistics() async {
    final allJobs = await getAllJobs();
    final analyzedJobs = allJobs.where((job) =>
    job.analysisResult != null &&
        job.analysisResult!['analysisType'] == 'enhanced_targeted'
    ).toList();

    if (analyzedJobs.isEmpty) {
      return {
        'totalJobs': allJobs.length,
        'analyzedJobs': 0,
        'averageConfidence': 0.0,
        'highConfidenceJobs': 0,
      };
    }

    double totalConfidence = 0.0;
    int highConfidenceCount = 0;

    for (var job in analyzedJobs) {
      if (job.analysisResult != null && job.analysisResult!['overallConfidence'] != null) {
        final confidence = job.analysisResult!['overallConfidence'] as double;
        totalConfidence += confidence;
        if (confidence > 0.7) {
          highConfidenceCount++;
        }
      }
    }

    return {
      'totalJobs': allJobs.length,
      'analyzedJobs': analyzedJobs.length,
      'averageConfidence': totalConfidence / analyzedJobs.length,
      'highConfidenceJobs': highConfidenceCount,
    };
  }

  // Clear all analysis results (for testing/reset)
  static Future<void> clearAllAnalysisResults() async {
    final allJobs = await getAllJobs();

    for (var job in allJobs) {
      final updatedJob = job.copyWith(
        analysisResult: null,
        ocrCompleted: false,
        webSearchCompleted: false,
        pricingCompleted: false,
      );
      await saveJob(updatedJob);
    }
  }

  // Export job data for debugging
  static Future<Map<String, dynamic>> exportJobData(String jobId) async {
    final job = await getJob(jobId);
    if (job == null) {
      return {'error': 'Job not found'};
    }

    return {
      'id': job.id,
      'userDescription': job.userDescription,
      'searchDescription': job.searchDescription,
      'createdAt': job.createdAt.toIso8601String(),
      'completedAt': job.completedAt?.toIso8601String(),
      'analysisResult': job.analysisResult,
      'ocrResults': job.ocrResults,
      'imageClassification': job.imageClassification,
      'measurementsDisplay': job.measurementsDisplay,
      'isCompleted': job.isCompleted,
    };
  }

  // Get recent activity (jobs modified in last N days)
  static Future<List<ItemJob>> getRecentActivity({int days = 7}) async {
    final allJobs = await getAllJobs();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    return allJobs.where((job) {
      final analysisDate = job.completedAt ?? job.createdAt;
      return analysisDate.isAfter(cutoffDate);
    }).toList();
  }
}