import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vc_appointment_booking/services/notification_service.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Future<QuerySnapshot<Map<String, dynamic>>> _future;
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

  @override
  void initState() {
    super.initState();
    _future = _loadMyBookings();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _loadMyBookings() async {
    final email = _auth.currentUser?.email;
    if (email == null) {
      // Query that will return empty results
      return _firestore
          .collection('appointments')
          .where('bookedBy', isEqualTo: '__none__')
          .limit(1)
          .get();
    }
    return _firestore
        .collection('appointments')
        .where('bookedBy', isEqualTo: email)
        .orderBy('timestamp', descending: true)
        .get();
  }

  Future<void> _cancelAppointment(String documentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firestore.collection('appointments').doc(documentId).delete();
      // Cancel the notification for this appointment
      await NotificationService.cancelAppointmentNotification(documentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Booking canceled.')));
      setState(() {
        _future = _loadMyBookings();
      });
    }
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

  String _formatDisplayFromDdMMyyyy(String ddMMyyyy) {
    final dt = DateFormat('dd-MM-yyyy').parse(ddMMyyyy);
    final weekday = DateFormat('EEEE').format(dt);
    final month = DateFormat('MMMM').format(dt);
    final year = DateFormat('y').format(dt);
    return '${dt.day} $weekday, $month, $year';
  }

  Future<void> _rescheduleAppointment(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final String currentDate = (document.data()['date'] as String?) ?? '';
    final String currentSlot = (document.data()['slot'] as String?) ?? '';
    final String currentReason = (document.data()['reason'] as String?) ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        DateTime currentMonth = DateFormat('dd-MM-yyyy').parse(currentDate);
        currentMonth = DateTime(currentMonth.year, currentMonth.month);
        List<String> tuesdaysInMonth = _getAllTuesdaysInMonth(currentMonth)
            .map((d) => DateFormat('dd-MM-yyyy').format(d))
            .toList();
        String selectedDate = tuesdaysInMonth.isNotEmpty
            ? (tuesdaysInMonth.contains(currentDate)
                ? currentDate
                : tuesdaysInMonth.first)
            : currentDate;
        List<String> unavailableSlots = [];
        bool isLoadingSlots = true;

        Future<void> loadUnavailable() async {
          final snapshot = await _firestore
              .collection('appointments')
              .where('date', isEqualTo: selectedDate)
              .get();
          unavailableSlots =
              snapshot.docs.map((d) => d.data()['slot'] as String).toList();
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> init() async {
              setModalState(() {
                isLoadingSlots = true;
              });
              await loadUnavailable();
              setModalState(() {
                isLoadingSlots = false;
              });
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (isLoadingSlots) {
                init();
              }
            });

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with close button (blue theme to match pages)
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue,
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Reschedule Appointment',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(bottomSheetContext),
                            icon: const Icon(Icons.close, color: Colors.white),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: tuesdaysInMonth.contains(selectedDate)
                                  ? selectedDate
                                  : (tuesdaysInMonth.isNotEmpty
                                      ? tuesdaysInMonth.first
                                      : null),
                              decoration: const InputDecoration(
                                labelText: 'Select Tuesday',
                                border: OutlineInputBorder(),
                              ),
                              items: tuesdaysInMonth
                                  .map((dateStr) => DropdownMenuItem<String>(
                                        value: dateStr,
                                        child: Text(_formatDisplayFromDdMMyyyy(
                                            dateStr)),
                                      ))
                                  .toList(),
                              onChanged: (value) async {
                                if (value == null) return;
                                setModalState(() {
                                  selectedDate = value;
                                  isLoadingSlots = true;
                                });
                                await loadUnavailable();
                                setModalState(() {
                                  isLoadingSlots = false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Previous month',
                            icon: const Icon(Icons.chevron_left,
                                color: Colors.blue),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            onPressed: () async {
                              setModalState(() {
                                currentMonth = DateTime(
                                    currentMonth.year, currentMonth.month - 1);
                                tuesdaysInMonth =
                                    _getAllTuesdaysInMonth(currentMonth)
                                        .map((d) =>
                                            DateFormat('dd-MM-yyyy').format(d))
                                        .toList();
                                if (tuesdaysInMonth.isNotEmpty) {
                                  selectedDate = tuesdaysInMonth.first;
                                }
                                isLoadingSlots = true;
                              });
                              await loadUnavailable();
                              setModalState(() {
                                isLoadingSlots = false;
                              });
                            },
                          ),
                          IconButton(
                            tooltip: 'Next month',
                            icon: const Icon(Icons.chevron_right,
                                color: Colors.blue),
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            onPressed: () async {
                              setModalState(() {
                                currentMonth = DateTime(
                                    currentMonth.year, currentMonth.month + 1);
                                tuesdaysInMonth =
                                    _getAllTuesdaysInMonth(currentMonth)
                                        .map((d) =>
                                            DateFormat('dd-MM-yyyy').format(d))
                                        .toList();
                                if (tuesdaysInMonth.isNotEmpty) {
                                  selectedDate = tuesdaysInMonth.first;
                                }
                                isLoadingSlots = true;
                              });
                              await loadUnavailable();
                              setModalState(() {
                                isLoadingSlots = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isLoadingSlots)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _slots.length,
                          itemBuilder: (context, index) {
                            final slot = _slots[index];
                            final isUnavailable =
                                unavailableSlots.contains(slot);
                            final isCurrent = selectedDate == currentDate &&
                                slot == currentSlot;
                            return ListTile(
                              title: Text(slot),
                              subtitle: Text(isUnavailable
                                  ? (isCurrent
                                      ? 'Your current slot'
                                      : 'Unavailable')
                                  : 'Available'),
                              trailing: isUnavailable
                                  ? const Icon(Icons.lock, color: Colors.grey)
                                  : ElevatedButton(
                                      onPressed: () async {
                                        final String email =
                                            _auth.currentUser!.email!;
                                        final String targetMonthKey =
                                            DateFormat('yyyy-MM').format(
                                          DateFormat('dd-MM-yyyy')
                                              .parse(selectedDate),
                                        );
                                        final String currentMonthKey =
                                            (document.data()['monthKey']
                                                    as String?) ??
                                                '';

                                        if (targetMonthKey != currentMonthKey) {
                                          final existingTarget =
                                              await _firestore
                                                  .collection('appointments')
                                                  .where('bookedBy',
                                                      isEqualTo: email)
                                                  .where('monthKey',
                                                      isEqualTo: targetMonthKey)
                                                  .limit(1)
                                                  .get();
                                          if (existingTarget.docs.isNotEmpty) {
                                            if (!bottomSheetContext.mounted) {
                                              return;
                                            }
                                            ScaffoldMessenger.of(
                                                    bottomSheetContext)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'You already have an appointment in that month.'),
                                              ),
                                            );
                                            return;
                                          }
                                        }

                                        await _firestore
                                            .collection('appointments')
                                            .doc(document.id)
                                            .update({
                                          'date': selectedDate,
                                          'slot': slot,
                                          'monthKey':
                                              DateFormat('yyyy-MM').format(
                                            DateFormat('dd-MM-yyyy')
                                                .parse(selectedDate),
                                          ),
                                          'reason': currentReason,
                                          'timestamp':
                                              FieldValue.serverTimestamp(),
                                        });
                                        if (!bottomSheetContext.mounted) return;
                                        Navigator.pop(bottomSheetContext);
                                        ScaffoldMessenger.of(bottomSheetContext)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Rescheduled successfully.')),
                                        );
                                        setState(() {
                                          _future = _loadMyBookings();
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Choose'),
                                    ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
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
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No bookings yet.'));
          }

          // Sort documents by timestamp if orderBy is not working due to missing index
          final sortedDocs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
          sortedDocs.sort((a, b) {
            final aTimestamp = a.data()['timestamp'] as Timestamp?;
            final bTimestamp = b.data()['timestamp'] as Timestamp?;
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            return bTimestamp.compareTo(aTimestamp); // Descending order
          });

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _loadMyBookings();
              });
              await _future;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: sortedDocs.length,
              itemBuilder: (context, index) {
                final doc = sortedDocs[index];
                final data = doc.data();
                final date = (data['date'] as String?) ?? '';
                final slot = (data['slot'] as String?) ?? '';
                final reason = (data['reason'] as String?) ?? '';
                final isBlocked = (data['isBlocked'] as bool?) == true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isBlocked ? Icons.block : Icons.event_available,
                              color: isBlocked ? Colors.red : Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slot,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDisplayFromDdMMyyyy(date),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isBlocked)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Reason for Visit:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reason.isEmpty ? 'No reason provided' : reason,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isBlocked) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _cancelAppointment(doc.id),
                                  icon: const Icon(Icons.cancel, size: 18),
                                  label: const Text('Cancel'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red[700],
                                    side: BorderSide(color: Colors.red[300]!),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _rescheduleAppointment(doc),
                                  icon: const Icon(Icons.schedule, size: 18),
                                  label: const Text('Reschedule'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
