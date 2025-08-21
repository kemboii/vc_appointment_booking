import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Ordered slots from earliest to latest
  final List<String> _slots = const [
    "9:00 AM - 9:15 AM",
    "9:15 AM - 9:30 AM",
    "9:30 AM - 9:45 AM",
    "9:45 AM - 10:00 AM",
    "10:00 AM - 10:15 AM",
    "10:15 AM - 10:30 AM",
    "10:30 AM - 10:45 AM",
    "10:45 AM - 11:00 AM",
    "11:00 AM - 11:15 AM",
    "11:15 AM - 11:30 AM",
    "11:30 AM - 11:45 AM",
    "11:45 AM - 12:00 PM",
  ];

  String _getNextTuesdayDate() {
    final DateTime today = DateTime.now();
    int daysUntilTuesday = (DateTime.tuesday - today.weekday) % 7;
    if (daysUntilTuesday == 0) {
      daysUntilTuesday = 7;
    }
    final DateTime upcomingTuesday =
        today.add(Duration(days: daysUntilTuesday));
    return DateFormat('dd-MM-yyyy').format(upcomingTuesday);
  }

  List<DateTime> _getAllTuesdaysInMonth(DateTime month) {
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final List<DateTime> tuesdays = [];
    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime date = DateTime(month.year, month.month, day);
      if (date.weekday == DateTime.tuesday) {
        tuesdays.add(date);
      }
    }
    return tuesdays;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  String _formatOrdinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  String _formatDisplayFromDdMMyyyy(String ddMMyyyy) {
    final dt = DateFormat('dd-MM-yyyy').parse(ddMMyyyy);
    final dayOrdinal = _formatOrdinal(dt.day);
    final month = DateFormat('MMM').format(dt); // Shorter month format
    final year = DateFormat('y').format(dt); // Full year format
    return '$dayOrdinal $month $year';
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchAppointmentsForDate(
      String dateStr) {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('date', isEqualTo: dateStr)
        .get();
  }

  Future<void> _deleteAppointment(String docId) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(docId)
        .delete();
  }

  Future<void> _blockSlot(String slot) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block Slot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will block the slot so no one can book it.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('appointments').add({
        'date': _selectedDate,
        'slot': slot,
        'bookedBy': 'admin',
        'reason': reasonController.text.trim().isEmpty
            ? 'Slot blocked by admin'
            : reasonController.text.trim(),
        'isBlocked': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot blocked successfully.')),
      );
      _refreshAppointments();
    }
  }

  Future<void> _blockAllSlots() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block All Slots'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This will block every slot for the selected date so no one can book.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A), // Same blue as logo
              foregroundColor: Colors.white,
            ),
            child: const Text('Block All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance.collection('appointments');

      // Preload existing docs to avoid duplicates
      final existing = await _fetchAppointmentsForDate(_selectedDate);
      final existingSlots = <String>{
        for (final d in existing.docs) (d.data()['slot'] as String)
      };

      for (final slot in _slots) {
        if (existingSlots.contains(slot)) {
          final doc = existing.docs.firstWhere((d) => d.data()['slot'] == slot);
          batch.update(doc.reference, {
            'isBlocked': true,
            'blockedReason': reasonController.text.trim().isEmpty
                ? 'All slots blocked by admin'
                : reasonController.text.trim(),
          });
        } else {
          batch.set(col.doc(), {
            'date': _selectedDate,
            'slot': slot,
            'bookedBy': 'admin',
            'reason': reasonController.text.trim().isEmpty
                ? 'All slots blocked by admin'
                : reasonController.text.trim(),
            'isBlocked': true,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All slots blocked successfully.')),
      );
      _refreshAppointments();
    }
  }

  Future<void> _unblockAllBlockedSlots() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unblock All Blocked Slots'),
        content: const Text(
            'This will unblock all admin-blocked slots for the selected date, making them available for booking again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unblock All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final existing = await _fetchAppointmentsForDate(_selectedDate);
      final blockedDocs = existing.docs
          .where((doc) => (doc.data()['isBlocked'] as bool?) == true)
          .toList();

      if (blockedDocs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No blocked slots to unblock.')),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in blockedDocs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All blocked slots unblocked successfully.')),
      );
      _refreshAppointments();
    }
  }

  late Future<QuerySnapshot<Map<String, dynamic>>> _appointmentsFuture;
  late String _selectedDate;
  DateTime _currentMonth = DateTime.now();
  List<String> _tuesdaysInMonth = [];

  void _rebuildTuesdaysInMonth() {
    final List<DateTime> all = _getAllTuesdaysInMonth(_currentMonth);
    final DateTime today = DateTime.now();
    final List<DateTime> filtered = _isSameMonth(_currentMonth, today)
        ? all
            .where((d) =>
                !d.isBefore(DateTime(today.year, today.month, today.day)))
            .toList()
        : all;
    _tuesdaysInMonth =
        filtered.map((d) => DateFormat('dd-MM-yyyy').format(d)).toList();
    if (_tuesdaysInMonth.isNotEmpty) {
      final String nextTue = _getNextTuesdayDate();
      if (_tuesdaysInMonth.contains(nextTue)) {
        _selectedDate = nextTue;
      } else if (!_tuesdaysInMonth.contains(_selectedDate)) {
        _selectedDate = _tuesdaysInMonth.first;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final String nextTuesdayStr = _getNextTuesdayDate();
    _selectedDate = nextTuesdayStr;
    final DateTime nextTuesday = DateFormat('dd-MM-yyyy').parse(nextTuesdayStr);
    _currentMonth = DateTime(nextTuesday.year, nextTuesday.month);
    _rebuildTuesdaysInMonth();
    _appointmentsFuture = _fetchAppointmentsForDate(_selectedDate);
  }

  void _refreshAppointments() {
    setState(() {
      _appointmentsFuture = _fetchAppointmentsForDate(_selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime realCurrentMonth =
        DateTime(DateTime.now().year, DateTime.now().month);
    final bool canGoPrevMonth =
        !DateTime(_currentMonth.year, _currentMonth.month - 1)
            .isBefore(realCurrentMonth);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.maybePop(context);
                },
              )
            : null,
        title: const Text('All Appointments (Admin)'),
        backgroundColor: const Color(0xFF1E3A8A), // Same blue as logo
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // No navigation code here!
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _tuesdaysInMonth.contains(_selectedDate)
                            ? _selectedDate
                            : (_tuesdaysInMonth.isNotEmpty
                                ? _tuesdaysInMonth.first
                                : null),
                        decoration: const InputDecoration(
                          labelText: 'Select Tuesday',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _tuesdaysInMonth
                            .map((dateStr) => DropdownMenuItem<String>(
                                  value: dateStr,
                                  child: Text(
                                    _formatDisplayFromDdMMyyyy(dateStr),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedDate = value;
                            _appointmentsFuture =
                                _fetchAppointmentsForDate(_selectedDate);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Previous month',
                            icon: const Icon(Icons.chevron_left,
                                color: Color(0xFF1E3A8A)),
                            onPressed: canGoPrevMonth
                                ? () {
                                    setState(() {
                                      _currentMonth = DateTime(
                                          _currentMonth.year,
                                          _currentMonth.month - 1);
                                      _rebuildTuesdaysInMonth();
                                      _appointmentsFuture =
                                          _fetchAppointmentsForDate(
                                              _selectedDate);
                                    });
                                  }
                                : null,
                          ),
                          IconButton(
                            tooltip: 'Next month',
                            icon: const Icon(Icons.chevron_right,
                                color: Color(0xFF1E3A8A)),
                            onPressed: () {
                              setState(() {
                                _currentMonth = DateTime(_currentMonth.year,
                                    _currentMonth.month + 1);
                                _rebuildTuesdaysInMonth();
                                _appointmentsFuture =
                                    _fetchAppointmentsForDate(_selectedDate);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Appointments for ${_formatDisplayFromDdMMyyyy(_selectedDate)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _blockAllSlots(),
                        icon: const Icon(Icons.block, size: 20),
                        label: const Text(
                          'Block All Slots',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF1E3A8A), // Same blue as logo
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _unblockAllBlockedSlots(),
                        icon: const Icon(Icons.lock_open, size: 20),
                        label: const Text(
                          'Unblock All',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
              future: _appointmentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                // Build a map of slot -> appointment doc for quick lookup
                final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
                    slotToDoc = {
                  for (final d in docs) (d.data()['slot'] as String): d
                };
                final int bookedCount = slotToDoc.length;
                final int availableCount = _slots.length - bookedCount;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Available: $availableCount',
                                    style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy,
                                      color: Colors.red.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Booked: $bookedCount',
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _slots.length,
                        itemBuilder: (context, index) {
                          final slot = _slots[index];
                          final doc = slotToDoc[slot];

                          if (doc == null) {
                            // Available slot
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              elevation: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade50,
                                      Colors.green.shade100
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.access_time,
                                        color: Colors.green),
                                  ),
                                  title: Text(
                                    slot,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: const Text(
                                    'Available for booking',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                  trailing: OutlinedButton.icon(
                                    onPressed: () => _blockSlot(slot),
                                    icon: const Icon(Icons.block, size: 18),
                                    label: const Text('Block'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange.shade700,
                                      side: BorderSide(
                                          color: Colors.orange.shade300),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final appointment = doc.data();
                          final bool isBlocked =
                              (appointment['isBlocked'] as bool?) == true;

                          return FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .where('email',
                                    isEqualTo: appointment['bookedBy'])
                                .limit(1)
                                .get(),
                            builder: (context, userSnapshot) {
                              String subtitle;
                              if (userSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                subtitle =
                                    'Loading user...\nReason: ${appointment['reason'] ?? 'N/A'}';
                              } else if (userSnapshot.hasError) {
                                subtitle =
                                    'Booked By: ${appointment['bookedBy'] ?? 'N/A'} (Lookup failed)\nReason: ${appointment['reason'] ?? 'N/A'}';
                              } else if (userSnapshot.data!.docs.isEmpty) {
                                subtitle =
                                    'Booked By: ${appointment['bookedBy'] ?? 'N/A'} (Unknown Role)\nReason: ${appointment['reason'] ?? 'N/A'}';
                              } else {
                                final userData = userSnapshot.data!.docs.first
                                    .data() as Map<String, dynamic>;
                                final userName =
                                    userData['name'] ?? 'Unknown Name';
                                final userRole =
                                    userData['role'] ?? 'Unknown Role';

                                final studentId = (userRole == 'Parent')
                                    ? (userData['studentId'] as String?)
                                    : null;
                                final parentLine = (studentId != null &&
                                        studentId.trim().isNotEmpty)
                                    ? '\nParent of Student ID: $studentId'
                                    : '';

                                final schoolId =
                                    userData['schoolId'] as String?;
                                final school = userData['school'] as String?;
                                final department =
                                    userData['department'] as String?;
                                final jobRole = userData['jobRole'] as String?;

                                final studentLines = (userRole == 'Student')
                                    ? '\nSchool ID: ${schoolId ?? 'N/A'}\nSchool: ${school ?? 'N/A'}\nDepartment: ${department ?? 'N/A'}'
                                    : '';
                                final staffLines = (userRole == 'Staff Member')
                                    ? '\nJob Role: ${jobRole ?? 'N/A'}'
                                    : '';

                                if (isBlocked) {
                                  subtitle =
                                      'Blocked by admin\nReason: ${appointment['reason'] ?? 'N/A'}';
                                } else {
                                  subtitle =
                                      'Booked By: $userName ($userRole)$parentLine$studentLines$staffLines\nEmail: ${appointment['bookedBy'] ?? 'N/A'}\nReason: ${appointment['reason'] ?? 'N/A'}';
                                }
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                elevation: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      colors: isBlocked
                                          ? [
                                              Colors.red.shade50,
                                              Colors.red.shade100
                                            ]
                                          : [
                                              const Color(0xFF1E3A8A)
                                                  .withOpacity(0.1),
                                              const Color(0xFF1E3A8A)
                                                  .withOpacity(0.2)
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isBlocked
                                            ? Colors.red.shade200
                                            : const Color(0xFF1E3A8A)
                                                .withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isBlocked
                                            ? Icons.block
                                            : Icons.event_available,
                                        color: isBlocked
                                            ? Colors.red
                                            : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    title: Text(
                                      slot,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: isBlocked
                                            ? Colors.red.shade700
                                            : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      tooltip: 'Remove appointment',
                                      onPressed: () async {
                                        final scaffoldMessenger =
                                            ScaffoldMessenger.of(context);
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) =>
                                              AlertDialog(
                                            title: const Text('Confirm Delete'),
                                            content: const Text(
                                                'Are you sure you want to remove this appointment?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                    dialogContext, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    dialogContext, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await _deleteAppointment(doc.id);
                                            if (!mounted) return;
                                            scaffoldMessenger.showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Appointment deleted.')));
                                            _refreshAppointments();
                                          } catch (e) {
                                            if (!mounted) return;
                                            scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Failed to delete: $e')));
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
