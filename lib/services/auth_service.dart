import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vc_appointment_booking/utils/admin_emails.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up
  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String? studentId, // Parent: student they are parent to
    String? schoolId, // Student
    String? school, // Student
    String? department, // Student
    String? jobRole, // Staff Member
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      // Store additional user info in Firestore
      if (user != null) {
        final Map<String, dynamic> userDoc = {
          'name': name,
          'email': email,
          'role': role,
        };

        if (role == 'Parent') {
          if (studentId != null && studentId.trim().isNotEmpty) {
            userDoc['studentId'] = studentId.trim();
          }
        } else if (role == 'Student') {
          if (schoolId != null && schoolId.trim().isNotEmpty) {
            userDoc['schoolId'] = schoolId.trim();
          }
          if (school != null && school.trim().isNotEmpty) {
            userDoc['school'] = school.trim();
          }
          if (department != null && department.trim().isNotEmpty) {
            userDoc['department'] = department.trim();
          }
        } else if (role == 'Staff Member') {
          if (jobRole != null && jobRole.trim().isNotEmpty) {
            userDoc['jobRole'] = jobRole.trim();
          }
        }

        await _firestore.collection('users').doc(user.uid).set(userDoc);

        // Sign in the user after a successful registration
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      return null; // No error
    } on FirebaseAuthException catch (e) {
      // Return the Firebase error message, or the exception as string if null
      return e.message ?? e.toString();
    } catch (e) {
      // Return any other error as string
      return e.toString();
    }
  }

// Returns null on success, error message on failure
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'An unknown Firebase error occurred';
    } catch (e) {
      return 'Sign in failed: ${e.toString()}';
    }
  }

  // Sign out
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await _auth.signOut();
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Check if the user's email is in the adminEmails list
    if (adminEmails.contains(user.email)) {
      return true;
    }

    // As a fallback, check the user's role in Firestore
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?['role'] == 'admin';
  }
}
