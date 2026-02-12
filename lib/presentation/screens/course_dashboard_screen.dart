import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../../domain/entities/course.dart';

class CourseDashboardScreen extends StatefulWidget {
  const CourseDashboardScreen({super.key});

  @override
  State<CourseDashboardScreen> createState() => _CourseDashboardScreenState();
}

class _CourseDashboardScreenState extends State<CourseDashboardScreen> {
  bool _loadingDashboard = false;
  List<Map<String, dynamic>> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboard();
    });
  }

  Future<void> _loadDashboard() async {
    final provider = context.read<ScanProvider>();
    
    if (provider.selectedCourse == null) {
      setState(() {
        _error = 'مفيش كورس متاح حالياً';
      });
      return;
    }

    setState(() {
      _loadingDashboard = true;
      _error = null;
      _rows = [];
    });

    try {
      final dashboard = await provider.courseRepository.getCourseDashboard(provider.selectedCourse!.id);
      setState(() {
        _rows = dashboard;
      });
    } catch (e) {
      setState(() {
        _error = 'حصل خطأ في تحميل الداشبورد: $e';
      });
    } finally {
      setState(() {
        _loadingDashboard = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScanProvider>(
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
                  _header(),
                  const SizedBox(height: 16),

                  _courseSelector(provider),
                  const SizedBox(height: 12),

                  if (_error != null) _errorBox(_error!),

                  Expanded(
                    child: _loadingDashboard
                        ? const Center(child: CircularProgressIndicator())
                        : _rows.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (_, i) => _sessionCard(_rows[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard الكورس',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3C5E),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'حضور يوم بيوم + ولد/بنت',
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
          child: const Icon(Icons.dashboard_outlined,
              color: Color(0xFF1A3C5E), size: 22),
        ),
      ],
    );
  }

  Widget _courseSelector(ScanProvider provider) {
    if (provider.courses.isEmpty) {
      return _infoCard('مفيش كورسات متاحة');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          const Text(
            'الكورس:',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1A3C5E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: provider.selectedCourse?.id,
              isExpanded: true,
              underline: const SizedBox(),
              items: provider.courses.map((course) {
                return DropdownMenuItem(
                  value: course.id,
                  child: Text(course.label, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) async {
                if (val == null) return;
                final course = provider.courses.firstWhere((c) => c.id == val);
                provider.selectCourse(course);
                await _loadDashboard();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> r) {
    debugPrint('=== Session Card Data ===');
    debugPrint('Session data: $r');
    debugPrint('Keys: ${r.keys}');
    
    final date = (r['session_date'] ?? '').toString();
    final title = (r['session_title'] ?? 'جلسة').toString();
    final sessionId = r['session_id']?.toString();

    final enrolled = (r['enrolled_count'] ?? 0) as int;
    final present = (r['present_count'] ?? 0) as int;

    final boys = (r['boys_present'] ?? 0) as int;
    final girls = (r['girls_present'] ?? 0) as int;

    final percent = enrolled == 0 ? 0 : ((present / enrolled) * 100).round();

    debugPrint('Session ID extracted: "$sessionId"');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_note_outlined, color: Color(0xFF1A3C5E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A3C5E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3C5E).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      date,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1A3C5E)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: sessionId != null && sessionId.isNotEmpty ? () => _deleteSession(sessionId) : null,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'حذف الجلسة',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _chip('حاضر', '$present'),
                  const SizedBox(width: 8),
                  _chip('إجمالي', '$enrolled'),
                  const SizedBox(width: 8),
                  _chip('نسبة', '$percent%'),
                ],
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _genderTile('أولاد', boys)),
                  const SizedBox(width: 10),
                  Expanded(child: _genderTile('بنات', girls)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A3C5E),
              )),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _genderTile(String label, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline, size: 18, color: Color(0xFF1A3C5E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Text('$count',
              style: const TextStyle(
                color: Color(0xFF1A3C5E),
                fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }

  Widget _infoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFC62828)))),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Text('مفيش Sessions للكورس ده', style: TextStyle(color: Colors.grey)),
    );
  }

  Future<void> _deleteSession(String sessionId) async {
    debugPrint('=== Delete Session Debug ===');
    debugPrint('Session ID: "$sessionId"');
    debugPrint('Session ID type: ${sessionId.runtimeType}');
    debugPrint('Is null: ${sessionId == null}');
    debugPrint('Is empty: ${sessionId?.isEmpty ?? true}');
    
    if (sessionId == null || sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('معرف الجلسة غير صالح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذه الجلسة؟ هذا الإجراء لا يمكن التراجع عنه.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        debugPrint('Attempting to delete session...');
        await context.read<ScanProvider>().courseRepository.deleteSession(sessionId);
        debugPrint('Session deleted successfully');
        await _loadDashboard();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الجلسة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Delete failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل حذف الجلسة: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
