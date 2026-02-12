import '../entities/student.dart';
import '../entities/attendance.dart';

abstract class StudentRepository {
  Future<List<Student>> searchStudents(String query);
  Future<Student?> getStudentByBarcode(String barcode);
  Future<List<Attendance>> getStudentAttendanceHistory(String studentId);
  Future<void> markAttendance(String sessionId, String barcode);
}
