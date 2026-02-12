import '../../domain/entities/course.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/course_repository.dart';
import '../datasources/remote/supabase_datasource.dart';
import '../mappers/course_mapper.dart';
import '../mappers/payment_mapper.dart';

class CourseRepositoryImpl implements CourseRepository {
  final SupabaseDataSource _dataSource;

  CourseRepositoryImpl(this._dataSource);

  @override
  Future<List<Course>> getActiveCourses() async {
    final data = await _dataSource.getActiveCourses();
    return data.map(CourseMapper.fromMap).toList();
  }

  @override
  Future<String> openTodaySession(String courseId) async {
    return await _dataSource.openTodaySession(courseId);
  }

  @override
  Future<void> markAttendance(String sessionId, String barcode) async {
    await _dataSource.markAttendance(sessionId, barcode);
  }

  @override
  Future<List<Map<String, dynamic>>> getCourseDashboard(String courseId) async {
    return await _dataSource.getCourseDashboard(courseId);
  }

  @override
  Future<Payment> getStudentPayment(String studentId, String courseId) async {
    final data = await _dataSource.getEnrollmentPayment(studentId, courseId);
    
    // Get course price
    final courses = await _dataSource.getActiveCourses();
    final course = courses.firstWhere((c) => c['id'] == courseId, orElse: () => {});
    final offeringPrice = (course['price'] is num) ? course['price'] as num : (num.tryParse(course['price'].toString()) ?? 0);
    
    return PaymentMapper.fromMap(data, studentId, courseId, offeringPrice: offeringPrice);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _dataSource.deleteSession(sessionId);
  }
}
