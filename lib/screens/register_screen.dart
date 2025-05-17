import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_waste/env.dart';
import 'dart:convert';
import 'package:smart_waste/screens/home_screen.dart' as home;
import 'package:smart_waste/screens/login_screen.dart' as login;
import 'package:smart_waste/main.dart';
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _email = '';
  String _password = '';
  String _repeatPassword = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;

  void _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final url = Uri.parse('${Env.apiBaseUrl}api/register');
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': _name,
            'email': _email,
            'password': _password,
            'password_confirmation': _repeatPassword,
          }),
        );

        setState(() => _isLoading = false);

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Registration successful, navigate to home
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const home.HomeScreen()),
          );
        } else {
          String errorMsg = 'Registration failed';
          try {
            final data = jsonDecode(response.body);
            if (data is Map && data.containsKey('message')) {
              errorMsg = data['message'];
            }
          } catch (_) {
            // If response is not JSON, use the raw body as error message
            errorMsg = response.body;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация'),
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

      ],),
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
                    labelText: 'Имя',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.name,
                  validator:
                      (value) =>
                          value != null && value.trim().isNotEmpty
                              ? null
                              : 'Введите имя',
                  onChanged: (value) => _name = value,
                ),
                const SizedBox(height: 16),
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
                          value != null && value.length >= 8
                              ? null
                              : 'Пароль слишком короткий',
                  onChanged: (value) => _password = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Повторите пароль',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRepeatPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureRepeatPassword = !_obscureRepeatPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureRepeatPassword,
                  validator:
                      (value) =>
                          value != null && value == _password
                              ? null
                              : 'Пароли не совпадают',
                  onChanged: (value) => _repeatPassword = value,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Регистрация'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const login.LoginScreen(),
                      ),
                    );
                  },
                  child: const Text('У вас уже есть аккаунт? Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
