import '../entities/course.dart';
import '../entities/payment.dart';

abstract class CourseRepository {
  Future<List<Course>> getActiveCourses();
  Future<String> openTodaySession(String courseId);
  Future<void> markAttendance(String sessionId, String barcode);
  Future<List<Map<String, dynamic>>> getCourseDashboard(String courseId);
  Future<Payment> getStudentPayment(String studentId, String courseId);
  Future<void> deleteSession(String sessionId);
}
