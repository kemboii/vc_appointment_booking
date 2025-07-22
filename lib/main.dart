import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_screen.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(DevicePreview(
    enabled: true, // Set to true for development preview
    builder: (context) => const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  bool isAdmin(String email) {
    // You can update this to check from Firestore later
    return email == 'secretary@ueab.ac.ke';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "UEAB VC Appointment Booking",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/admin': (context) => const AdminPage(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData) {
            final user = snapshot.data!;
            if (isAdmin(user.email ?? "")) {
              return const AdminPage();
            } else {
              return const HomePage();
            }
          } else {
            return const LoginPage();
          }
        },
      ),
      // Enable Device Preview locale and media query support
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }
}
