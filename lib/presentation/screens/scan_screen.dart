import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../widgets/student_avatar.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/payment.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final MobileScannerController _scannerController;

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

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
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

  Future<void> _handleBarcode(String code) async {
    final provider = context.read<ScanProvider>();
    
    if (provider.sessionId == null) {
      _showToast('لازم تضغط "فتح جلسة اليوم" الأول');
      return;
    }

    final now = DateTime.now();
    if (_lastScanAt != null && now.difference(_lastScanAt!) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastScanAt = now;

    if (_lastBarcode != null && _lastBarcode == code) return;

    await _hapticAndTick();
    await provider.scanStudent(code);

    if (provider.error != null) {
      _showToast(provider.error!);
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScanProvider>(
      builder: (context, provider, child) {
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
                            _buildHeader(provider),
                            const SizedBox(height: 16),
                            _buildCourseSelector(provider),
                            const SizedBox(height: 12),
                            _buildOpenSessionButton(provider),
                            const SizedBox(height: 18),
                            _buildScanArea(provider, size: scanBox),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),

                    if (provider.scannedStudent != null)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => provider.dismissCard(),
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
                        child: provider.scannedStudent != null
                            ? GestureDetector(
                                key: const ValueKey('student_card'),
                                onTap: () => provider.dismissCard(),
                                child: _buildStudentCard(provider),
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
      },
    );
  }

  Widget _buildHeader(ScanProvider provider) {
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
          provider.sessionId == null 
              ? 'اختار كورس وافتح جلسة اليوم' 
              : 'جلسة اليوم مفتوحة ✅ (اسكان الـ QR للتسجيل)',
          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCourseSelector(ScanProvider provider) {
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
            DropdownButton<Course>(
              value: provider.selectedCourse,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A3C5E), fontFamily: 'Cairo'),
              items: provider.courses.map((course) {
                return DropdownMenuItem<Course>(
                  value: course,
                  child: SizedBox(
                    width: 190, 
                    child: Text('${course.label} • ${_formatMoney(course.price)} ج', overflow: TextOverflow.ellipsis)
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  provider.selectCourse(val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenSessionButton(ScanProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: provider.isLoading ? null : () => provider.openTodaySession(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A3C5E),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (provider.isLoading) ...[
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
              Text(provider.sessionId == null ? 'فتح جلسة اليوم' : 'جلسة اليوم شغالة'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanArea(ScanProvider provider, {required double size}) {
    final cameraActive = provider.sessionId != null;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: provider.isProcessingScan ? _pulseAnimation.value : 1.0,
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
                    if (!cameraActive || provider.scannedStudent != null) return;
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

  Widget _buildStudentCard(ScanProvider provider) {
    final student = provider.scannedStudent!;
    final payment = provider.scannedStudentPayment;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 10))],
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.showSuccess)
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

            StudentAvatar(student: student),

            const SizedBox(height: 12),

            Text(
              student.fullName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A3C5E)),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),
            _infoRow(Icons.church_outlined, 'الكنيسة', student.churchName ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.school_outlined, 'الخدمة', student.serviceName ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.qr_code_2, 'QR', student.barcodeValue ?? '-'),

            // Payment information
            if (payment != null) ...[
              const SizedBox(height: 12),
              _infoRow(Icons.local_offer_outlined, 'سعر الكورس', '${_formatMoney(payment.offeringPrice)} ج'),
              const SizedBox(height: 8),
              _infoRow(Icons.payments_outlined, 'المدفوع', '${_formatMoney(payment.paidAmount)} ج'),
              const SizedBox(height: 8),
              _infoRow(Icons.account_balance_wallet_outlined, 'الباقي', '${_formatMoney(payment.remainingAmount)} ج'),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _getPaymentStatusColor(payment.status).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getPaymentStatusColor(payment.status).withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 18, color: _getPaymentStatusColor(payment.status)),
                    const SizedBox(width: 8),
                    const Text('حالة الدفع', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(payment.statusArabic, style: TextStyle(fontSize: 13, color: _getPaymentStatusColor(payment.status), fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return const Color(0xFF2E7D32);
      case PaymentStatus.partial:
        return const Color(0xFFEF6C00);
      case PaymentStatus.waived:
        return const Color(0xFF1565C0);
      case PaymentStatus.unpaid:
        return const Color(0xFFC62828);
    }
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

  String _formatMoney(num v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
