import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_waste/main.dart';
import 'package:smart_waste/env.dart';
import 'orders_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String? error;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _birthday;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        setState(() {
          error = 'Not authenticated';
          isLoading = false;
        });
        return;
      }
      final response = await http.get(
        Uri.parse('${Env.apiBaseUrl}api/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userData = data['user'];
          _firstNameController.text = userData?['first_name'] ?? '';
          _lastNameController.text = userData?['last_name'] ?? '';
          _phoneController.text = userData?['phone'] ?? '';
          if (userData?['birthday'] != null) {
            _birthday = DateTime.tryParse(userData!['birthday']);
          }
          isLoading = false;
        });
      } else {
        // If backend returns error, just go back
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (status.isGranted) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _profileImage = File(picked.path);
        });
      }
    } else if (status.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text(
                'Please enable photo access permission in your device settings to change your profile picture.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied to access photos')),
      );
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? now,
      // Open with today as default
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() {
        _birthday = picked;
      });
    }
  }

  void _updateProfile() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Not authenticated')));
      return;
    }

    try {
      var uri = Uri.parse('${Env.apiBaseUrl}api/UpdateProfile');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['first_name'] = _firstNameController.text;
      request.fields['last_name'] = _lastNameController.text;
      request.fields['phone'] = _phoneController.text;
      if (_birthday != null) {
        request.fields['birthday'] = DateFormat(
          'yyyy-MM-dd',
        ).format(_birthday!);
      }

      if (_profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', _profileImage!.path),
        );
      }

      var response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        setState(() {
          _profileImage = null; // Clear local image so backend image is used
        });
        fetchProfile(); // Refresh profile data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile (${response.statusCode}): $respStr',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, _) {
              IconData icon;
              switch (mode) {
                case ThemeMode.dark:
                  icon = Icons.dark_mode;
                  break;
                case ThemeMode.light:
                  icon = Icons.light_mode;
                  break;
                default:
                  icon = Icons.brightness_auto;
              }
              return IconButton(
                icon: Icon(icon),
                tooltip: 'Change theme',
                onPressed: () {
                  ThemeMode newMode;
                  if (mode == ThemeMode.system) {
                    newMode = ThemeMode.light;
                  } else if (mode == ThemeMode.light) {
                    newMode = ThemeMode.dark;
                  } else {
                    newMode = ThemeMode.system;
                  }
                  themeNotifier.value = newMode;
                },
              );
            },
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(child: Text(error!))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundImage:
                                _profileImage != null
                                    ? FileImage(_profileImage!)
                                    : (userData?['photo'] != null
                                            ? NetworkImage(
                                              userData!['photo']
                                                      .toString()
                                                      .startsWith('http')
                                                  ? userData!['photo']
                                                  : '${Env.apiBaseUrl}storage/${userData!['photo']}',
                                            )
                                            : const AssetImage(
                                              'assets/avatar_placeholder.png',
                                            ))
                                        as ImageProvider,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickImage,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: theme.colorScheme.primary,
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'Имя',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Фамилия',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickBirthday,
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText:
                                'Дата рождения', // Change to 'Дата рождения' (Date of Birth)
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.calendar_today),
                            hintText:
                                _birthday != null
                                    ? DateFormat(
                                      'dd.MM.yyyy',
                                    ).format(_birthday!)
                                    : 'Выберите дату',
                          ),
                          controller: TextEditingController(
                            text:
                                _birthday != null
                                    ? DateFormat(
                                      'dd.MM.yyyy',
                                    ).format(_birthday!)
                                    : '',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateProfile,
                        child: const Text('Обновить'),
                      ),
                    ),
                  ],
                ),
              ),
      bottomNavigationBar: AppBottomNavBar(selectedIndex: 2),
    );
  }
}
