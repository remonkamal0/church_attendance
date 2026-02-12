import '../entities/course.dart';
import '../repositories/course_repository.dart';

class GetActiveCoursesUseCase {
  final CourseRepository _repository;

  GetActiveCoursesUseCase(this._repository);

  Future<List<Course>> call() async {
    return await _repository.getActiveCourses();
  }
}
