import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/remote/supabase_datasource.dart';
import '../../data/repositories/student_repository_impl.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../domain/repositories/student_repository.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/usecases/search_students_usecase.dart';
import '../../domain/usecases/mark_attendance_usecase.dart';
import '../../domain/usecases/get_active_courses_usecase.dart';
import '../../presentation/providers/scan_provider.dart';
import '../../presentation/providers/history_provider.dart';

class DependencyInjection {
  static final DependencyInjection _instance = DependencyInjection._internal();
  factory DependencyInjection() => _instance;
  DependencyInjection._internal();

  late final SupabaseDataSource _supabaseDataSource;
  late final StudentRepository _studentRepository;
  late final CourseRepository _courseRepository;
  late final SearchStudentsUseCase _searchStudentsUseCase;
  late final MarkAttendanceUseCase _markAttendanceUseCase;
  late final GetActiveCoursesUseCase _getActiveCoursesUseCase;

  void initialize() {
    _supabaseDataSource = SupabaseDataSourceImpl(Supabase.instance.client);
    _studentRepository = StudentRepositoryImpl(_supabaseDataSource);
    _courseRepository = CourseRepositoryImpl(_supabaseDataSource);
    
    _searchStudentsUseCase = SearchStudentsUseCase(_studentRepository);
    _markAttendanceUseCase = MarkAttendanceUseCase(_studentRepository);
    _getActiveCoursesUseCase = GetActiveCoursesUseCase(_courseRepository);
  }

  ScanProvider createScanProvider() {
    return ScanProvider(
      _getActiveCoursesUseCase,
      _markAttendanceUseCase,
      _courseRepository,
      _studentRepository,
    );
  }

  HistoryProvider createHistoryProvider() {
    return HistoryProvider(
      _searchStudentsUseCase,
      _studentRepository,
    );
  }

  // Getters for repositories and use cases if needed directly
  StudentRepository get studentRepository => _studentRepository;
  CourseRepository get courseRepository => _courseRepository;
  SearchStudentsUseCase get searchStudentsUseCase => _searchStudentsUseCase;
  MarkAttendanceUseCase get markAttendanceUseCase => _markAttendanceUseCase;
  GetActiveCoursesUseCase get getActiveCoursesUseCase => _getActiveCoursesUseCase;
}
