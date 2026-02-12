import 'package:flutter/foundation.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/payment.dart';
import '../../domain/usecases/get_active_courses_usecase.dart';
import '../../domain/usecases/mark_attendance_usecase.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/student_repository.dart';

class ScanProvider extends ChangeNotifier {
  final GetActiveCoursesUseCase _getActiveCoursesUseCase;
  final MarkAttendanceUseCase _markAttendanceUseCase;
  final CourseRepository _courseRepository;
  final StudentRepository _studentRepository;

  ScanProvider(
    this._getActiveCoursesUseCase,
    this._markAttendanceUseCase,
    this._courseRepository,
    this._studentRepository,
  );

  List<Course> _courses = [];
  Course? _selectedCourse;
  String? _sessionId;
  Student? _scannedStudent;
  Payment? _scannedStudentPayment;
  bool _isLoading = false;
  bool _isProcessingScan = false;
  bool _showSuccess = false;
  String? _error;

  List<Course> get courses => _courses;
  Course? get selectedCourse => _selectedCourse;
  String? get sessionId => _sessionId;
  Student? get scannedStudent => _scannedStudent;
  Payment? get scannedStudentPayment => _scannedStudentPayment;
  bool get isLoading => _isLoading;
  bool get isProcessingScan => _isProcessingScan;
  bool get showSuccess => _showSuccess;
  String? get error => _error;
  CourseRepository get courseRepository => _courseRepository;

  Future<void> loadCourses() async {
    _setLoading(true);
    try {
      final courses = await _getActiveCoursesUseCase();
      _courses = courses.where((c) => c.title.isNotEmpty && c.yearName.isNotEmpty).toList();
      _selectedCourse = _courses.isNotEmpty ? _courses.first : null;
      _error = null;
    } catch (e) {
      _error = 'فشل تحميل الكورسات: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> openTodaySession() async {
    if (_selectedCourse == null) {
      _error = 'اختار كورس الأول';
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      final sessionId = await _courseRepository.openTodaySession(_selectedCourse!.id);
      _sessionId = sessionId;
      _error = null;
    } catch (e) {
      _error = 'خطأ في فتح الجلسة: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> scanStudent(String barcode) async {
    if (_sessionId == null) {
      _error = 'لازم تضغط "فتح جلسة اليوم" الأول';
      notifyListeners();
      return;
    }

    if (_isProcessingScan) return;

    _setProcessingScan(true);
    _showSuccess = false;

    try {
      await _markAttendanceUseCase(_sessionId!, barcode);
      
      // Get student info and payment details
      final student = await _getStudentByBarcode(barcode);
      if (student != null) {
        final payment = await _courseRepository.getStudentPayment(student.id, _selectedCourse!.id);
        
        _scannedStudent = student;
        _scannedStudentPayment = payment;
        _showSuccess = true;
        _error = null;
      } else {
        _error = 'الـ QR ده مش متسجل';
      }
    } catch (e) {
      _error = 'فشل تسجيل الحضور: $e';
    } finally {
      _setProcessingScan(false);
    }
  }

  void selectCourse(Course course) {
    _selectedCourse = course;
    _sessionId = null;
    _scannedStudent = null;
    _scannedStudentPayment = null;
    _showSuccess = false;
    notifyListeners();
  }

  void dismissCard() {
    _scannedStudent = null;
    _scannedStudentPayment = null;
    _showSuccess = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setProcessingScan(bool processing) {
    _isProcessingScan = processing;
    notifyListeners();
  }

  Future<Student?> _getStudentByBarcode(String barcode) async {
    return await _studentRepository.getStudentByBarcode(barcode);
  }
}
