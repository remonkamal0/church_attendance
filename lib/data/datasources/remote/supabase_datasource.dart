import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

abstract class SupabaseDataSource {
  Future<List<Map<String, dynamic>>> searchStudents(String query);
  Future<Map<String, dynamic>?> getStudentByBarcode(String barcode);
  Future<List<Map<String, dynamic>>> getStudentAttendance(String studentId);
  Future<void> markAttendance(String sessionId, String barcode);
  Future<List<Map<String, dynamic>>> getActiveCourses();
  Future<String> openTodaySession(String courseId);
  Future<List<Map<String, dynamic>>> getCourseDashboard(String courseId);
  Future<Map<String, dynamic>?> getEnrollmentPayment(String studentId, String courseId);
  Future<void> deleteSession(String sessionId);
}

class SupabaseDataSourceImpl implements SupabaseDataSource {
  final SupabaseClient _client;

  SupabaseDataSourceImpl(this._client);

  @override
  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    final res = await _client
        .from('students')
        .select('id, full_name, barcode_value, photo_url, churches(name), services(name)')
        .or('full_name.ilike.%$query%,barcode_value.eq.$query')
        .limit(20);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getStudentByBarcode(String barcode) async {
    final res = await _client
        .from('students')
        .select('id, full_name, barcode_value, photo_url, churches(name), services(name)')
        .eq('barcode_value', barcode)
        .maybeSingle();

    return res != null ? Map<String, dynamic>.from(res) : null;
  }

  @override
  Future<List<Map<String, dynamic>>> getStudentAttendance(String studentId) async {
    final res = await _client
        .from('session_attendance')
        .select('id, status, scanned_at, notes, course_sessions(session_date, title)')
        .eq('student_id', studentId)
        .order('scanned_at', ascending: false)
        .limit(300);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<void> markAttendance(String sessionId, String barcode) async {
    await _client.rpc('mark_present', params: {
      'p_session_id': sessionId,
      'p_barcode': barcode,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveCourses() async {
    final res = await _client
        .from('course_offerings')
        .select('id, price, courses(title), years(name)')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<String> openTodaySession(String courseId) async {
    final result = await _client.rpc('open_today_session', params: {
      'p_offering_id': courseId,
    });

    return result.toString();
  }

  @override
  Future<List<Map<String, dynamic>>> getCourseDashboard(String courseId) async {
    final res = await _client.rpc(
      'get_course_dashboard',
      params: {'p_offering': courseId},
    );

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> getEnrollmentPayment(String studentId, String courseId) async {
    final res = await _client
        .from('enrollments')
        .select('paid_amount, payment_status')
        .eq('student_id', studentId)
        .eq('course_offering_id', courseId)
        .maybeSingle();

    return res != null ? Map<String, dynamic>.from(res) : null;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    debugPrint('=== Supabase Delete Session ===');
    debugPrint('Session ID: "$sessionId"');
    debugPrint('Session ID type: ${sessionId.runtimeType}');
    
    try {
      final response = await _client
          .from('course_sessions')
          .delete()
          .eq('id', sessionId);
      
      debugPrint('Delete response: $response');
      debugPrint('Delete completed successfully');
    } catch (e) {
      debugPrint('Delete error: $e');
      rethrow;
    }
  }
}
