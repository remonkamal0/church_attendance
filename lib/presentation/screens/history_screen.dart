import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../widgets/student_avatar.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/attendance.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _hapticAndTick() async {
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;

      final provider = context.read<HistoryProvider>();
      if (q.isEmpty) {
        provider.clearSearch();
        return;
      }

      await provider.searchStudents(q);
    });
  }

  void _openQrSearchScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final controller = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
        );

        bool gotResult = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final h = MediaQuery.of(context).size.height;

            return Container(
              height: h * 0.65,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'سكان QR للبحث',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A3C5E),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            MobileScanner(
                              controller: controller,
                              fit: BoxFit.cover,
                              onDetect: (capture) async {
                                if (gotResult) return;

                                final barcodes = capture.barcodes;
                                if (barcodes.isEmpty) return;

                                final code = barcodes.first.rawValue;
                                if (code == null || code.trim().isEmpty) return;

                                gotResult = true;
                                final qr = code.trim();

                                await _hapticAndTick();

                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }

                                _searchController.text = qr;
                                _searchController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _searchController.text.length),
                                );

                                final provider = context.read<HistoryProvider>();
                                await provider.searchStudents(qr);

                                if (provider.searchResults.isEmpty) {
                                  _showToast('الـ QR ده مش متسجل');
                                  return;
                                }

                                if (provider.searchResults.length == 1) {
                                  await provider.selectStudent(provider.searchResults.first);
                                }
                              },
                            ),

                            IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.75),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('إغلاق'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A3C5E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildSearchBar(),
                  const SizedBox(height: 8),

                  if (provider.error != null) _buildError(provider.error!),

                  if (provider.isSearching) _buildLoadingLine('جاري البحث...'),

                  if (provider.searchResults.isNotEmpty) _buildSearchResults(provider),

                  const SizedBox(height: 16),

                  Expanded(
                    child: provider.selectedStudent != null
                        ? _buildStudentHistory(provider)
                        : _buildDefaultView(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'السجل',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3C5E),
              ),
            ),
            Text(
              'البحث بالاسم أو الـ QR',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3C5E).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.people_outlined,
            color: Color(0xFF1A3C5E),
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1A3C5E)),
        decoration: InputDecoration(
          hintText: 'البحث بالاسم أو رقم الـ QR...',
          hintTextDirection: TextDirection.rtl,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 22),

          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'سكان QR',
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF1A3C5E)),
                onPressed: _openQrSearchScanner,
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  tooltip: 'مسح',
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    context.read<HistoryProvider>().clearSearch();
                  },
                ),
            ],
          ),

          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchResults(HistoryProvider provider) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.searchResults.length,
          separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          itemBuilder: (_, index) {
            final student = provider.searchResults[index];
            return ListTile(
              onTap: () => provider.selectStudent(student),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: StudentAvatar(student: student, size: 42),
              title: Text(
                student.fullName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A3C5E),
                ),
              ),
              subtitle: Text(
                '${student.churchName?.isEmpty ?? true ? '—' : student.churchName} • ${student.barcodeValue?.isEmpty ?? true ? 'بدون QR' : student.barcodeValue}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStudentHistory(HistoryProvider provider) {
    final student = provider.selectedStudent!;
    
    if (provider.isLoadingHistory) {
      return _buildLoadingCenter('جاري تحميل سجل ${student.fullName} ...');
    }

    final total = provider.attendanceHistory.length;
    final present = provider.attendanceHistory.where((r) => r.status == AttendanceStatus.present).length;
    final percent = total == 0 ? 0 : ((present / total) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStudentSummaryCard(
          student: student,
          present: present,
          total: total,
          percent: percent,
        ),
        const SizedBox(height: 16),
        const Text(
          'سجل الحضور / الغياب',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A3C5E),
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: total == 0
              ? const Center(
            child: Text('مفيش سجل لحد دلوقتي', style: TextStyle(color: Colors.grey)),
          )
              : ListView.builder(
            itemCount: provider.attendanceHistory.length,
            itemBuilder: (_, index) => _buildRecordItem(provider.attendanceHistory[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentSummaryCard({
    required Student student,
    required int present,
    required int total,
    required int percent,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3C5E), Color(0xFF2E6B9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A3C5E).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            StudentAvatar(student: student, size: 68),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    student.churchName?.isEmpty ?? true ? '—' : student.churchName!,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    student.barcodeValue?.isEmpty ?? true ? 'QR: —' : 'QR: ${student.barcodeValue}',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statChip('حضور', present),
                      const SizedBox(width: 8),
                      _statChip('إجمالي', total),
                      const SizedBox(width: 8),
                      _statChip('نسبة', '$percent%'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(Attendance attendance) {
    final isPresent = attendance.status == AttendanceStatus.present;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
          border: Border.all(
            color: isPresent
                ? const Color(0xFF2E7D32).withOpacity(0.15)
                : const Color(0xFFC62828).withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPresent
                      ? const Color(0xFF2E7D32).withOpacity(0.1)
                      : const Color(0xFFC62828).withOpacity(0.1),
                ),
                child: Center(
                  child: Icon(
                    isPresent ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: isPresent ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          attendance.sessionTitle.isEmpty ? 'جلسة' : attendance.sessionTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A3C5E),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPresent
                                ? const Color(0xFF2E7D32).withOpacity(0.1)
                                : const Color(0xFFC62828).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            attendance.statusArabic,
                            style: TextStyle(
                              fontSize: 11,
                              color: isPresent ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      attendance.sessionDate.isNotEmpty 
                          ? 'تاريخ الجلسة: ${attendance.sessionDate}'
                          : 'وقت التسجيل: ${attendance.scannedAt.toString()}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A3C5E).withOpacity(0.06),
            ),
            child: const Center(
              child: Icon(Icons.search, size: 44, color: Color(0xFF1A3C5E)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'ابحث عن طالب',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A3C5E),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'اكتب الاسم أو رقم الـ QR فوق أو استخدم زر السكان',
            style: TextStyle(fontSize: 13, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLoadingCenter(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFC62828).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC62828).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        ],
      ),
    );
  }
}
