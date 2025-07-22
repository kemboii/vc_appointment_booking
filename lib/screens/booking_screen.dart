import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _selectedDate = DateTime.now();
  final List<String> _slots = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
  ];

  Future<void> _bookSlot(String slot) async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to book a slot.')),
      );
      return;
    }

    final formattedDate =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    // Check if slot is already booked
    final existing = await _firestore
        .collection('appointments')
        .where('date', isEqualTo: formattedDate)
        .where('slot', isEqualTo: slot)
        .get();

    if (!mounted) return;

    if (existing.docs.isNotEmpty && existing.docs.first['isBooked'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This slot is already booked.')),
      );
      return;
    }

    // Add or update the appointment
    if (existing.docs.isEmpty) {
      await _firestore.collection('appointments').add({
        'date': formattedDate,
        'slot': slot,
        'isBooked': true,
        'bookedBy': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore
          .collection('appointments')
          .doc(existing.docs.first.id)
          .update({
        'isBooked': true,
        'bookedBy': user.email ?? 'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Slot $slot booked for $formattedDate!')),
    );
    setState(() {}); // Refresh UI
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            "Select Date:",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
              onDateChanged: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Available Slots for $formattedDate",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _firestore
                  .collection('appointments')
                  .where('date', isEqualTo: formattedDate)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bookedSlots = <String, dynamic>{};
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    bookedSlots[doc['slot']] = doc.data();
                  }
                }
                return ListView.builder(
                  itemCount: _slots.length,
                  itemBuilder: (context, index) {
                    final slot = _slots[index];
                    final isBooked = bookedSlots[slot]?['isBooked'] == true;
                    final bookedBy = bookedSlots[slot]?['bookedBy'];
                    return ListTile(
                      title: Text(slot),
                      subtitle: isBooked
                          ? Text('Booked by: $bookedBy',
                              style: const TextStyle(color: Colors.red))
                          : const Text('Available',
                              style: TextStyle(color: Colors.green)),
                      trailing: isBooked
                          ? const Icon(Icons.lock, color: Colors.grey)
                          : ElevatedButton(
                              onPressed: () => _bookSlot(slot),
                              child: const Text('Book'),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
