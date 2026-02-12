import '../../domain/entities/payment.dart';

class PaymentMapper {
  static Payment fromMap(Map<String, dynamic>? map, String studentId, String courseId, {num offeringPrice = 0}) {
    if (map == null) {
      return Payment(
        studentId: studentId,
        courseId: courseId,
        offeringPrice: offeringPrice,
        paidAmount: 0,
        remainingAmount: offeringPrice,
        status: PaymentStatus.unpaid,
      );
    }

    final rawPaid = map['paid_amount'];
    final paid = (rawPaid is num) ? rawPaid : (num.tryParse(rawPaid.toString()) ?? 0);

    final statusStr = (map['payment_status'] ?? 'unpaid').toString();
    PaymentStatus status;
    
    switch (statusStr) {
      case 'paid':
        status = PaymentStatus.paid;
        break;
      case 'partial':
        status = PaymentStatus.partial;
        break;
      case 'waived':
        status = PaymentStatus.waived;
        break;
      default:
        status = PaymentStatus.unpaid;
    }

    final remaining = (offeringPrice - paid) < 0 ? 0 : (offeringPrice - paid);

    return Payment(
      studentId: studentId,
      courseId: courseId,
      offeringPrice: offeringPrice,
      paidAmount: paid,
      remainingAmount: remaining,
      status: status,
    );
  }

  static Map<String, dynamic> toMap(Payment payment) {
    return {
      'student_id': payment.studentId,
      'course_id': payment.courseId,
      'offering_price': payment.offeringPrice,
      'paid_amount': payment.paidAmount,
      'remaining_amount': payment.remainingAmount,
      'payment_status': payment.status.name,
    };
  }
}
