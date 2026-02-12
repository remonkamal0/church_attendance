import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseDashboardScreen extends StatefulWidget {
  const CourseDashboardScreen({super.key});

  @override
  State<CourseDashboardScreen> createState() => _CourseDashboardScreenState();
}

class _CourseDashboardScreenState extends State<CourseDashboardScreen> {
  final _supabase = Supabase.instance.client;

  bool _loadingOfferings = true;
  bool _loadingDashboard = false;

  List<Map<String, dynamic>> _offerings = [];
  String? _selectedOfferingId;

  List<Map<String, dynamic>> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _loadingOfferings = true;
      _error = null;
    });

    try {
      final res = await _supabase
          .from('course_offerings')
          .select('id, courses(title), years(name)')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _offerings = list;
        if (_offerings.isNotEmpty) {
          _selectedOfferingId ??= _offerings.first['id'] as String;
        }
      });

      if (_selectedOfferingId != null) {
        await _loadDashboard(_selectedOfferingId!);
      }
    } catch (e) {
      setState(() => _error = 'حصل خطأ في تحميل الكورسات: $e');
    } finally {
      if (mounted) setState(() => _loadingOfferings = false);
    }
  }

  Future<void> _loadDashboard(String offeringId) async {
    setState(() {
      _loadingDashboard = true;
      _error = null;
      _rows = [];
    });

    try {
      final res = await _supabase.rpc(
        'get_course_dashboard',
        params: {'p_offering': offeringId},
      );

      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() => _rows = list);
    } catch (e) {
      setState(() => _error = 'حصل خطأ في تحميل الداشبورد: $e');
    } finally {
      if (mounted) setState(() => _loadingDashboard = false);
    }
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
              _header(),
              const SizedBox(height: 16),

              _courseSelector(),
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

  Widget _courseSelector() {
    if (_loadingOfferings) {
      return _infoCard('جاري تحميل الكورسات...');
    }

    if (_offerings.isEmpty) {
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
              value: _selectedOfferingId,
              isExpanded: true,
              underline: const SizedBox(),
              items: _offerings.map((o) {
                final id = o['id'] as String;
                final courseTitle = (o['courses']?['title'] ?? 'Course').toString();
                final yearName = (o['years']?['name'] ?? '').toString();
                final label = yearName.isEmpty ? courseTitle : '$courseTitle - $yearName';
                return DropdownMenuItem(
                  value: id,
                  child: Text(label, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) async {
                if (val == null) return;
                setState(() => _selectedOfferingId = val);
                await _loadDashboard(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> r) {
    final date = (r['session_date'] ?? '').toString();
    final title = (r['session_title'] ?? 'جلسة').toString();

    final enrolled = (r['enrolled_count'] ?? 0) as int;
    final present = (r['present_count'] ?? 0) as int;

    final boys = (r['boys_present'] ?? 0) as int;
    final girls = (r['girls_present'] ?? 0) as int;

    final percent = enrolled == 0 ? 0 : ((present / enrolled) * 100).round();

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
}
