/*

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // فرض می‌کنم ChatScreen اینجاست

class CreateNewPasswordScreen extends StatefulWidget {
  final String email;

  CreateNewPasswordScreen({required this.email});

  @override
  _CreateNewPasswordScreenState createState() => _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => isLoading = true);

    try {
      String newPassword = _passwordController.text;

      // چک می‌کنیم که کاربر وجود داره
      try {
        // برای ریست پسورد، از لینک ریست استفاده می‌کنیم
        await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "لینک ریست رمز به ایمیل ${widget.email} فرستاده شد. لطفاً ایمیل خود را چک کنید.",
            ),
          ),
        );
        // برمی‌گردیم به صفحه لاگین
        if (mounted) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (e) {
        // اگه ایمیل ثبت‌نشده باشه، اکانت جدید می‌سازیم
        if (e.toString().contains('user-not-found')) {
          UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: widget.email,
            password: newPassword,
          );
          await userCredential.user?.sendEmailVerification();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("اکانت جدید ساخته شد! لطفاً ایمیل خود را تأیید کنید.")),
          );
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(studentId: userCredential.user!.uid),
              ),
            );
          }
        } else {
          throw e;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطا: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseFontSize = screenWidth * 0.04;
    final baseIconSize = screenWidth * 0.08;
    final basePadding = screenWidth * 0.04;
    final baseBorderRadius = screenWidth * 0.06;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Color(0xFF1A0F2B),
              Color(0xFF2A1B3D),
              Color(0xFF44318D).withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(basePadding * 2),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "ساخت رمز جدید",
                      style: TextStyle(
                        fontSize: baseFontSize * 1.6,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: basePadding * 2),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: basePadding * 0.8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(baseBorderRadius * 0.7),
                        border: Border.all(
                          color: Color(0xFF8EC5FC).withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: Colors.white, fontSize: baseFontSize),
                        decoration: InputDecoration(
                          hintText: "رمز جدید",
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(Icons.lock, color: Color(0xFFD8B5FF)),
                          border: InputBorder.none,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "لطفاً رمز جدید را وارد کنید";
                          }
                          if (value.length < 6) {
                            return "رمز باید حداقل 6 کاراکتر باشد";
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: basePadding),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: basePadding * 0.8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(baseBorderRadius * 0.7),
                        border: Border.all(
                          color: Color(0xFF8EC5FC).withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        style: TextStyle(color: Colors.white, fontSize: baseFontSize),
                        decoration: InputDecoration(
                          hintText: "تأیید رمز جدید",
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(Icons.lock, color: Color(0xFFD8B5FF)),
                          border: InputBorder.none,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "لطفاً رمز را تأیید کنید";
                          }
                          if (value != _passwordController.text) {
                            return "رمزها مطابقت ندارند";
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: basePadding * 2),
                    isLoading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _updatePassword,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: basePadding * 1.1,
                          horizontal: basePadding * 2,
                        ),
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(baseBorderRadius),
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFD8B5FF),
                              Color(0xFF8EC5FC),
                              Color(0xFFD8B5FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(baseBorderRadius),
                        ),
                        child: Center(
                          child: Text(
                            "تأیید",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: baseFontSize * 1.3,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
 */
