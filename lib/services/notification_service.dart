import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  static Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? granted = await androidImplementation?.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<void> scheduleAppointmentReminder({
    required String appointmentId,
    required DateTime appointmentDateTime,
    required String slot,
    required String reason,
    int minutesBefore = 30,
  }) async {
    final reminderTime = appointmentDateTime.subtract(Duration(minutes: minutesBefore));
    
    // Don't schedule if reminder time is in the past
    if (reminderTime.isBefore(DateTime.now())) {
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'appointment_reminders',
      'Appointment Reminders',
      channelDescription: 'Notifications for upcoming VC appointments',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      appointmentId.hashCode,
      'Appointment Reminder',
      'Your VC appointment ($slot) is in $minutesBefore minutes.\nReason: $reason',
      details,
    );
  }


  static Future<void> cancelAppointmentNotification(String appointmentId) async {
    await _notifications.cancel(appointmentId.hashCode);
  }

  static Future<void> scheduleNotificationsForUserAppointments() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Get user's upcoming appointments
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    final appointments = await _firestore
        .collection('appointments')
        .where('bookedBy', isEqualTo: user.email)
        .where('date', isGreaterThanOrEqualTo: todayStr)
        .get();

    for (final doc in appointments.docs) {
      final data = doc.data();
      final dateStr = data['date'] as String;
      final slot = data['slot'] as String;
      final reason = data['reason'] as String? ?? 'No reason provided';
      
      // Parse appointment date and time
      final appointmentDate = DateFormat('yyyy-MM-dd').parse(dateStr);
      final timeStr = slot.split(' - ')[0]; // Get start time
      final appointmentTime = _parseTimeString(timeStr);
      
      final appointmentDateTime = DateTime(
        appointmentDate.year,
        appointmentDate.month,
        appointmentDate.day,
        appointmentTime.hour,
        appointmentTime.minute,
      );

      // Schedule notifications at different intervals
      await scheduleAppointmentReminder(
        appointmentId: doc.id,
        appointmentDateTime: appointmentDateTime,
        slot: slot,
        reason: reason,
        minutesBefore: 30, // 30 minutes before
      );
    }
  }

  static DateTime _parseTimeString(String timeStr) {
    // Parse time like "9:00 AM" or "10:15 AM"
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minutePart = parts[1].split(' ');
    final minute = int.parse(minutePart[0]);
    final amPm = minutePart[1];
    
    int finalHour = hour;
    if (amPm.toUpperCase() == 'PM' && hour != 12) {
      finalHour += 12;
    } else if (amPm.toUpperCase() == 'AM' && hour == 12) {
      finalHour = 0;
    }
    
    return DateTime(2000, 1, 1, finalHour, minute);
  }

  static Future<void> showNotificationPreference() async {
    // This will be called to ask user if they want notifications
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'notification_setup',
      'Notification Setup',
      channelDescription: 'Setup notifications for appointments',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      999,
      'Enable Appointment Reminders?',
      'Tap to set up notifications for your upcoming VC appointments',
      details,
    );
  }
}
