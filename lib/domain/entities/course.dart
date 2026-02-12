import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final String id;
  final String title;
  final String yearName;
  final num price;
  final bool isActive;

  const Course({
    required this.id,
    required this.title,
    required this.yearName,
    required this.price,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, title, yearName, price, isActive];

  String get label => '$title • $yearName';

  Course copyWith({
    String? id,
    String? title,
    String? yearName,
    num? price,
    bool? isActive,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      yearName: yearName ?? this.yearName,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
    );
  }
}
