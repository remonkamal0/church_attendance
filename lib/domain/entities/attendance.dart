import 'package:equatable/equatable.dart';

enum AttendanceStatus { present, absent, late, excused }

class Attendance extends Equatable {
  final String id;
  final String studentId;
  final String sessionId;
  final AttendanceStatus status;
  final DateTime scannedAt;
  final String? notes;
  final String sessionTitle;
  final String sessionDate;

  const Attendance({
    required this.id,
    required this.studentId,
    required this.sessionId,
    required this.status,
    required this.scannedAt,
    this.notes,
    required this.sessionTitle,
    required this.sessionDate,
  });

  @override
  List<Object?> get props => [
        id,
        studentId,
        sessionId,
        status,
        scannedAt,
        notes,
        sessionTitle,
        sessionDate,
      ];

  Attendance copyWith({
    String? id,
    String? studentId,
    String? sessionId,
    AttendanceStatus? status,
    DateTime? scannedAt,
    String? notes,
    String? sessionTitle,
    String? sessionDate,
  }) {
    return Attendance(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      sessionId: sessionId ?? this.sessionId,
      status: status ?? this.status,
      scannedAt: scannedAt ?? this.scannedAt,
      notes: notes ?? this.notes,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      sessionDate: sessionDate ?? this.sessionDate,
    );
  }

  String get statusArabic {
    switch (status) {
      case AttendanceStatus.present:
        return 'حاضر';
      case AttendanceStatus.late:
        return 'متأخر';
      case AttendanceStatus.excused:
        return 'بعذر';
      case AttendanceStatus.absent:
        return 'غائب';
    }
  }
}
