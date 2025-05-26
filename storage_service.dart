// ========================================
// lib/services/storage_service.dart - UPDATED WITH TARGETED SEARCH
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

  // NEW: TARGETED SEARCH SUPPORT METHODS

  /// Update a job with targeted search results
  static Future<void> updateJobWithTargetedSearch(String jobId, TargetedSearchResults results) async {
    final job = await getJob(jobId);
    if (job != null) {
      final updatedJob = job.copyWith(
        targetedSearchResults: results,
        webSearchCompleted: true, // Mark as completed
      );
      await saveJob(updatedJob);
    }
  }

  /// Get all jobs that have targeted search results
  static Future<List<ItemJob>> getJobsWithTargetedSearch() async {
    final allJobs = await getAllJobs();
    return allJobs.where((job) => job.hasTargetedSearchResults).toList();
  }

  /// Get all jobs that need targeted search analysis
  static Future<List<ItemJob>> getJobsPendingTargetedSearch() async {
    final allJobs = await getAllJobs();
    return allJobs.where((job) =>
    !job.hasTargetedSearchResults &&
        job.ocrCompleted && // Only analyze jobs that have OCR completed
        job.images.isNotEmpty
    ).toList();
  }

  /// Get targeted search statistics
  static Future<Map<String, dynamic>> getTargetedSearchStats() async {
    final allJobs = await getAllJobs();
    final analyzedJobs = allJobs.where((job) => job.hasTargetedSearchResults).toList();

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
      'pendingJobs': allJobs.length - analyzedJobs.length,
      'averageConfidence': analyzedJobs.isEmpty ? 0.0 : totalConfidence / analyzedJobs.length,
      'highConfidenceJobs': highConfidenceCount,
      'successRate': allJobs.isEmpty ? 0.0 : (highConfidenceCount / allJobs.length),
    };
  }

  /// Clear targeted search results for a job (for re-analysis)
  static Future<void> clearJobTargetedSearch(String jobId) async {
    final job = await getJob(jobId);
    if (job != null) {
      final updatedJob = job.copyWith(
        targetedSearchResults: null,
        webSearchCompleted: false,
      );
      await saveJob(updatedJob);
    }
  }

  /// Get jobs analyzed within a specific date range
  static Future<List<ItemJob>> getJobsAnalyzedInRange(DateTime startDate, DateTime endDate) async {
    final analyzedJobs = await getJobsWithTargetedSearch();
    return analyzedJobs.where((job) {
      final analysisDate = job.targetedSearchResults!.analysisDate;
      return analysisDate.isAfter(startDate) && analysisDate.isBefore(endDate);
    }).toList();
  }

  /// Search jobs by product name or manufacturer from targeted search results
  static Future<List<ItemJob>> searchJobsByProduct(String query) async {
    final analyzedJobs = await getJobsWithTargetedSearch();
    final lowerQuery = query.toLowerCase();

    return analyzedJobs.where((job) {
      final products = job.targetedSearchResults!.identifiedProducts;
      return products.any((product) =>
      product.manufacturer.toLowerCase().contains(lowerQuery) ||
          product.productName.toLowerCase().contains(lowerQuery) ||
          product.modelNumber.toLowerCase().contains(lowerQuery)
      ) || job.userDescription.toLowerCase().contains(lowerQuery) ||
          job.searchDescription.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Export targeted search data for backup/sharing
  static Future<Map<String, dynamic>> exportTargetedSearchData() async {
    final analyzedJobs = await getJobsWithTargetedSearch();
    return {
      'exportDate': DateTime.now().toIso8601String(),
      'jobCount': analyzedJobs.length,
      'jobs': analyzedJobs.map((job) => {
        'id': job.id,
        'userDescription': job.userDescription,
        'searchDescription': job.searchDescription,
        'targetedSearchResults': job.targetedSearchResults?.toJson(),
        'analysisDate': job.targetedSearchResults?.analysisDate.toIso8601String(),
      }).toList(),
    };
  }

  /// Get jobs that might benefit from re-analysis (old results)
  static Future<List<ItemJob>> getJobsNeedingReanalysis({int daysSinceAnalysis = 30}) async {
    final analyzedJobs = await getJobsWithTargetedSearch();
    final cutoffDate = DateTime.now().subtract(Duration(days: daysSinceAnalysis));

    return analyzedJobs.where((job) {
      final analysisDate = job.targetedSearchResults!.analysisDate;
      return analysisDate.isBefore(cutoffDate);
    }).toList();
  }

  /// Update job with enhanced OCR results for better targeted search
  static Future<void> updateJobOcrForTargetedSearch(String jobId, Map<String, String> enhancedOcrResults) async {
    final job = await getJob(jobId);
    if (job != null) {
      final updatedJob = job.copyWith(
        ocrResults: {...(job.ocrResults ?? {}), ...enhancedOcrResults},
        ocrCompleted: true,
      );
      await saveJob(updatedJob);
    }
  }
}