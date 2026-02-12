import '../../domain/entities/course.dart';

class CourseMapper {
  static Course fromMap(Map<String, dynamic> map) {
    final rawPrice = map['price'];
    final price = (rawPrice is num) ? rawPrice : (num.tryParse(rawPrice.toString()) ?? 0);

    return Course(
      id: map['id'] as String,
      title: (map['courses']?['title'] ?? '').toString(),
      yearName: (map['years']?['name'] ?? '').toString(),
      price: price,
      isActive: true, // Assuming all returned courses are active
    );
  }

  static Map<String, dynamic> toMap(Course course) {
    return {
      'id': course.id,
      'title': course.title,
      'year_name': course.yearName,
      'price': course.price,
      'is_active': course.isActive,
    };
  }
}
