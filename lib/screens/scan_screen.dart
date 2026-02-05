// lib/screens/scan_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class CourseOfferingItem {
  final String id;
  final String courseTitle;
  final String yearName;

  CourseOfferingItem({
    required this.id,
    required this.courseTitle,
    required this.yearName,
  });

  String get label => '$courseTitle • $yearName';
}

class StudentUiModel {
  final String id;
  final String fullName;
  final String? churchName;
  final String? barcodeValue;

  StudentUiModel({
    required this.id,
    required this.fullName,
    this.churchName,
    this.barcodeValue,
  });
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  StudentUiModel? _scannedStudent;

  bool _isScanning = false;     // لواجهة النبض
  bool _showSuccess = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ✅ كورسات
  List<CourseOfferingItem> _offerings = [];
  CourseOfferingItem? _selectedOffering;

  // ✅ جلسة اليوم للكورس
  String? _sessionId;
  bool _openingSession = false;

  // ✅ سكانر
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _cameraActive = false;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadOfferings();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadOfferings() async {
    try {
      final res = await supabase
          .from('course_offerings')
          .select('id, courses(title), years(name)')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = (res as List).map((row) {
        return CourseOfferingItem(
          id: row['id'] as String,
          courseTitle: (row['courses']?['title'] ?? '').toString(),
          yearName: (row['years']?['name'] ?? '').toString(),
        );
      }).where((x) => x.courseTitle.isNotEmpty && x.yearName.isNotEmpty).toList();

      setState(() {
        _offerings = list;
        _selectedOffering = list.isNotEmpty ? list.first : null;
      });
    } catch (e) {
      _toast('فشل تحميل الكورسات: $e');
    }
  }

  Future<void> _openTodaySession() async {
    if (_selectedOffering == null) {
      _toast('اختار كورس الأول');
      return;
    }

    setState(() {
      _openingSession = true;
      _sessionId = null;
      _cameraActive = false;
      _scannedStudent = null;
      _showSuccess = false;
    });

    try {
      final result = await supabase.rpc('open_today_session', params: {
        'p_offering_id': _selectedOffering!.id,
      });

      final sessionId = result.toString();

      setState(() {
        _sessionId = sessionId;
        _cameraActive = true; // ✅ افتح الكاميرا بعد فتح الجلسة
      });

      _toast('تم فتح جلسة اليوم وتجهيز الغياب ✅');
    } catch (e) {
      _toast('خطأ في فتح الجلسة: $e');
    } finally {
      setState(() => _openingSession = false);
    }
  }

  Future<void> _handleBarcode(String code) async {
    // فلتر منع التكرار السريع
    final now = DateTime.now();
    if (_lastScanAt != null && now.difference(_lastScanAt!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastScanAt = now;

    if (_sessionId == null) {
      _toast('لازم تضغط "فتح جلسة اليوم" الأول');
      return;
    }

    setState(() {
      _isScanning = true;
      _showSuccess = false;
      _scannedStudent = null;
    });

    try {
      // 1) سجل حضور في الكورس
      await supabase.rpc('mark_present', params: {
        'p_session_id': _sessionId,
        'p_barcode': code,
      });

      // 2) هات بيانات الطالب لعرضها
      final studentRes = await supabase
          .from('students')
          .select('id, full_name, barcode_value, churches(name)')
          .eq('barcode_value', code)
          .maybeSingle();

      if (studentRes == null) {
        // حصل حضور لكن مش لقينا بيانات؟ (غريب) بس نتعامل
        setState(() {
          _isScanning = false;
          _showSuccess = true;
          _scannedStudent = StudentUiModel(
            id: '',
            fullName: 'تم التسجيل ✅',
            churchName: null,
            barcodeValue: code,
          );
        });
        return;
      }

      final student = StudentUiModel(
        id: studentRes['id'] as String,
        fullName: (studentRes['full_name'] ?? '').toString(),
        barcodeValue: (studentRes['barcode_value'] ?? '').toString(),
        churchName: (studentRes['churches']?['name'] ?? '').toString(),
      );

      setState(() {
        _isScanning = false;
        _scannedStudent = student;
        _showSuccess = true;
      });

      // يرجع يخفي النجاح بعد ثانيتين
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _showSuccess = false;
          _scannedStudent = null;
          _isScanning = false;
        });
      });
    } catch (e) {
      setState(() => _isScanning = false);
      _toast('فشل تسجيل الحضور: $e');
    }
  }

  void _resetCard() {
    setState(() {
      _scannedStudent = null;
      _showSuccess = false;
      _isScanning = false;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                _buildHeader(),
                const SizedBox(height: 18),

                _buildCourseSelector(),
                const SizedBox(height: 12),

                _buildOpenSessionButton(),
                const SizedBox(height: 18),

                _buildScanArea(),
                const SizedBox(height: 24),

                if (_scannedStudent != null && !_showSuccess) _buildStudentCard(_scannedStudent!),
                if (_showSuccess && _scannedStudent != null) _buildSuccessCard(_scannedStudent!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A3C5E), Color(0xFF2E6B9E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A3C5E).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.church_outlined, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 14),
        const Text(
          'حضور الكورس',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A3C5E)),
          textAlign: TextAlign.center,
        ),
        Text(
          _sessionId == null ? 'اختار كورس وافتح جلسة اليوم' : 'جلسة اليوم مفتوحة ✅ (اسكان الـ QR للتسجيل)',
          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCourseSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'الكورس / السنة',
                style: TextStyle(fontSize: 14, color: Color(0xFF1A3C5E), fontWeight: FontWeight.w600),
              ),
            ),
            DropdownButton<CourseOfferingItem>(
              value: _selectedOffering,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A3C5E), fontFamily: 'Cairo'),
              items: _offerings
                  .map((o) => DropdownMenuItem<CourseOfferingItem>(
                value: o,
                child: Text(o.label, overflow: TextOverflow.ellipsis),
              ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedOffering = val;
                  _sessionId = null;       // ✅ تغيير الكورس = لازم تفتح جلسة جديدة
                  _cameraActive = false;
                  _resetCard();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenSessionButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _openingSession ? null : _openTodaySession,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A3C5E),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_openingSession) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Text('جاري فتح جلسة اليوم...'),
            ] else ...[
              const Icon(Icons.play_circle_outline),
              const SizedBox(width: 10),
              const Text('فتح جلسة اليوم'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanArea() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isScanning ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1A3C5E).withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8)),
          ],
          border: Border.all(color: const Color(0xFF1A3C5E).withOpacity(0.12), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_cameraActive)
                MobileScanner(
                  controller: _scannerController,
                  fit: BoxFit.cover,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final code = barcodes.first.rawValue;
                    if (code == null || code.trim().isEmpty) return;
                    _handleBarcode(code.trim());
                  },
                )
              else
                _scanDisabledView(),

              // Overlay بسيط
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.65), width: 2),
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scanDisabledView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.qr_code_scanner_outlined,
          size: 72,
          color: const Color(0xFF1A3C5E).withOpacity(0.45),
        ),
        const SizedBox(height: 10),
        Text(
          _sessionId == null ? 'اضغط "فتح جلسة اليوم" أولًا' : 'الكاميرا غير مفعلة',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildStudentCard(StudentUiModel student) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A3C5E), Color(0xFF2E6B9E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: const Color(0xFF1A3C5E).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text(
                  student.fullName.isNotEmpty ? student.fullName[0] : '?',
                  style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              student.fullName,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1A3C5E)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            if ((student.barcodeValue ?? '').isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3C5E).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  student.barcodeValue!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1A3C5E), fontWeight: FontWeight.w600, letterSpacing: 1.3),
                ),
              ),
            const SizedBox(height: 18),

            _infoRow(Icons.church_outlined, 'الكنيسة', student.churchName ?? '-'),
            const SizedBox(height: 10),
            _infoRow(Icons.access_time_outlined, 'الوقت', _formatTime(DateTime.now())),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _resetCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 22),
                    SizedBox(width: 8),
                    Text('تم - جاهز للي بعده', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _resetCard,
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1A3C5E)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A3C5E), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(StudentUiModel student) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))],
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32).withOpacity(0.1),
              ),
              child: const Center(
                child: Icon(Icons.check_circle, size: 44, color: Color(0xFF2E7D32)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'تم التسجيل بنجاح!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 6),
            Text(
              'تم تسجيل حضور ${student.fullName}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'م' : 'ص';
    return '$h:$m $ampm';
  }
}
