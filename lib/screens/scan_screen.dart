import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final num price;

  CourseOfferingItem({
    required this.id,
    required this.courseTitle,
    required this.yearName,
    required this.price,
  });

  String get label => '$courseTitle • $yearName';
}

class StudentUiModel {
  final String id;
  final String fullName;
  final String? churchName;
  final String? barcodeValue;
  final String? photoUrl;
  final String? courseLabel;

  final num offeringPrice;
  final num paidAmount;
  final num remainingAmount;
  final String paymentStatus;

  StudentUiModel({
    required this.id,
    required this.fullName,
    this.churchName,
    this.barcodeValue,
    this.photoUrl,
    this.courseLabel,
    required this.offeringPrice,
    required this.paidAmount,
    required this.remainingAmount,
    required this.paymentStatus,
  });
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  StudentUiModel? _scannedStudent;
  bool _showSuccess = false;

  bool _isProcessingScan = false;
  bool _isCardVisible = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  List<CourseOfferingItem> _offerings = [];
  CourseOfferingItem? _selectedOffering;

  String? _sessionId;
  bool _openingSession = false;

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  DateTime? _lastScanAt;
  String? _lastBarcode;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
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

  Future<void> _hapticAndTick() async {
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  Future<void> _loadOfferings() async {
    try {
      final res = await supabase
          .from('course_offerings')
          .select('id, price, courses(title), years(name)')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = (res as List).map((row) {
        final rawPrice = row['price'];
        final price = (rawPrice is num) ? rawPrice : (num.tryParse(rawPrice.toString()) ?? 0);

        return CourseOfferingItem(
          id: row['id'] as String,
          courseTitle: (row['courses']?['title'] ?? '').toString(),
          yearName: (row['years']?['name'] ?? '').toString(),
          price: price,
        );
      }).where((x) => x.courseTitle.isNotEmpty && x.yearName.isNotEmpty).toList();

      if (!mounted) return;
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
      _scannedStudent = null;
      _showSuccess = false;
      _isProcessingScan = false;
      _isCardVisible = false;
      _lastBarcode = null;
    });

    try {
      final result = await supabase.rpc('open_today_session', params: {
        'p_offering_id': _selectedOffering!.id,
      });

      final sessionId = result.toString();

      if (!mounted) return;
      setState(() {
        _sessionId = sessionId;
      });

      await _scannerController.start();
      _toast('تم فتح جلسة اليوم ✅ تقدر تسكان دلوقتي');
    } catch (e) {
      _toast('خطأ في فتح الجلسة: $e');
    } finally {
      if (mounted) setState(() => _openingSession = false);
    }
  }

  Future<void> _dismissCardAndResume() async {
    if (!mounted) return;
    setState(() {
      _isCardVisible = false;
      _scannedStudent = null;
      _showSuccess = false;
    });

    try {
      await _scannerController.start();
    } catch (_) {}

    _isProcessingScan = false;
  }

  Future<({num paid, String status})> _getEnrollmentPayment({
    required String studentId,
    required String offeringId,
  }) async {
    try {
      final res = await supabase
          .from('enrollments')
          .select('paid_amount, payment_status')
          .eq('student_id', studentId)
          .eq('course_offering_id', offeringId)
          .maybeSingle();

      if (res == null) {
        return (paid: 0, status: 'unpaid');
      }

      final rawPaid = res['paid_amount'];
      final paid = (rawPaid is num) ? rawPaid : (num.tryParse(rawPaid.toString()) ?? 0);

      final status = (res['payment_status'] ?? 'unpaid').toString();
      return (paid: paid, status: status);
    } catch (_) {
      return (paid: 0, status: 'unpaid');
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوع';
      case 'partial':
        return 'دفع جزئي';
      case 'waived':
        return 'معفي';
      default:
        return 'غير مدفوع';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF2E7D32);
      case 'partial':
        return const Color(0xFFEF6C00);
      case 'waived':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFFC62828);
    }
  }

  String _money(num v) {
    // شكل بسيط بدون intl
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  Future<void> _handleBarcode(String code) async {
    if (_sessionId == null) {
      _toast('لازم تضغط "فتح جلسة اليوم" الأول');
      return;
    }

    if (_isCardVisible) return;

    final now = DateTime.now();
    if (_lastScanAt != null && now.difference(_lastScanAt!) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastScanAt = now;

    if (_lastBarcode != null && _lastBarcode == code) return;

    if (_isProcessingScan) return;
    _isProcessingScan = true;

    setState(() {
      _showSuccess = false;
    });

    try {
      await _scannerController.stop();

      final studentRes = await supabase
          .from('students')
          .select('id, full_name, barcode_value, photo_url, churches(name)')
          .eq('barcode_value', code)
          .maybeSingle();

      if (studentRes == null) {
        await _hapticAndTick();
        _toast('الـ QR ده مش متسجل');

        await _scannerController.start();
        _isProcessingScan = false;
        return;
      }

      await supabase.rpc('mark_present', params: {
        'p_session_id': _sessionId,
        'p_barcode': code,
      });

      await _hapticAndTick();

      final studentId = studentRes['id'] as String;
      final offeringId = _selectedOffering!.id;
      final offeringPrice = _selectedOffering!.price;

      final pay = await _getEnrollmentPayment(studentId: studentId, offeringId: offeringId);
      final paid = pay.paid;
      final status = pay.status;

      final remaining = (offeringPrice - paid) < 0 ? 0 : (offeringPrice - paid);

      final student = StudentUiModel(
        id: studentId,
        fullName: (studentRes['full_name'] ?? '').toString(),
        barcodeValue: (studentRes['barcode_value'] ?? '').toString(),
        photoUrl: (studentRes['photo_url'] ?? '').toString(),
        churchName: (studentRes['churches']?['name'] ?? '').toString(),
        courseLabel: _selectedOffering?.label,
        offeringPrice: offeringPrice,
        paidAmount: paid,
        remainingAmount: remaining,
        paymentStatus: status,
      );

      _lastBarcode = code;

      if (!mounted) return;
      setState(() {
        _scannedStudent = student;
        _showSuccess = true;
        _isCardVisible = true;
      });
    } catch (e) {
      _toast('فشل تسجيل الحضور: $e');
      _isProcessingScan = false;
      try {
        await _scannerController.start();
      } catch (_) {}
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final scanBox = w < 380 ? 240.0 : 270.0;

            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildCourseSelector(),
                        const SizedBox(height: 12),
                        _buildOpenSessionButton(),
                        const SizedBox(height: 18),
                        _buildScanArea(size: scanBox),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),

                if (_isCardVisible)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _dismissCardAndResume,
                      child: Container(color: Colors.black.withOpacity(0.35)),
                    ),
                  ),

                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, anim) {
                      return ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.0).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      );
                    },
                    child: _isCardVisible && _scannedStudent != null
                        ? GestureDetector(
                      key: const ValueKey('student_card'),
                      onTap: _dismissCardAndResume,
                      child: _buildStudentCard(_scannedStudent!),
                    )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
                ),
              ],
            );
          },
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
                color: const Color(0xFF1A3C5E).withOpacity(0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.school_outlined, color: Colors.white, size: 28),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'الكورس / السنة',
                style: TextStyle(fontSize: 14, color: Color(0xFF1A3C5E), fontWeight: FontWeight.w700),
              ),
            ),
            DropdownButton<CourseOfferingItem>(
              value: _selectedOffering,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A3C5E), fontFamily: 'Cairo'),
              items: _offerings.map((o) {
                return DropdownMenuItem<CourseOfferingItem>(
                  value: o,
                  child: SizedBox(width: 190, child: Text('${o.label} • ${_money(o.price)} ج', overflow: TextOverflow.ellipsis)),
                );
              }).toList(),
              onChanged: (val) async {
                setState(() {
                  _selectedOffering = val;
                  _sessionId = null;
                  _isCardVisible = false;
                  _scannedStudent = null;
                  _showSuccess = false;
                  _isProcessingScan = false;
                  _lastBarcode = null;
                });
                try {
                  await _scannerController.stop();
                } catch (_) {}
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
              Text(_sessionId == null ? 'فتح جلسة اليوم' : 'جلسة اليوم شغالة'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanArea({required double size}) {
    final cameraActive = _sessionId != null;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isProcessingScan ? _pulseAnimation.value : 1.0,
          child: child,
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: const Color(0xFF1A3C5E).withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
          border: Border.all(color: const Color(0xFF1A3C5E).withOpacity(0.12), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (cameraActive)
                MobileScanner(
                  controller: _scannerController,
                  fit: BoxFit.cover,
                  onDetect: (capture) {
                    if (!cameraActive) return;
                    if (_isCardVisible) return;
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final code = barcodes.first.rawValue;
                    if (code == null || code.trim().isEmpty) return;
                    _handleBarcode(code.trim());
                  },
                )
              else
                _scanDisabledView(),
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
        Icon(Icons.qr_code_scanner_outlined, size: 72, color: const Color(0xFF1A3C5E).withOpacity(0.45)),
        const SizedBox(height: 10),
        Text('اضغط "فتح جلسة اليوم" أولًا', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildStudentCard(StudentUiModel student) {
    final statusColor = _statusColor(student.paymentStatus);
    final statusText = _statusLabel(student.paymentStatus);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 10))],
        border: Border.all(color: statusColor.withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showSuccess)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 18),
                    SizedBox(width: 8),
                    Text('تم التسجيل - دوس هنا عشان تقفل',
                        style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            _avatar(student),
            const SizedBox(height: 12),

            Text(
              student.fullName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A3C5E)),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),
            _infoRow(Icons.church_outlined, 'الكنيسة', student.churchName ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.school_outlined, 'الخدمة', student.courseLabel ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.qr_code_2, 'QR', student.barcodeValue ?? '-'),

            const SizedBox(height: 8),
            _infoRow(Icons.local_offer_outlined, 'سعر الكورس', '${_money(student.offeringPrice)} ج'),
            const SizedBox(height: 8),
            _infoRow(Icons.payments_outlined, 'المدفوع', '${_money(student.paidAmount)} ج'),
            const SizedBox(height: 8),
            _infoRow(Icons.account_balance_wallet_outlined, 'الباقي', '${_money(student.remainingAmount)} ج'),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 18, color: statusColor),
                  const SizedBox(width: 8),
                  const Text('حالة الدفع', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(statusText, style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(StudentUiModel s) {
    final url = (s.photoUrl ?? '').trim();
    final hasPhoto = url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'));

    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3C5E), Color(0xFF2E6B9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF1A3C5E).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initialAvatar(s))
            : _initialAvatar(s),
      ),
    );
  }

  Widget _initialAvatar(StudentUiModel s) {
    return Center(
      child: Text(
        s.fullName.isNotEmpty ? s.fullName[0] : '?',
        style: const TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1A3C5E)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A3C5E), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
