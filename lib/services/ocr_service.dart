// ========================================
// lib/services/ocr_service.dart
// ========================================
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/item_job.dart';
import 'storage_service.dart';

class OCRService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Process all images in an ItemJob and extract text
  static Future<Map<String, String>> processItemImages(ItemJob job) async {
    final Map<String, String> ocrResults = {};

    try {
      for (int i = 0; i < job.images.length; i++) {
        final imagePath = job.images[i];
        print('🔍 Processing OCR for image: $imagePath');

        try {
          final extractedText = await extractTextFromImage(imagePath);
          ocrResults['image_$i'] = extractedText;
          print('✅ OCR extracted ${extractedText.length} characters from image $i');
        } catch (e) {
          print('❌ OCR failed for image $i: $e');
          ocrResults['image_$i'] = '';
        }
      }

      // Update the job with OCR results
      await _updateJobWithOCR(job.id, ocrResults);

      return ocrResults;

    } catch (e) {
      print('❌ OCR Service error: $e');
      return {};
    }
  }

  /// Extract text from a single image file
  static Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // Combine all text blocks
      final StringBuffer textBuffer = StringBuffer();

      for (TextBlock block in recognizedText.blocks) {
        textBuffer.writeln(block.text);
      }

      final extractedText = textBuffer.toString().trim();
      print('📝 Extracted text: ${extractedText.substring(0, extractedText.length > 100 ? 100 : extractedText.length)}...');

      return extractedText;

    } catch (e) {
      print('❌ Error extracting text from $imagePath: $e');
      return '';
    }
  }

  /// Extract structured data (brands, models, numbers) from text
  static Map<String, List<String>> extractStructuredData(String text) {
    final Map<String, List<String>> structured = {
      'brands': [],
      'models': [],
      'numbers': [],
      'keywords': [],
    };

    if (text.isEmpty) return structured;

    final lines = text.split('\n');

    // Common brand patterns
    final brandPatterns = [
      RegExp(r'\b(Samsung|Apple|Canon|Nikon|Sony|LG|Dell|HP|Lenovo|Asus|Acer)\b', caseSensitive: false),
      RegExp(r'\b(Microsoft|Google|Amazon|Nintendo|Panasonic|Olympus|Fujifilm)\b', caseSensitive: false),
    ];

    // Model number patterns
    final modelPatterns = [
      RegExp(r'\b[A-Z]{2,}\d{3,}\b'), // Like "ABC123", "XYZ4567"
      RegExp(r'\b\d{3,}[A-Z]{1,3}\b'), // Like "123ABC", "456XY"
      RegExp(r'\b[A-Z]\d{2,}-[A-Z0-9]+\b'), // Like "A12-B34C"
    ];

    // Number patterns (prices, measurements, etc.)
    final numberPatterns = [
      RegExp(r'\$\d+\.?\d*'), // Prices like $99.99
      RegExp(r'\b\d+\.?\d*\s*(mm|cm|in|inches|kg|lb|oz|gb|tb)\b', caseSensitive: false), // Measurements
      RegExp(r'\b\d{10,}\b'), // Long numbers (could be model numbers)
    ];

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Extract brands
      for (RegExp pattern in brandPatterns) {
        final matches = pattern.allMatches(line);
        for (Match match in matches) {
          final brand = match.group(0)!;
          if (!structured['brands']!.contains(brand)) {
            structured['brands']!.add(brand);
          }
        }
      }

      // Extract model numbers
      for (RegExp pattern in modelPatterns) {
        final matches = pattern.allMatches(line);
        for (Match match in matches) {
          final model = match.group(0)!;
          if (!structured['models']!.contains(model)) {
            structured['models']!.add(model);
          }
        }
      }

      // Extract numbers
      for (RegExp pattern in numberPatterns) {
        final matches = pattern.allMatches(line);
        for (Match match in matches) {
          final number = match.group(0)!;
          if (!structured['numbers']!.contains(number)) {
            structured['numbers']!.add(number);
          }
        }
      }

      // Extract significant keywords (longer than 3 chars, alphabetic)
      final words = line.split(RegExp(r'\s+'));
      for (String word in words) {
        word = word.replaceAll(RegExp(r'[^\w]'), ''); // Remove punctuation
        if (word.length > 3 && RegExp(r'^[a-zA-Z]+$').hasMatch(word)) {
          if (!structured['keywords']!.contains(word.toLowerCase())) {
            structured['keywords']!.add(word.toLowerCase());
          }
        }
      }
    }

    return structured;
  }

  /// Update job with OCR results and mark as completed
  static Future<void> _updateJobWithOCR(String jobId, Map<String, String> ocrResults) async {
    final job = await StorageService.getJob(jobId);
    if (job != null) {
      // Extract structured data from all OCR text
      final allText = ocrResults.values.join(' ');
      final structuredData = extractStructuredData(allText);

      final updatedJob = job.copyWith(
        ocrResults: ocrResults,
        ocrCompleted: true,
        imageClassification: structuredData, // Store structured data
      );

      await StorageService.saveJob(updatedJob);
      print('✅ Job $jobId updated with OCR results');
    }
  }

  /// Process OCR for a job if not already completed
  static Future<ItemJob?> ensureOCRCompleted(String jobId) async {
    final job = await StorageService.getJob(jobId);
    if (job == null) return null;

    if (!job.ocrCompleted && job.images.isNotEmpty) {
      print('🔄 Starting OCR processing for job: ${job.id}');
      await processItemImages(job);
      // Return updated job
      return await StorageService.getJob(jobId);
    }

    return job;
  }

  /// Get OCR summary for display
  static String getOCRSummary(ItemJob job) {
    if (!job.ocrCompleted || job.ocrResults?.isEmpty == true) {
      return 'OCR not completed';
    }

    final allText = job.ocrResults!.values.join(' ');
    final wordCount = allText.split(RegExp(r'\s+')).length;
    final structured = job.imageClassification;

    final summary = StringBuffer();
    summary.writeln('📄 Text extracted: $wordCount words');

    if (structured != null) {
      if (structured['brands']?.isNotEmpty == true) {
        summary.writeln('🏷️ Brands found: ${structured['brands']!.join(', ')}');
      }
      if (structured['models']?.isNotEmpty == true) {
        summary.writeln('🔢 Models: ${structured['models']!.join(', ')}');
      }
      if (structured['numbers']?.isNotEmpty == true) {
        summary.writeln('💰 Numbers: ${structured['numbers']!.take(3).join(', ')}');
      }
    }

    return summary.toString();
  }

  /// Cleanup resources
  static void dispose() {
    _textRecognizer.close();
  }
}