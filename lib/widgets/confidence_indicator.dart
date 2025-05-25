import 'package:flutter/material.dart';

class ConfidenceIndicator extends StatelessWidget {
  final double confidence;
  final String? label;
  final double size;

  const ConfidenceIndicator({
    Key? key,
    required this.confidence,
    this.label,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    String confidenceText;
    IconData icon;

    if (confidence >= 0.8) {
      color = Colors.green;
      confidenceText = 'High';
      icon = Icons.check_circle;
    } else if (confidence >= 0.6) {
      color = Colors.orange;
      confidenceText = 'Medium';
      icon = Icons.warning;
    } else {
      color = Colors.red;
      confidenceText = 'Low';
      icon = Icons.error;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: size,
        ),
        SizedBox(width: 4),
        Text(
          label != null ? '$label: $confidenceText' : confidenceText,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: size * 0.6,
          ),
        ),
        SizedBox(width: 4),
        Text(
          '(${(confidence * 100).toInt()}%)',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: size * 0.5,
          ),
        ),
      ],
    );
  }
}