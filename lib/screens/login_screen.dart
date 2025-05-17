import 'package:flutter/material.dart';
import 'package:smart_waste/screens/home_screen.dart';
import 'package:smart_waste/screens/register_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:smart_waste/main.dart';
import 'package:smart_waste/env.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _storage = const FlutterSecureStorage();

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final url = Uri.parse('${Env.apiBaseUrl}api/login');
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': _email, // Use email here instead of username
            'password': _password,
          }),
        );

        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final token = data['token'];
          // Save token securely
          await _storage.write(key: 'auth_token', value: token);
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid email or password.')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход'),
        centerTitle: true,
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Электронная почта',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator:
                      (value) =>
                          value != null && value.contains('@')
                              ? null
                              : 'Введите корректный email',
                  onChanged: (value) => _email = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  validator:
                      (value) =>
                          value != null && value.length >= 6
                              ? null
                              : 'Пароль слишком короткий',
                  onChanged: (value) => _password = value,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child:
                        _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Войти'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('Нет аккаунта? Зарегистрируйтесь'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
