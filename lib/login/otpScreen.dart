import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Assuming ChatScreen is here

typedef SendOtpCallback = Future<void> Function(String email, String otp);

class OTPScreen extends StatefulWidget {
  final String email;
  final String password; // Ignored
  final String otp;
  final bool isForReset;
  final SendOtpCallback onResendOtp; // Callback برای Resend

  OTPScreen({
    required this.email,
    required this.password,
    required this.otp,
    required this.isForReset,
    required this.onResendOtp,
  });

  @override
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> with TickerProviderStateMixin {
  final TextEditingController _otpController1 = TextEditingController();
  final TextEditingController _otpController2 = TextEditingController();
  final TextEditingController _otpController3 = TextEditingController();
  final TextEditingController _otpController4 = TextEditingController();
  final FocusNode _focusNode1 = FocusNode();
  final FocusNode _focusNode2 = FocusNode();
  final FocusNode _focusNode3 = FocusNode();
  final FocusNode _focusNode4 = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  late String _currentOtp; // برای آپدیت OTP
  late AnimationController _animationController1;
  late AnimationController _animationController2;
  late AnimationController _animationController3;
  late AnimationController _animationController4;
  late Animation<double> _fadeAnimation1;
  late Animation<double> _fadeAnimation2;
  late Animation<double> _fadeAnimation3;
  late Animation<double> _fadeAnimation4;
  late Animation<Offset> _slideAnimation1;
  late Animation<Offset> _slideAnimation2;
  late Animation<Offset> _slideAnimation3;
  late Animation<Offset> _slideAnimation4;

  @override
  void initState() {
    super.initState();
    _currentOtp = widget.otp; // مقدار اولیه OTP

    // Initialize animation controllers
    _animationController1 = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _animationController2 = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _animationController3 = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _animationController4 = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    // Fade animations
    _fadeAnimation1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController1, curve: Curves.easeInOut),
    );
    _fadeAnimation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController2, curve: Curves.easeInOut),
    );
    _fadeAnimation3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController3, curve: Curves.easeInOut),
    );
    _fadeAnimation4 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController4, curve: Curves.easeInOut),
    );

    // Slide animations
    _slideAnimation1 = Tween<Offset>(
      begin: Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController1, curve: Curves.easeInOut),
    );
    _slideAnimation2 = Tween<Offset>(
      begin: Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController2, curve: Curves.easeInOut),
    );
    _slideAnimation3 = Tween<Offset>(
      begin: Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController3, curve: Curves.easeInOut),
    );
    _slideAnimation4 = Tween<Offset>(
      begin: Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController4, curve: Curves.easeInOut),
    );

    // Listen to controller changes to trigger animations
    _otpController1.addListener(() {
      if (_otpController1.text.isNotEmpty) {
        _animationController1.forward();
      } else {
        _animationController1.reverse();
      }
    });
    _otpController2.addListener(() {
      if (_otpController2.text.isNotEmpty) {
        _animationController2.forward();
      } else {
        _animationController2.reverse();
      }
    });
    _otpController3.addListener(() {
      if (_otpController3.text.isNotEmpty) {
        _animationController3.forward();
      } else {
        _animationController3.reverse();
      }
    });
    _otpController4.addListener(() {
      if (_otpController4.text.isNotEmpty) {
        _animationController4.forward();
      } else {
        _animationController4.reverse();
      }
    });
  }

  void _verifyOTP() async {
    if (!_formKey.currentState!.validate()) {
      print('فرم معتبر نیست');
      return;
    }

    String enteredOTP =
        "${_otpController1.text}${_otpController2.text}${_otpController3.text}${_otpController4.text}";
    print('کد واردشده: $enteredOTP, کد انتظار: $_currentOtp');

    if (!mounted) {
      print('ویجت mounted نیست');
      return;
    }
    setState(() => isLoading = true);

    try {
      if (enteredOTP == _currentOtp) {
        print('OTP درست است, isForReset: ${widget.isForReset}');
        if (widget.isForReset) {
          if (!mounted) return;
          print('رفت به حالت reset password');
          _showCustomSnackBar(
            context,
            "Password reset is disabled.",
            isError: true,
          );
        } else {
          print('شروع چک Firestore برای ایمیل: ${widget.email}');
          var userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.email)
              .get();

          String userId;

          if (userDoc.exists) {
            print('کاربر پیدا شد: ${userDoc.data()}');
            userId = userDoc.data()?['uid'] as String? ?? '';
            if (userId.isEmpty) {
              print('UID خالیه');
              throw Exception("User ID not found in Firestore.");
            }
            print('لاگین ناشناس');
            await FirebaseAuth.instance.signInAnonymously();
          } else {
            print('کاربر جدید, ساخت حساب ناشناس');
            UserCredential userCredential =
            await FirebaseAuth.instance.signInAnonymously();
            User? user = userCredential.user;

            if (user != null) {
              userId = user.uid;
              print('ذخیره کاربر جدید در Firestore: $userId');
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.email)
                  .set({
                'email': widget.email,
                'uid': userId,
                'createdAt': FieldValue.serverTimestamp(),
                'lastLogin': FieldValue.serverTimestamp(),
              });
            } else {
              print('خطا: کاربر ناشناس ساخته نشد');
              throw Exception("Failed to create anonymous user.");
            }
          }

          if (!mounted) {
            print('ویجت mounted نیست قبل از رفتن به ChatScreen');
            return;
          }
          print('رفتن به ChatScreen با userId: $userId');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                studentId: userId,
              ),
            ),
          );
        }
      } else {
        if (!mounted) {
          print('ویجت mounted نیست برای خطای OTP');
          return;
        }
        print('OTP اشتباهه');
        _showCustomSnackBar(
          context,
          "Incorrect OTP. Please try again.",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) {
        print('ویجت mounted نیست برای catch');
        return;
      }
      print('خطا توی verify: $e');
      _showCustomSnackBar(
        context,
        "Error: $e",
        isError: true,
      );
    } finally {
      if (!mounted) {
        print('ویجت mounted نیست برای finally');
        return;
      }
      print('پایان verify, isLoading=false');
      setState(() => isLoading = false);
    }
  }
  void _showCustomSnackBar(BuildContext context, String message,
      {required bool isError}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseFontSize = screenWidth * 0.04;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(
          horizontal: baseFontSize * 2,
          vertical: baseFontSize * 5,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: Duration(seconds: 3),
        content: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(
            vertical: baseFontSize * 0.5,
            horizontal: baseFontSize,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isError
                  ? [Colors.redAccent, Colors.red]
                  : [Colors.greenAccent, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: baseFontSize * 1.5,
              ),
              SizedBox(width: baseFontSize),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: baseFontSize * 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        animation: CurvedAnimation(
          parent: AnimationController(
            vsync: this,
            duration: Duration(milliseconds: 500),
          )..forward(),
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otpController1.dispose();
    _otpController2.dispose();
    _otpController3.dispose();
    _otpController4.dispose();
    _focusNode1.dispose();
    _focusNode2.dispose();
    _focusNode3.dispose();
    _focusNode4.dispose();
    _animationController1.dispose();
    _animationController2.dispose();
    _animationController3.dispose();
    _animationController4.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseFontSize = screenWidth * 0.04;
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
            Color(0xFF6B46C1).withOpacity(0.9),
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
                    "Verify Your Code",
                    style: TextStyle(
                      fontSize: baseFontSize * 1.8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: basePadding),
                  Text(
                    "We've sent a 4-digit code to ${widget.email}. Enter it below to continue.",
                    style: TextStyle(
                      fontSize: baseFontSize * 1.1,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: basePadding * 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOtpField(
                          _otpController1, _focusNode1, _focusNode2, 1),
                      SizedBox(width: basePadding),
                      _buildOtpField(
                          _otpController2, _focusNode2, _focusNode3, 2),
                      SizedBox(width: basePadding),
                      _buildOtpField(
                          _otpController3, _focusNode3, _focusNode4, 3),
                      SizedBox(width: basePadding),
                      _buildOtpField(_otpController4, _focusNode4, null, 4),
                    ],
                  ),
                  SizedBox(height: basePadding * 0.5),
                  SizedBox(height: basePadding * 0.5),
                  SizedBox(height: basePadding * 0.5),
                  TextButton(
                    onPressed: () async {
                      if (!mounted) return; // چک اولیه
                      setState(() => isLoading = true);
                      try {
                        String newOtp =
                        (1000 + Random().nextInt(9000)).toString();
                        await widget.onResendOtp(widget.email, newOtp);
                        if (!mounted) return; // چک قبل از آپدیت UI
                        setState(() {
                          _currentOtp = newOtp;
                        });
                        _showCustomSnackBar(
                          context,
                          "New OTP sent to ${widget.email}",
                          isError: false,
                        );
                      } catch (e) {
                        if (!mounted) return; // چک قبل از اسنک‌بار خطا
                        _showCustomSnackBar(
                          context,
                          "Error sending OTP: $e",
                          isError: true,
                        );
                      } finally {
                        if (!mounted) return; // چک قبل از آپدیت نهایی
                        setState(() => isLoading = false);
                      }
                    },
                    child: Text(
                      "Resend OTP",
                      style: TextStyle(
                        fontSize: baseFontSize * 0.9,
                        color: Color(0xFF8EC5FC),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: basePadding),
                  Text(
                    "Didn't receive the code? Check your spam/junk folder.",
                    style: TextStyle(
                      fontSize: baseFontSize * 0.8,
                      color: Color(0xFFD8B5FF),
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: basePadding * 3),
                  isLoading
                      ? CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : ElevatedButton(
                          onPressed: _verifyOTP,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(baseBorderRadius),
                            ),
                            elevation: 8,
                            shadowColor: Colors.black45,
                          ),
                          child: Container(
                            width: screenWidth * 0.5,
                            padding: EdgeInsets.symmetric(
                              vertical: basePadding * 1.01,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFD8B5FF),
                                  Color(0xFF8EC5FC),
                                  Color(0xFFD8B5FF),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.circular(baseBorderRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "Verify Code",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: baseFontSize * 1.1,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
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
    ));
  }

  Widget _buildOtpField(TextEditingController controller, FocusNode focusNode,
      FocusNode? nextFocus, int fieldIndex) {
    final screenWidth = MediaQuery.of(context).size.width;
    final baseFontSize = screenWidth * 0.04;
    final basePadding = screenWidth * 0.04;

    Animation<double> fadeAnimation;
    Animation<Offset> slideAnimation;

    switch (fieldIndex) {
      case 1:
        fadeAnimation = _fadeAnimation1;
        slideAnimation = _slideAnimation1;
        break;
      case 2:
        fadeAnimation = _fadeAnimation2;
        slideAnimation = _slideAnimation2;
        break;
      case 3:
        fadeAnimation = _fadeAnimation3;
        slideAnimation = _slideAnimation3;
        break;
      case 4:
      default:
        fadeAnimation = _fadeAnimation4;
        slideAnimation = _slideAnimation4;
        break;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([fadeAnimation, slideAnimation, focusNode]),
      builder: (context, child) {
        return Transform.scale(
          scale: focusNode.hasFocus ? 1.1 : 1.0,
          child: Opacity(
            opacity: controller.text.isEmpty ? 0.5 : fadeAnimation.value,
            child: SlideTransition(
              position: slideAnimation,
              child: Container(
                width: screenWidth * 0.15,
                height: screenWidth * 0.15,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: focusNode.hasFocus
                        ? Color(0xFFD8B5FF)
                        : Color(0xFF8EC5FC).withOpacity(0.5),
                    width: focusNode.hasFocus ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFD8B5FF)
                          .withOpacity(focusNode.hasFocus ? 0.4 : 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: baseFontSize * 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLength: 1,
                  decoration: InputDecoration(
                    counterText: "",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "";
                    }
                    if (!RegExp(r'^\d$').hasMatch(value)) {
                      return "";
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value.length == 1 && nextFocus != null) {
                      FocusScope.of(context).requestFocus(nextFocus);
                    }
                    if (value.isEmpty && focusNode != _focusNode1) {
                      FocusScope.of(context).previousFocus();
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
