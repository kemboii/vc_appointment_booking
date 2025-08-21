import 'package:flutter/material.dart';

/// App-wide constants and styles
class AppConstants {
  // App
  static const String appTitle = 'UEAB VC Appointment Booking';

  // Colors
  static const Color primaryColor = Colors.blue;
  static const Color secondaryColor = Colors.lightBlueAccent;
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color textColor = Colors.black87;

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String appointmentsCollection = 'appointments';

  // Padding and spacing
  static const double defaultPadding = 16.0;

  // Border radius
  static const BorderRadius defaultBorderRadius =
      BorderRadius.all(Radius.circular(8));

  // Font styles
  static const TextStyle headingStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: textColor,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );
}
