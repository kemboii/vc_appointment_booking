import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';

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

  String _selectedDate = "";
  List<String> _bookedSlots = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = _getNextTuesdayDate();
    _loadBookedSlots();
  }

  String _getNextTuesdayDate() {
    DateTime now = DateTime.now();
    while (now.weekday != DateTime.tuesday) {
      now = now.add(const Duration(days: 1));
    }
    return DateFormat('dd-MM-yyyy').format(now);
  }

  Future<void> _loadBookedSlots() async {
    final snapshot = await _firestore
        .collection('appointments')
        .where('date', isEqualTo: _selectedDate)
        .get();

    if (!mounted) return;

    setState(() {
      _bookedSlots = snapshot.docs.map((doc) => doc['slot'] as String).toList();
    });
  }

  Future<void> _bookSlot(String slot) async {
    final userEmail = _authService.currentUser?.email;

    if (userEmail == null) return;

    final existing = await _firestore
        .collection('appointments')
        .where('userEmail', isEqualTo: userEmail)
        .where('date', isEqualTo: _selectedDate)
        .get();

    if (!mounted) return;

    if (existing.docs.isNotEmpty) {
      _showDialog("You already have a booking for that day.");
      return;
    }

    await _firestore.collection('appointments').add({
      'bookedBy': userEmail,
      'slot': slot,
      'date': _selectedDate,
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

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? "Unknown";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Appointment"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome, $email", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Available Slots for $_selectedDate",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _slots.length,
                itemBuilder: (context, index) {
                  final slot = _slots[index];
                  final isBooked = _bookedSlots.contains(slot);

                  return ListTile(
                    title: Text(slot),
                    trailing: isBooked
                        ? const Text("Booked",
                            style: TextStyle(color: Colors.red))
                        : ElevatedButton(
                            onPressed: () => _bookSlot(slot),
                            child: const Text("Book"),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
