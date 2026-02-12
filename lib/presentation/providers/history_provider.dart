import 'package:flutter/foundation.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/usecases/search_students_usecase.dart';
import '../../domain/repositories/student_repository.dart';

class HistoryProvider extends ChangeNotifier {
  final SearchStudentsUseCase _searchStudentsUseCase;
  final StudentRepository _studentRepository;

  HistoryProvider(
    this._searchStudentsUseCase,
    this._studentRepository,
  );

  List<Student> _searchResults = [];
  Student? _selectedStudent;
  List<Attendance> _attendanceHistory = [];
  bool _isSearching = false;
  bool _isLoadingHistory = false;
  String? _error;

  List<Student> get searchResults => _searchResults;
  Student? get selectedStudent => _selectedStudent;
  List<Attendance> get attendanceHistory => _attendanceHistory;
  bool get isSearching => _isSearching;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;

  Future<void> searchStudents(String query) async {
    if (query.trim().isEmpty) {
      _clearSearch();
      return;
    }

    _setSearching(true);
    try {
      final results = await _searchStudentsUseCase(query);
      _searchResults = results;
      _selectedStudent = null;
      _attendanceHistory = [];
      _error = null;
    } catch (e) {
      _error = 'حصل خطأ في البحث: $e';
    } finally {
      _setSearching(false);
    }
  }

  Future<void> selectStudent(Student student) async {
    _selectedStudent = student;
    _searchResults = [];
    _setLoadingHistory(true);
    
    try {
      final history = await _studentRepository.getStudentAttendanceHistory(student.id);
      _attendanceHistory = history;
      _error = null;
    } catch (e) {
      _error = 'حصل خطأ في تحميل السجل: $e';
    } finally {
      _setLoadingHistory(false);
    }
  }

  void clearSearch() {
    _clearSearch();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _clearSearch() {
    _searchResults = [];
    _selectedStudent = null;
    _attendanceHistory = [];
    _error = null;
    notifyListeners();
  }

  void _setSearching(bool searching) {
    _isSearching = searching;
    notifyListeners();
  }

  void _setLoadingHistory(bool loading) {
    _isLoadingHistory = loading;
    notifyListeners();
  }
}
