import 'package:flutter/material.dart';
import '../../domain/entities/student.dart';

class StudentAvatar extends StatelessWidget {
  final Student student;
  final double size;

  const StudentAvatar({
    super.key,
    required this.student,
    this.size = 86,
  });

  @override
  Widget build(BuildContext context) {
    final url = (student.photoUrl ?? '').trim();
    final hasPhoto = url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3C5E), Color(0xFF2E6B9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A3C5E).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipOval(
        child: hasPhoto && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Image error: $error');
                  return _buildInitialAvatar();
                },
              )
            : _buildInitialAvatar(),
      ),
    );
  }

  Widget _buildInitialAvatar() {
    final firstLetter = student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?';
    return Center(
      child: Text(
        firstLetter,
        style: TextStyle(
          fontSize: size * 0.4,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
