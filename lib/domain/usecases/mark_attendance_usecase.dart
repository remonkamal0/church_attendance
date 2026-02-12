import '../repositories/student_repository.dart';

class MarkAttendanceUseCase {
  final StudentRepository _repository;

  MarkAttendanceUseCase(this._repository);

  Future<void> call(String sessionId, String barcode) async {
    if (sessionId.isEmpty || barcode.isEmpty) {
      throw ArgumentError('Session ID and barcode cannot be empty');
    }
    await _repository.markAttendance(sessionId, barcode);
  }
}
