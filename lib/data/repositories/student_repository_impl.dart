import '../../domain/entities/student.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/repositories/student_repository.dart';
import '../datasources/remote/supabase_datasource.dart';
import '../mappers/student_mapper.dart';
import '../mappers/attendance_mapper.dart';

class StudentRepositoryImpl implements StudentRepository {
  final SupabaseDataSource _dataSource;

  StudentRepositoryImpl(this._dataSource);

  @override
  Future<List<Student>> searchStudents(String query) async {
    final data = await _dataSource.searchStudents(query);
    return data.map(StudentMapper.fromMap).toList();
  }

  @override
  Future<Student?> getStudentByBarcode(String barcode) async {
    final data = await _dataSource.getStudentByBarcode(barcode);
    return data != null ? StudentMapper.fromMap(data) : null;
  }

  @override
  Future<List<Attendance>> getStudentAttendanceHistory(String studentId) async {
    final data = await _dataSource.getStudentAttendance(studentId);
    return data.map(AttendanceMapper.fromMap).toList();
  }

  @override
  Future<void> markAttendance(String sessionId, String barcode) async {
    await _dataSource.markAttendance(sessionId, barcode);
  }
}
