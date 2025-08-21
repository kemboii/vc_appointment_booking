import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../widgets/reason_selection_widget.dart';
import '../screens/my_bookings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _slots = [
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

  String _selectedDate = ""; // dd-MM-yyyy
  List<String> _bookedSlots = [];
  List<String> _adminBlockedSlots = [];
  DateTime _currentMonth = DateTime.now();
  List<String> _tuesdaysInMonth = [];
  String _userFirstName = "";
  String _userRole = "";

  @override
  void initState() {
    super.initState();
    final String nextTuesdayStr = _getNextTuesdayDate();
    _selectedDate = nextTuesdayStr;
    final DateTime nextTuesday = DateFormat('dd-MM-yyyy').parse(nextTuesdayStr);
    _currentMonth = DateTime(nextTuesday.year, nextTuesday.month);
    _rebuildTuesdaysInMonth();
    _loadBookedSlots();
    _loadUserFirstName();
  }

  Future<void> _loadUserFirstName() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data() ?? const {};
      final fullName = data['name'] as String?;
      final role = data['role'] as String?;
      if (!mounted) return;
      setState(() {
        _userRole = (role ?? '').trim().isEmpty ? 'Student' : role!.trim();
        if (fullName == null || fullName.trim().isEmpty) {
          _userFirstName = (_authService.currentUser?.email ?? 'User');
        } else {
          final parts = fullName.trim().split(' ');
          _userFirstName = parts.isNotEmpty ? parts.first : fullName;
        }
      });
    } catch (_) {
      // Fallbacks
      if (!mounted) return;
      setState(() {
        _userFirstName = (_authService.currentUser?.email ?? 'User');
        _userRole = 'Student';
      });
    }
  }

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
      // Ensure selection defaults to upcoming Tuesday in this month when applicable
      final String nextTue = _getNextTuesdayDate();
      if (_tuesdaysInMonth.contains(nextTue)) {
        _selectedDate = nextTue;
      } else if (!_tuesdaysInMonth.contains(_selectedDate)) {
        _selectedDate = _tuesdaysInMonth.first;
      }
    }
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

  Future<void> _loadBookedSlots() async {
    final snapshot = await _firestore
        .collection('appointments')
        .where('date', isEqualTo: _selectedDate)
        .get();

    if (!mounted) return;

    setState(() {
      _bookedSlots = snapshot.docs.map((doc) => doc['slot'] as String).toList();
      _adminBlockedSlots = snapshot.docs
          .where((doc) => (doc.data()['isBlocked'] as bool?) == true)
          .map((doc) => doc['slot'] as String)
          .toList();
    });
  }

  Future<void> _bookSlot(String slot, String reason) async {
    final userEmail = _authService.currentUser?.email;

    if (userEmail == null) return;

    final DateTime selected = DateFormat('dd-MM-yyyy').parse(_selectedDate);
    final String monthKey = DateFormat('yyyy-MM').format(selected);

    // Enforce only one appointment per user per month
    final existingMonth = await _firestore
        .collection('appointments')
        .where('bookedBy', isEqualTo: userEmail)
        .where('monthKey', isEqualTo: monthKey)
        .limit(1)
        .get();

    if (existingMonth.docs.isNotEmpty) {
      if (!mounted) return;
      _showDialog("You already have an appointment this month.");
      return;
    }

    await _firestore.collection('appointments').add({
      'bookedBy': userEmail,
      'slot': slot,
      'date': _selectedDate,
      'monthKey': monthKey,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    _showDialog("Appointment booked successfully!");
    _loadBookedSlots();
  }

  void _showDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Notice"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showReasonDialog(String slot) {
    String selectedReason = ""; // To store the selected reason

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Select a Reason"),
        content: ReasonSelectionWidget(
          role: _userRole.isNotEmpty ? _userRole : 'Student',
          onReasonSelected: (reason) {
            selectedReason = reason;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedReason.isNotEmpty) {
                _bookSlot(slot, selectedReason);
                Navigator.pop(context);
              } else {
                // Show an error message if no reason is selected
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select a reason.")),
                );
              }
            },
            child: const Text("Book Appointment"),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _authService.signOut();
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
        title: const Text("Book Appointment"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'My Bookings',
            icon: const Icon(Icons.event_note),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyBookingsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _userFirstName.isEmpty
                      ? "Welcome"
                      : "Welcome, $_userFirstName",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
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
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() {
                            _selectedDate = value;
                          });
                          await _loadBookedSlots();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Previous month',
                            icon: const Icon(Icons.chevron_left,
                                color: Colors.blue),
                            onPressed: canGoPrevMonth
                                ? () async {
                                    setState(() {
                                      _currentMonth = DateTime(
                                          _currentMonth.year,
                                          _currentMonth.month - 1);
                                      _rebuildTuesdaysInMonth();
                                    });
                                    await _loadBookedSlots();
                                  }
                                : null,
                          ),
                          IconButton(
                            tooltip: 'Next month',
                            icon: const Icon(Icons.chevron_right,
                                color: Colors.blue),
                            onPressed: () async {
                              setState(() {
                                _currentMonth = DateTime(_currentMonth.year,
                                    _currentMonth.month + 1);
                                _rebuildTuesdaysInMonth();
                              });
                              await _loadBookedSlots();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Available Slots for ${_formatDisplayFromDdMMyyyy(_selectedDate)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
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
                final isBooked = _bookedSlots.contains(slot);
                final isAdminBlocked = _adminBlockedSlots.contains(slot);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  elevation: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: isBooked
                            ? [Colors.red.shade50, Colors.red.shade100]
                            : [Colors.blue.shade50, Colors.blue.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isBooked
                              ? Colors.red.shade200
                              : Colors.blue.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isBooked ? Icons.event_busy : Icons.access_time,
                          color: isBooked ? Colors.red : Colors.blue,
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
                        isBooked
                            ? (isAdminBlocked ? "Booked by Admin" : "Booked")
                            : "Available for booking",
                        style: TextStyle(
                          color: isBooked
                              ? Colors.red.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                      trailing: isBooked
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: const Text(
                                "Booked",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _showReasonDialog(slot),
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: const Text("Book"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
