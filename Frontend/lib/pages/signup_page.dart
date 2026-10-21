import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:frontend/utils/api_config.dart';
import 'package:frontend/utils/auth_check.dart';
import 'package:frontend/widgets/breakbite_textbox.dart';

// 1. Change to StatefulWidget
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // 2. Define controllers here
  late final TextEditingController uname;
  late final TextEditingController uemail;
  late final TextEditingController upass;
  late final TextEditingController usap;
  late final TextEditingController unum;

  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    // 3. Initialize them when the widget starts
    uname = TextEditingController();
    uemail = TextEditingController();
    upass = TextEditingController();
    usap = TextEditingController();
    unum = TextEditingController();
  }

  @override
  void dispose() {
    // 4. Dispose them AUTOMATICALLY when the screen closes
    uname.dispose();
    uemail.dispose();
    upass.dispose();
    usap.dispose();
    unum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: SizedBox(
              width: screenWidth > 600 ? 400 : screenWidth * 0.9,
              child: Column(
                children: [
                  // --- TOP BUN ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD99058),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(80)),
                      boxShadow: [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
                      ],
                    ),
                    child: Text(
                      "Register",
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // --- CHEESE LAYER ---
                  Container(height: 15, color: Colors.yellowAccent),

                  // --- MAIN FILLINGS ---
                  Container(
                    color: Colors.brown,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ServeoTextBox(hint: "Full Name", icon: Icons.person, cont: uname),
                        const SizedBox(height: 10),
                        ServeoTextBox(hint: "Email", icon: Icons.email, keyboard: TextInputType.emailAddress, cont: uemail),
                        const SizedBox(height: 10),
                        ServeoTextBox(hint: "Password", icon: Icons.password, cont: upass),
                        const SizedBox(height: 10),
                        ServeoTextBox(hint: "Phone Number", icon: Icons.phone, keyboard: TextInputType.phone, cont: unum),
                        const SizedBox(height: 10),
                        ServeoTextBox(hint: "SAP id", icon: Icons.badge, keyboard: TextInputType.number, cont: usap),
                      ],
                    ),
                  ),

                  // --- BOTTOM BUN ---
                  Material(
                    color: const Color(0xFFA66D42),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        if (_isRegistering) return;
                        final String name = uname.text.trim();
                        final String email = uemail.text.trim();
                        final String pass = upass.text.trim();
                        final String phone = unum.text.trim();
                        final String sap = usap.text.trim();

                        if (name.isEmpty || email.isEmpty || pass.isEmpty || phone.isEmpty || sap.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please fill in all fields")),
                          );
                          return;
                        }
                        if (!email.contains("@") || !email.contains(".")) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter a valid email address")),
                          );
                          return;
                        }
                        if (pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Password must be at least 6 characters")),
                          );
                          return;
                        }

                        setState(() => _isRegistering = true);
                        try {
                          User? user = await AuthCheck.signUp(email, pass, name);

                          if (user != null) {
                            String? token = await user.getIdToken();

                            // NOTE: Use 10.0.2.2 if on Android Emulator
                            final response = await post(
                                Uri.parse("${ApiConfig.baseUrl}/user/signup"),
                                headers: {
                                  "Content-Type": "application/json",
                                  "Authorization": "Bearer $token"
                                },
                                body: jsonEncode({
                                  "uname": name,
                                  "uemail": email,
                                  "upass": pass,
                                  "upnum": phone,
                                  "usap": sap,
                                })
                            );

                            if (!context.mounted) return;

                            if (response.statusCode == 200 || response.statusCode == 201) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("User Created: ${user.email}")),
                              );
                              Navigator.of(context).pop();
                              // No need to manually clear/dispose here.
                              // The dispose() method above handles it.
                            } else {
                              String msg = response.body;
                              try { msg = jsonDecode(response.body)["message"] ?? msg; } catch (_) {}
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Signup failed: $msg")),
                              );
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          if (!context.mounted) return;
                          const messages = {
                            "email-already-in-use": "An account with this email already exists.",
                            "invalid-email": "Please enter a valid email address.",
                            "weak-password": "Password must be at least 6 characters.",
                            "network-request-failed": "Network error. Check your connection and try again.",
                            "too-many-requests": "Too many attempts. Please try again later.",
                          };
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(messages[e.code] ?? "Signup failed: ${e.message ?? e.code}")),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        } finally {
                          if (mounted) setState(() => _isRegistering = false);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 25),
                        child: _isRegistering
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                "Create Account",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                  ),

                  // --- FOOTER ---
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      "Already have an account? Login",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}