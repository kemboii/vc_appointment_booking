import 'package:flutter/material.dart';
import 'package:vc_appointment_booking/services/auth_service.dart';
import 'package:vc_appointment_booking/app.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  final _studentIdController = TextEditingController(); // Parent: student's ID
  final _schoolIdController = TextEditingController(); // Student
  final _schoolController = TextEditingController(); // Student
  final _departmentController = TextEditingController(); // Student
  final _jobRoleController = TextEditingController(); // Staff Member

  String? _selectedRole;
  final List<String> _roles = ['Staff Member', 'Student', 'Parent'];

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null) {
      setState(() {
        _errorMessage = 'Please select a role.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final result = await _authService.signUp(
      name: name,
      email: email,
      password: password,
      role: _selectedRole!,
      studentId:
          _selectedRole == 'Parent' ? _studentIdController.text.trim() : null,
      schoolId:
          _selectedRole == 'Student' ? _schoolIdController.text.trim() : null,
      school: _selectedRole == 'Student' ? _schoolController.text.trim() : null,
      department:
          _selectedRole == 'Student' ? _departmentController.text.trim() : null,
      jobRole: _selectedRole == 'Staff Member'
          ? _jobRoleController.text.trim()
          : null,
    );

    if (!mounted) return; // Prevents using context if widget is disposed

    setState(() {
      _isLoading = false;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Registration successful. Please log in.')),
      );
      // Let the auth state stream drive navigation. Simply pop back if possible.
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } else {
      debugPrint('Registration error: $result');
      setState(() {
        _errorMessage = result;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    _schoolIdController.dispose();
    _schoolController.dispose();
    _departmentController.dispose();
    _jobRoleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const AppHeader(),
                const SizedBox(height: 16),
                const Text(
                  "Create Account",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value != null && value.isNotEmpty
                      ? null
                      : "Enter your full name",
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value != null && value.contains('@')
                      ? null
                      : "Enter a valid email",
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) => value != null && value.length >= 6
                      ? null
                      : "Password must be at least 6 characters",
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  hint: const Text('Select Role'),
                  decoration: const InputDecoration(
                    labelText: "Role",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                  items: _roles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    );
                  }).toList(),
                  validator: (value) =>
                      value == null ? 'Please select a role' : null,
                ),
                if (_selectedRole == 'Parent') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _studentIdController,
                    decoration: const InputDecoration(
                      labelText: "Student ID (your child)",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value != null && value.trim().isNotEmpty
                            ? null
                            : "Enter the student's ID",
                  ),
                ],
                if (_selectedRole == 'Student') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _schoolIdController,
                    decoration: const InputDecoration(
                      labelText: "School ID",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value != null && value.trim().isNotEmpty
                            ? null
                            : "Enter your school ID",
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _schoolController,
                    decoration: const InputDecoration(
                      labelText: "School",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value != null && value.trim().isNotEmpty
                            ? null
                            : "Enter your school",
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: "Department",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value != null && value.trim().isNotEmpty
                            ? null
                            : "Enter your department",
                  ),
                ],
                if (_selectedRole == 'Staff Member') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _jobRoleController,
                    decoration: const InputDecoration(
                      labelText: "Job Role (e.g. Lecturer, HOD)",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value != null && value.trim().isNotEmpty
                            ? null
                            : "Enter your job role",
                  ),
                ],
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text("Register"),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushNamed(context, '/login');
                    }
                  },
                  child: const Text("Already have an account? Login here"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
