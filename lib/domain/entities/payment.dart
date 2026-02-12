import 'package:equatable/equatable.dart';

enum PaymentStatus { unpaid, paid, partial, waived }

class Payment extends Equatable {
  final String studentId;
  final String courseId;
  final num offeringPrice;
  final num paidAmount;
  final num remainingAmount;
  final PaymentStatus status;

  const Payment({
    required this.studentId,
    required this.courseId,
    required this.offeringPrice,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
  });

  @override
  List<Object?> get props => [
        studentId,
        courseId,
        offeringPrice,
        paidAmount,
        remainingAmount,
        status,
      ];

  Payment copyWith({
    String? studentId,
    String? courseId,
    num? offeringPrice,
    num? paidAmount,
    num? remainingAmount,
    PaymentStatus? status,
  }) {
    return Payment(
      studentId: studentId ?? this.studentId,
      courseId: courseId ?? this.courseId,
      offeringPrice: offeringPrice ?? this.offeringPrice,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
    );
  }

  String get statusArabic {
    switch (status) {
      case PaymentStatus.paid:
        return 'مدفوع';
      case PaymentStatus.partial:
        return 'دفع جزئي';
      case PaymentStatus.waived:
        return 'معفي';
      case PaymentStatus.unpaid:
        return 'غير مدفوع';
    }
  }

  String formatMoney(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}
