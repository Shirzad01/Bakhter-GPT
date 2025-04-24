
/*

import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:math';
import 'otpScreen.dart';

class ResetPasswordScreen extends StatefulWidget {
  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _sendResetOTP() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => isLoading = true);

    try {
      String email = _emailController.text.trim();
      String otp = (Random().nextInt(9000) + 1000).toString();
      await _sendOTP(email, otp);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              email: email,
              password: '',
              otp: otp,
              isForReset: true,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطا در ارسال OTP: $e")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendOTP(String email, String otp) async {
    String username = 'haroonshirzad333@gmail.com';
    String password = 'ggpztsiiengimpcq';

    final smtpServer = gmail(username, password);

    final message = Message()
      ..from = Address(username, 'Bashiri LearnAI')
      ..recipients.add(email)
      ..subject = 'Your OTP Code for Password Reset'
      ..text = 'Your OTP code is $otp. It is valid for 5 minutes.'
      ..html = '<h3>Your OTP Code</h3><p>Your OTP code is <b>$otp</b>. It is valid for 5 minutes.</p>';

    try {
      final sendReport = await send(message, smtpServer);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("کد OTP به ایمیل شما فرستاده شد!")),
      );
    } catch (e) {
      throw Exception("خطا در ارسال OTP: $e");
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
                      "ریست رمز عبور",
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
                        controller: _emailController,
                        style: TextStyle(color: Colors.white, fontSize: baseFontSize),
                        decoration: InputDecoration(
                          hintText: "ایمیل خود را وارد کنید",
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(Icons.email, color: Color(0xFFD8B5FF)),
                          border: InputBorder.none,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "لطفاً ایمیل را وارد کنید";
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return "ایمیل نامعتبر است";
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(height: basePadding * 2),
                    isLoading
                        ? CircularProgressIndicator()
                        : ElevatedButton(
                      onPressed: _sendResetOTP,
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
