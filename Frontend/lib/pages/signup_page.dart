import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:frontend/utils/api_config.dart';
import 'package:frontend/utils/auth_check.dart';
import 'package:frontend/widgets/breakbite_textbox.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late final TextEditingController uname;
  late final TextEditingController uemail;
  late final TextEditingController upass;
  late final TextEditingController unum;

  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    uname = TextEditingController();
    uemail = TextEditingController();
    upass = TextEditingController();
    unum = TextEditingController();
  }

  @override
  void dispose() {
    uname.dispose();
    uemail.dispose();
    upass.dispose();
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
                        ServeoTextBox(
                          hint: "Full Name",
                          icon: Icons.person,
                          cont: uname,
                        ),
                        const SizedBox(height: 10),
                        ServeoTextBox(
                          hint: "Email",
                          icon: Icons.email,
                          keyboard: TextInputType.emailAddress,
                          cont: uemail,
                        ),
                        const SizedBox(height: 10),
                        ServeoTextBox(
                          hint: "Password",
                          icon: Icons.password,
                          obscure: true,
                          cont: upass,
                        ),
                        const SizedBox(height: 10),
                        ServeoTextBox(
                          hint: "Phone Number",
                          icon: Icons.phone,
                          keyboard: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                          cont: unum,
                        ),
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
                        final String pass = upass.text; // Note: do not trim password
                        final String phone = unum.text.trim();

                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter your full name")),
                          );
                          return;
                        }

                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter your email")),
                          );
                          return;
                        }

                        final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                        if (!emailRegex.hasMatch(email)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter a valid email address")),
                          );
                          return;
                        }

                        if (pass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter a password")),
                          );
                          return;
                        }

                        if (pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Password must be at least 6 characters long")),
                          );
                          return;
                        }

                        if (phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter your phone number")),
                          );
                          return;
                        }

                        if (phone.length < 10 || phone.length > 15) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter a valid phone number (10 to 15 digits)")),
                          );
                          return;
                        }

                        setState(() => _isRegistering = true);
                        try {
                          User? user = await AuthCheck.signUp(email, pass, name);

                          if (user != null) {
                            String? token = await user.getIdToken();

                            final response = await post(
                              Uri.parse("${ApiConfig.baseUrl}/user/signup"),
                              headers: {
                                "Content-Type": "application/json",
                                "Authorization": "Bearer $token",
                              },
                              body: jsonEncode({
                                "uname": name,
                                "uemail": email,
                                "upass": pass,
                                "upnum": phone,
                              }),
                            );

                            if (!context.mounted) return;

                            if (response.statusCode == 200 || response.statusCode == 201) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Account created successfully! Please login.")),
                              );
                              Navigator.of(context).pop();
                            } else if (response.statusCode >= 500) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Server unavailable. Please try again later.")),
                              );
                            } else {
                              String msg = "Registration failed";
                              try {
                                final body = jsonDecode(response.body);
                                if (body is Map && body.containsKey("message")) {
                                  msg = body["message"].toString();
                                }
                              } catch (_) {}
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(msg)),
                              );
                            }
                          }
                        } on FirebaseAuthException catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AuthCheck.getFirebaseAuthErrorMessage(e))),
                          );
                        } on ClientException catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Network connection failed. Please check your internet connection.")),
                          );
                        } on TimeoutException catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Server timed out. Please try again later.")),
                          );
                        } catch (e) {
                          debugPrint("Signup error: $e");
                          if (!context.mounted) return;
                          final errStr = e.toString().toLowerCase();
                          if (errStr.contains("socketexception") || errStr.contains("network") || errStr.contains("connection")) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Network connection failed. Please check your internet connection.")),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("An unexpected error occurred. Please try again.")),
                            );
                          }
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