class Validators {
  // Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    return null;
  }

  // Validate email with role-specific domain requirements
  static String? validateEmailWithRole(String? value, String? role) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }

    final email = value.trim().toLowerCase();
    
    // Check domain requirements based on role
    if (role == 'Student' || role == 'Staff Member') {
      if (!email.endsWith('@ueab.ac.ke')) {
        return 'Students and Staff must use their UEAB email (@ueab.ac.ke)';
      }
    }
    // Parents can use any valid email address

    return null;
  }

  // Validate password strength
  static String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }

    if (value.trim().length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  // Validate full name
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }

    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters';
    }

    return null;
  }
}
