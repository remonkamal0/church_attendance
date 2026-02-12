import 'package:flutter/material.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/payment.dart';

class DebugStudentInfo extends StatelessWidget {
  final Student student;
  final Payment? payment;

  const DebugStudentInfo({
    super.key,
    required this.student,
    this.payment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DEBUG INFO',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow('ID', student.id),
          _buildInfoRow('Name', student.fullName),
          _buildInfoRow('Church', student.churchName ?? 'NULL'),
          _buildInfoRow('Service', student.serviceName ?? 'NULL'),
          _buildInfoRow('Barcode', student.barcodeValue ?? 'NULL'),
          _buildInfoRow('Photo URL', student.photoUrl ?? 'NULL'),
          if (payment != null) ...[
            _buildInfoRow('Payment Status', payment!.status.name),
            _buildInfoRow('Paid Amount', '${payment!.paidAmount}'),
            _buildInfoRow('Remaining', '${payment!.remainingAmount}'),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
