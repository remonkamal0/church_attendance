import 'package:equatable/equatable.dart';

class Student extends Equatable {
  final String id;
  final String fullName;
  final String? churchName;
  final String? serviceName;
  final String? barcodeValue;
  final String? photoUrl;

  const Student({
    required this.id,
    required this.fullName,
    this.churchName,
    this.serviceName,
    this.barcodeValue,
    this.photoUrl,
  });

  @override
  List<Object?> get props => [id, fullName, churchName, serviceName, barcodeValue, photoUrl];

  Student copyWith({
    String? id,
    String? fullName,
    String? churchName,
    String? serviceName,
    String? barcodeValue,
    String? photoUrl,
  }) {
    return Student(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      churchName: churchName ?? this.churchName,
      serviceName: serviceName ?? this.serviceName,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
