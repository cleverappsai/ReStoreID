// ========================================
// lib/screens/home_screen.dart
// ========================================
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/item_job.dart';
import '../services/storage_service.dart';
import 'job_creation_screen.dart';
import 'job_list_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ItemJob> _recentJobs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentJobs();
  }

  Future<void> _loadRecentJobs() async {
    final jobs = await StorageService.getAllJobs();
    setState(() {
      _recentJobs = jobs.take(3).toList();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resale Item ID',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              Text(
                'Identify and price items quickly',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 32),

              // Recent Jobs Card
              if (_recentJobs.isNotEmpty) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Jobs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        ..._recentJobs.map((job) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(job.description),
                          subtitle: Text(_formatDate(job.createdAt)),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Navigate to job details
                          },
                        )).toList(),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JobListScreen(cameras: widget.cameras),
                              ),
                            );
                          },
                          child: Text('View All Jobs'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],

              // Main Action Buttons
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Start New Item Button
                    Container(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => JobCreationScreen(cameras: widget.cameras),
                            ),
                          ).then((_) => _loadRecentJobs());
                        },
                        icon: Icon(Icons.add_a_photo, size: 28),
                        label: Text(
                          'Start New Item',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // View Jobs Button
                    Container(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => JobListScreen(cameras: widget.cameras),
                            ),
                          ).then((_) => _loadRecentJobs());
                        },
                        icon: Icon(Icons.list, size: 28),
                        label: Text(
                          'View All Jobs',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.blue[600]!, width: 2),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
