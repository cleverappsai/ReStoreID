// ========================================
// lib/screens/job_list_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import 'results_screen.dart';

class JobListScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const JobListScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  List<ItemJob> _jobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
    });

    final jobs = await StorageService.getAllJobs();
    setState(() {
      _jobs = jobs;
      _isLoading = false;
    });
  }

  Future<void> _deleteJob(String jobId) async {
    await StorageService.deleteJob(jobId);
    _loadJobs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Job deleted')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
        title: Text('All Jobs'),
    backgroundColor: Colors.blue[600],
    foregroundColor: Colors.white,
    ),
    body: _isLoading
    ? Center(child: CircularProgressIndicator())
        : _jobs.isEmpty
    ? Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(
    Icons.work_outline,
    size: 64,
    color: Colors.grey[400],
    ),
    SizedBox(height: 16),
    Text(
    'No jobs yet',
    style: TextStyle(
    fontSize: 20,
    color: Colors.grey[600],
    ),
    onTap: job.analysisResult != null
    ? () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => ResultsScreen(job: job),
    ),
    );
    }
    : null,
    ),
    );
  },
  ),
  );
}
}