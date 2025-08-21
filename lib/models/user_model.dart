class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String role;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
  });

  // Convert a UserModel into a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role,
    };
  }

  // Create a UserModel from a Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
    );
  }
}
