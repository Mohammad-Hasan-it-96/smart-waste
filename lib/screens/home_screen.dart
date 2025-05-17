import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:smart_waste/main.dart';
import 'add_order_screen.dart';
import 'profile_screen.dart';
import 'register_screen.dart';
import 'package:smart_waste/env.dart';
import 'dart:convert';
import 'orders_screen.dart';
import 'package:badges/badges.dart' as badges;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static Future<bool> isLoggedInStatic(BuildContext context) async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    return token != null;
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  final _storage = const FlutterSecureStorage();

  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _tasks = [];

  final List<String> _wasteTypes = [
    'Пластик',
    'Стекло',
    'Бумага',
    'Металл',
    'Органика',
  ];
  final List<DateTime> _collectionDates = [
    DateTime.now().add(const Duration(days: 1)),
    DateTime.now().add(const Duration(days: 3)),
    DateTime.now().add(const Duration(days: 5)),
  ];

  int? _status; // 0 or 1, null means loading or not fetched yet
  bool _isLoggedIn = false;
  bool _isNotificationsDropdownOpen = false;
  bool _isMarkingNotificationsRead = false;

  int get _unreadNotificationsCount =>
      _lastNotifications.where((n) => n['is_read'] == 0).length;

  List<Map<String, dynamic>> get _lastNotifications {
    final sorted = List<Map<String, dynamic>>.from(_notifications);
    sorted.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    return sorted.take(10).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAuthAndFetch();
  }

  Future<void> _checkAuthAndFetch() async {
    final token = await _storage.read(key: 'auth_token');
    setState(() {
      _isLoggedIn = token != null;
    });
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    final token = await _storage.read(key: 'auth_token');
    final url = Uri.parse('${Env.apiBaseUrl}api/home');
    try {
      final response = await http.get(
        url,
        headers:
            token != null
                ? {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                }
                : {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _offers = List<Map<String, dynamic>>.from(data['offers'] ?? []);
          _notifications = List<Map<String, dynamic>>.from(
            data['notifications'] ?? [],
          );
          _tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
        });
      } else {
        setState(() {
          _offers = [];
          _notifications = [];
          _tasks = [];
        });
      }
    } catch (e) {
      setState(() {
        _offers = [];
        _notifications = [];
        _tasks = [];
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

  Widget _mainContent(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo and description
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Icon(
                      Icons.eco,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Добро пожаловать в Smart Waste!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Управляйте вывозом отходов, оформляйте подписки и следите за чистотой вашего дома с помощью нашего приложения.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              if (_tasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tasks.length > 3 ? 3 : _tasks.length,
                      separatorBuilder:
                          (context, i) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final task = _tasks[i];
                        return Container(
                          width: 200,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(
                                0.15,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _russianDay(task['day_of_week']),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    task['date'] ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          theme.brightness == Brightness.dark
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${task['start_time']?.substring(0, 5) ?? ''} - ${task['end_time']?.substring(0, 5) ?? ''}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          theme.brightness == Brightness.dark
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              if (_offers.isNotEmpty)
                Column(
                  children: List.generate(_offers.length, (i) {
                    final offer = _offers[i];
                    final String? price = offer["price"]?.toString();
                    final String? priceAfterDiscount =
                        offer["price_after_discount"]?.toString();
                    final bool isOneTime = offer["offer_period"] == "one_time";
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        color:
                            isOneTime
                                ? theme.colorScheme.primary
                                : (theme.brightness == Brightness.dark
                                    ? Colors.grey[850]
                                    : Colors.grey[200]),
                        elevation: isOneTime ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final token = await _storage.read(
                              key: 'auth_token',
                            );
                            if (token == null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(),
                                ),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => AddOrderScreen(
                                        offerId: offer["id"],
                                        priceAfterDiscount: priceAfterDiscount,
                                        offerPeriod:
                                            offer["offer_period"]?.toString(),
                                      ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  offer["title"] ?? '',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isOneTime
                                            ? Colors.white
                                            : (theme.brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  offer["body"] ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color:
                                        isOneTime
                                            ? Colors.white70
                                            : (theme.brightness ==
                                                    Brightness.dark
                                                ? Colors.white70
                                                : Colors.black87),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (price != null &&
                                        priceAfterDiscount != null &&
                                        price != priceAfterDiscount)
                                      Text(
                                        '$price ₽',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color:
                                              isOneTime
                                                  ? Colors.white70
                                                  : Colors.grey,
                                          decoration:
                                              TextDecoration.lineThrough,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    if (priceAfterDiscount != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8.0,
                                        ),
                                        child: Text(
                                          '$priceAfterDiscount ₽',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isOneTime
                                                    ? Colors.white
                                                    : theme
                                                        .colorScheme
                                                        .secondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              if (_offers.isEmpty)
                const Center(
                  child: Text(
                    'Нет доступных предложений',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              if (!_isLoggedIn)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Войти или зарегистрироваться'),
                              content: const Text(
                                'Для покупки услуг по подписке войдите или зарегистрируйтесь.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => LoginScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Войти'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => RegisterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Зарегистрироваться'),
                                ),
                              ],
                            ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'Для покупки услуг по подписке войдите или зарегистрируйтесь.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionList(List<DateTime> dates) {
    if (dates.isEmpty) {
      return const Center(child: Text('Нет запланированного вывоза'));
    }
    return ListView.builder(
      itemCount: dates.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.delete),
          title: Text('Вывоз ${_wasteTypes[index % _wasteTypes.length]}'),
          subtitle: Text(
            DateFormat('EEEE, d MMMM', 'ru_RU').format(dates[index]),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView() {
    return const Center(child: Text('Календарь вывоза мусора будет здесь'));
  }

  Future<void> _markNotificationsAsRead() async {
    if (_isMarkingNotificationsRead) return;
    _isMarkingNotificationsRead = true;
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;
    final url = Uri.parse('${Env.apiBaseUrl}api/MakeAllRead');
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      // Update local state
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = 1;
        }
      });
    } catch (e) {
      // Optionally handle error
    } finally {
      _isMarkingNotificationsRead = false;
    }
  }

  void _showNotificationsDropdown(BuildContext context) async {
    setState(() {
      _isNotificationsDropdownOpen = true;
    });
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset position = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + button.size.height,
        overlay.size.width - position.dx - button.size.width,
        overlay.size.height - position.dy,
      ),
      items:
          _lastNotifications.isEmpty
              ? [const PopupMenuItem(child: Text('Нет уведомлений'))]
              : _lastNotifications.map((notification) {
                final bool isUnread = notification['is_read'] == 0;
                return PopupMenuItem(
                  value: notification['id'],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification['title'] ?? '',
                        style: TextStyle(
                          fontWeight:
                              isUnread ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                          color:
                              isUnread
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification['body'] ?? '',
                        style: TextStyle(
                          fontWeight:
                              isUnread ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? (isUnread ? Colors.white : Colors.white70)
                                  : (isUnread
                                      ? Colors.black87
                                      : Colors.black54),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
    );
    // After showing dropdown, mark as read
    if (_unreadNotificationsCount > 0) {
      await _markNotificationsAsRead();
    }
    setState(() {
      _isNotificationsDropdownOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Умные отходы'),
        actions: [
          Builder(
            builder:
                (context) => badges.Badge(
                  showBadge: _unreadNotificationsCount > 0,
                  badgeContent: Text(
                    _unreadNotificationsCount > 0
                        ? _unreadNotificationsCount.toString()
                        : '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  position: badges.BadgePosition.topEnd(top: 0, end: 2),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.all(6),
                    elevation: 0,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.notifications,
                      color:
                          _unreadNotificationsCount > 0
                              ? theme.colorScheme.primary
                              : null,
                    ),
                    onPressed: () => _showNotificationsDropdown(context),
                    tooltip: 'Уведомления',
                  ),
                ),
          ),
          if (_isLoggedIn)
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
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
      body: _mainContent(context),
      bottomNavigationBar: Container(
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
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Главная',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.list_alt_rounded),
                label: 'Заказы',
              ),
              if (_isLoggedIn)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded),
                  label: 'Профиль',
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _logout() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      await _storage.delete(key: 'auth_token');
      setState(() {
        _isLoggedIn = false;
      });
      _checkAuthAndFetch();
      return;
    }

    try {
      final url = Uri.parse('${Env.apiBaseUrl}api/logout');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      await _storage.delete(key: 'auth_token');
      setState(() {
        _isLoggedIn = false;
      });
      _checkAuthAndFetch();
    } catch (e) {
      await _storage.delete(key: 'auth_token');
      setState(() {
        _isLoggedIn = false;
      });
      _checkAuthAndFetch();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Navigate to OrdersScreen if orders tab is tapped
      if (index == 1) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const OrdersScreen()));
      }
      // Navigate to ProfileScreen if profile tab is tapped and user is logged in
      if (_isLoggedIn && index == 2) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const ProfileScreen()));
      }
      // You can add navigation logic for other tabs if needed
    });
  }
}
