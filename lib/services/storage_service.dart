// ========================================
// lib/services/storage_service.dart
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
}
