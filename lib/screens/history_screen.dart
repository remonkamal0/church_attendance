// lib/screens/history_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Haptic + SystemSound
import 'package:mobile_scanner/mobile_scanner.dart'; // ✅ QR Scan
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  bool _isSearching = false;
  bool _isLoadingHistory = false;

  Map<String, dynamic>? _selectedStudent;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _attendanceRows = [];

  String? _error;

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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _hapticAndTick() async {
    try {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // ignore
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;

      if (q.isEmpty) {
        setState(() {
          _searchResults = [];
          _selectedStudent = null;
          _attendanceRows = [];
          _error = null;
          _isSearching = false;
        });
        return;
      }

      await _searchStudents(q);
    });
  }

  Future<void> _searchStudents(String query) async {
    setState(() {
      _isSearching = true;
      _error = null;
      _searchResults = [];
      _selectedStudent = null;
      _attendanceRows = [];
    });

    try {
      final res = await _supabase
          .from('students')
          .select('id, full_name, barcode_value, photo_url, churches(name)')
          .or('full_name.ilike.%$query%,barcode_value.eq.$query')
          .limit(20);

      final rows = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _searchResults = rows;
      });
    } catch (e) {
      setState(() {
        _error = 'حصل خطأ في البحث: $e';
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectStudent(Map<String, dynamic> student) async {
    setState(() {
      _selectedStudent = student;
      _searchResults = [];
      _isLoadingHistory = true;
      _error = null;
      _attendanceRows = [];
    });

    try {
      final studentId = student['id'] as String;

      final res = await _supabase
          .from('session_attendance')
          .select('id, status, scanned_at, notes, course_sessions(session_date, title)')
          .eq('student_id', studentId)
          .order('scanned_at', ascending: false)
          .limit(300);

      final rows = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _attendanceRows = rows;
      });
    } catch (e) {
      setState(() {
        _error = 'حصل خطأ في تحميل السجل: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // ✅ سكان QR للبحث داخل صفحة السجل
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

                                // ✅ تيك + هزاز
                                await _hapticAndTick();

                                // اقفل الشيت
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }

                                // حط القيمة في البحث
                                _searchController.text = qr;
                                _searchController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _searchController.text.length),
                                );

                                // نفّذ البحث فورًا
                                await _searchStudents(qr);

                                // ✅ لو ملقاش طالب
                                if (_searchResults.isEmpty) {
                                  _toast('الـ QR ده مش متسجل');
                                  return;
                                }

                                // ✅ لو نتيجة واحدة: افتح السجل تلقائي
                                if (_searchResults.length == 1) {
                                  await _selectStudent(_searchResults.first);
                                }
                              },
                            ),

                            // Overlay إطار
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

  @override
  Widget build(BuildContext context) {
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

              if (_error != null) _buildError(_error!),

              if (_isSearching) _buildLoadingLine('جاري البحث...'),

              if (_searchResults.isNotEmpty) _buildSearchResults(),

              const SizedBox(height: 16),

              Expanded(
                child: _selectedStudent != null
                    ? _buildStudentHistory()
                    : _buildDefaultView(),
              ),
            ],
          ),
        ),
      ),
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

          // ✅ زر سكان QR + زر مسح
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
                    setState(() {
                      _selectedStudent = null;
                      _searchResults = [];
                      _attendanceRows = [];
                      _error = null;
                    });
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

  Widget _buildSearchResults() {
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
          itemCount: _searchResults.length,
          separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          itemBuilder: (_, index) {
            final s = _searchResults[index];
            final name = (s['full_name'] ?? '').toString();
            final barcode = (s['barcode_value'] ?? '').toString();

            String churchName = '';
            final churches = s['churches'];
            if (churches is Map && churches['name'] != null) {
              churchName = churches['name'].toString();
            }

            return ListTile(
              onTap: () => _selectStudent(s),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A3C5E), Color(0xFF2E6B9E)],
                  ),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0] : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A3C5E),
                ),
              ),
              subtitle: Text(
                '${churchName.isEmpty ? '—' : churchName} • ${barcode.isEmpty ? 'بدون QR' : barcode}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStudentHistory() {
    final s = _selectedStudent!;
    final name = (s['full_name'] ?? '').toString();
    final barcode = (s['barcode_value'] ?? '').toString();

    String churchName = '';
    final churches = s['churches'];
    if (churches is Map && churches['name'] != null) {
      churchName = churches['name'].toString();
    }

    if (_isLoadingHistory) {
      return _buildLoadingCenter('جاري تحميل سجل $name ...');
    }

    final total = _attendanceRows.length;
    final present = _attendanceRows.where((r) => (r['status'] ?? '').toString() == 'present').length;
    final percent = total == 0 ? 0 : ((present / total) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStudentSummaryCard(
          name: name,
          church: churchName,
          barcode: barcode,
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
            itemCount: _attendanceRows.length,
            itemBuilder: (_, index) => _buildRecordItem(_attendanceRows[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentSummaryCard({
    required String name,
    required String church,
    required String barcode,
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
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    church.isEmpty ? '—' : church,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    barcode.isEmpty ? 'QR: —' : 'QR: $barcode',
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

  Widget _buildRecordItem(Map<String, dynamic> row) {
    final status = (row['status'] ?? 'absent').toString();
    final scannedAt = row['scanned_at'];

    String title = '';
    String dateStr = '';

    final cs = row['course_sessions'];
    if (cs is Map) {
      title = (cs['title'] ?? '').toString();
      final d = (cs['session_date'] ?? '').toString();
      if (d.isNotEmpty) dateStr = d;
    }

    final isPresent = status == 'present';

    String statusAr = switch (status) {
      'present' => 'حاضر',
      'late' => 'متأخر',
      'excused' => 'بعذر',
      _ => 'غائب',
    };

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
                          title.isEmpty ? 'جلسة' : title,
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
                            statusAr,
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
                      _formatLine(dateStr, scannedAt),
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

  String _formatLine(String sessionDate, dynamic scannedAt) {
    if (sessionDate.isNotEmpty) {
      return 'تاريخ الجلسة: $sessionDate';
    }
    if (scannedAt != null) {
      return 'وقت التسجيل: ${scannedAt.toString()}';
    }
    return '—';
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
