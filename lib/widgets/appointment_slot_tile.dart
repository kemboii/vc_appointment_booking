import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppointmentSlotTile extends StatefulWidget {
  final DateTime slotTime;

  const AppointmentSlotTile({super.key, required this.slotTime});
  //                ^^^^^^^^
  @override
  State<AppointmentSlotTile> createState() => _AppointmentSlotTileState();
}

class _AppointmentSlotTileState extends State<AppointmentSlotTile> {
  bool isBooked = false;
  String? bookedBy;

  @override
  void initState() {
    super.initState();
    checkIfBooked();
  }

  Future<void> checkIfBooked() async {
    final query = await FirebaseFirestore.instance
        .collection('appointments')
        .where('appointmentTime', isEqualTo: widget.slotTime)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      setState(() {
        isBooked = true;
        bookedBy = query.docs.first.data()['email'];
      });
    }
  }

  Future<void> bookSlot() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to book.")),
      );
      return;
    }
    setState(() {
      isBooked = true;
      bookedBy = user.email;
    });

    await FirebaseFirestore.instance.collection('appointments').add({
      'userId': user.uid,
      'bookedBy': user.email,
      'fullName': user.displayName ?? "No Name",
      'appointmentTime': widget.slotTime,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'booked',
    });

    if (!mounted) return; // <-- Add this line

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              "Appointment booked at ${DateFormat.jm().format(widget.slotTime)}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat.jm().format(widget.slotTime);

    return ListTile(
      title: Text("Slot: $timeText"),
      subtitle: isBooked
          ? Text("Booked by: $bookedBy",
              style: const TextStyle(color: Colors.red))
          : const Text("Available", style: TextStyle(color: Colors.green)),
      trailing: isBooked
          ? const Icon(Icons.lock, color: Colors.grey)
          : ElevatedButton(
              onPressed: bookSlot,
              child: const Text("Book"),
            ),
    );
  }
}
