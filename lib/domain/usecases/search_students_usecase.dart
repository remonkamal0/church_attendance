import '../entities/student.dart';
import '../repositories/student_repository.dart';

class SearchStudentsUseCase {
  final StudentRepository _repository;

  SearchStudentsUseCase(this._repository);

  Future<List<Student>> call(String query) async {
    if (query.trim().isEmpty) return [];
    return await _repository.searchStudents(query);
  }
}
