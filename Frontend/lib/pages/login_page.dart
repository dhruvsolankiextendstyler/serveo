import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/admin_utils/admin_order_provider.dart';
import 'package:frontend/admin_widgets/admin_page.dart';
import 'package:http/http.dart';
import 'package:frontend/pages/signup_page.dart';
import 'package:frontend/utils/PageNav.dart';
import 'package:frontend/utils/auth_check.dart';
import 'package:frontend/widgets/breakbite_textbox.dart';
import 'package:provider/provider.dart';

import '../utils/api_config.dart';
import '../utils/menu_provider.dart';
import '../utils/order_provider.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController uemail;
  late final TextEditingController upass;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    uemail = TextEditingController();
    upass = TextEditingController();
  }

  @override
  void dispose() {
    uemail.dispose();
    upass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: Text(
                      "Login",
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    height: 20,
                    color: Colors.yellow,
                  ),
                  // --- THE "FILLINGS" (TextFields) ---
                  Container(
                    color: Colors.brown,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
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
                          cont: upass,
                          obscure: true,
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
                        if (_isLoading) return;

                        final String email = uemail.text.trim();
                        final String pass = upass.text; // Note: do not trim password

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
                            const SnackBar(content: Text("Please enter your password")),
                          );
                          return;
                        }

                        setState(() => _isLoading = true);
                        try {
                          User? user = await AuthCheck.login(email, pass);
                          if (user != null) {
                            final String? token = await user.getIdToken();
                            final response = await get(
                              Uri.parse("${ApiConfig.baseUrl}/user/login/"),
                              headers: {
                                "Content-Type": "application/json",
                                "Authorization": "Bearer $token",
                              },
                            );

                            if (!context.mounted) return;

                            if (response.statusCode == 200) {
                              final userData = jsonDecode(response.body);
                              if (userData['userType'] == 'normal') {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => MultiProvider(
                                      providers: [
                                        ChangeNotifierProvider(create: (_) => MenuProvider()..fetchMenu()),
                                        ChangeNotifierProvider(create: (_) => OrderProvider()),
                                      ],
                                      child: DashboardPage(uname: FirebaseAuth.instance.currentUser?.displayName ?? "User"),
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (routeContext) => ChangeNotifierProvider<AdminOrderProvider>(
                                      create: (_) => AdminOrderProvider()..fetchOrders(),
                                      child: AdminPage(),
                                    ),
                                  ),
                                );
                              }
                            } else if (response.statusCode >= 500) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Server unavailable. Please try again later.")),
                              );
                            } else {
                              String msg = "Login failed";
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
                          debugPrint("Login error: $e");
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
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                "Order Now (Sign In)",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(PageNav(child: const SignupPage()));
                      uemail.clear();
                      upass.clear();
                    },
                    child: Text(
                      "No account? Sign Up!",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}