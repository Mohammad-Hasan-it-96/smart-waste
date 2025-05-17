import 'dart:convert';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'package:smart_waste/main.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:smart_waste/env.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        setState(() {
          _error = 'Пожалуйста, войдите в систему, чтобы просмотреть заказы.';
          _isLoading = false;
        });
        return;
      }
      final url = Uri.parse('${Env.apiBaseUrl}api/my_tasks');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Ошибка загрузки заказов. Попробуйте позже.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка сети. Проверьте подключение.';
        _isLoading = false;
      });
    }
  }

  String _russianDay(String? day) {
    switch (day) {
      case 'Monday':
        return 'Понедельник';
      case 'Tuesday':
        return 'Вторник';
      case 'Wednesday':
        return 'Среда';
      case 'Thursday':
        return 'Четверг';
      case 'Friday':
        return 'Пятница';
      case 'Saturday':
        return 'Суббота';
      case 'Sunday':
        return 'Воскресенье';
      default:
        return day ?? '';
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.event, color: theme.colorScheme.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _russianDay(task['day_of_week']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.date_range, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        task['date'] ?? '',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${task['start_time']?.substring(0, 5) ?? ''} - ${task['end_time']?.substring(0, 5) ?? ''}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заказы'),
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.redAccent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : _tasks.isEmpty
              ? const Center(
                child: Text(
                  'У вас пока нет заказов',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
              : ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (context, i) => _buildTaskCard(_tasks[i]),
              ),
      bottomNavigationBar: AppBottomNavBar(selectedIndex: 1),
    );
  }
}

class AppBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  const AppBottomNavBar({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<bool>(
      future: HomeScreen.isLoggedInStatic(context),
      builder: (context, snapshot) {
        final isLoggedIn = snapshot.data ?? false;
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: theme.scaffoldBackgroundColor,
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor: theme.colorScheme.primary.withOpacity(0.5),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              elevation: 0,
              currentIndex: selectedIndex,
              onTap: (index) {
                if (index == selectedIndex) return;
                if (index == 0) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const OrdersScreen(),
                    ),
                    (route) => false,
                  );
                } else if (index == 2 && isLoggedIn) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Главная',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_rounded),
                  label: 'Заказы',
                ),
                if (isLoggedIn)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded),
                    label: 'Профиль',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
