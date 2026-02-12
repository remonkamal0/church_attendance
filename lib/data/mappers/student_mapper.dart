import '../../domain/entities/student.dart';

class StudentMapper {
  static Student fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as String,
      fullName: (map['full_name'] ?? '').toString(),
      churchName: map['churches']?['name']?.toString(),
      serviceName: map['services']?['name']?.toString(),
      barcodeValue: (map['barcode_value'] ?? '').toString(),
      photoUrl: (map['photo_url'] ?? '').toString(),
    );
  }

  static Map<String, dynamic> toMap(Student student) {
    return {
      'id': student.id,
      'full_name': student.fullName,
      'church_name': student.churchName,
      'service_name': student.serviceName,
      'barcode_value': student.barcodeValue,
      'photo_url': student.photoUrl,
    };
  }
}
