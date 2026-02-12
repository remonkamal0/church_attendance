import '../../domain/entities/attendance.dart';

class AttendanceMapper {
  static Attendance fromMap(Map<String, dynamic> map) {
    final statusStr = (map['status'] ?? 'absent').toString();
    AttendanceStatus status;
    
    switch (statusStr) {
      case 'present':
        status = AttendanceStatus.present;
        break;
      case 'late':
        status = AttendanceStatus.late;
        break;
      case 'excused':
        status = AttendanceStatus.excused;
        break;
      default:
        status = AttendanceStatus.absent;
    }

    final sessionData = map['course_sessions'] as Map<String, dynamic>? ?? {};
    final sessionTitle = (sessionData['title'] ?? '').toString();
    final sessionDate = (sessionData['session_date'] ?? '').toString();
    
    final scannedAtStr = map['scanned_at']?.toString();
    DateTime scannedAt = DateTime.now();
    if (scannedAtStr != null && scannedAtStr.isNotEmpty) {
      scannedAt = DateTime.tryParse(scannedAtStr) ?? DateTime.now();
    }

    return Attendance(
      id: map['id'] as String,
      studentId: '', // This should come from the context
      sessionId: '', // This should come from the context
      status: status,
      scannedAt: scannedAt,
      notes: map['notes']?.toString(),
      sessionTitle: sessionTitle,
      sessionDate: sessionDate,
    );
  }

  static Map<String, dynamic> toMap(Attendance attendance) {
    return {
      'id': attendance.id,
      'student_id': attendance.studentId,
      'session_id': attendance.sessionId,
      'status': attendance.status.name,
      'scanned_at': attendance.scannedAt.toIso8601String(),
      'notes': attendance.notes,
    };
  }
}
