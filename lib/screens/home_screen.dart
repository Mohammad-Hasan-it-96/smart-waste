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
import 'select_offer_screen.dart';
import 'package:badges/badges.dart' as badges;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'edit_address_screen.dart';

// Add this class before the HomeScreen class
class AddressesBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> addresses;
  final VoidCallback? onAddressChanged;
  const AddressesBottomSheet({
    super.key,
    required this.addresses,
    this.onAddressChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [Text('Ваши адреса', style: theme.textTheme.titleLarge)],
          ),
          const SizedBox(height: 16),
          ...addresses
              .map(
                (address) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      Icons.location_on,
                      color:
                          address['isDefault'] == true
                              ? theme.colorScheme.primary
                              : Colors.grey,
                    ),
                    title: Text(
                      '${address['street_number']}, д. ${address['building_number']}, кв. ${address['apartment_number']}',
                      style: TextStyle(
                        fontWeight:
                            address['isDefault'] == true
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => EditAddressScreen(
                                          locationId: address['id'],
                                          initialLat:
                                              address['lat'] != null
                                                  ? double.tryParse(
                                                    address['lat'].toString(),
                                                  )
                                                  : null,
                                          initialLong:
                                              address['long'] != null
                                                  ? double.tryParse(
                                                    address['long'].toString(),
                                                  )
                                                  : null,
                                          buildingNumber:
                                              address['building_number'],
                                          streetNumber:
                                              address['street_number'],
                                          apartmentNumber:
                                              address['apartment_number'],
                                          details: address['details'],
                                        ),
                                  ),
                                )
                                .then((value) {
                                  if (value == true &&
                                      onAddressChanged != null) {
                                    onAddressChanged!();
                                  }
                                });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Удалить адрес?'),
                                    content: const Text(
                                      'Вы уверены, что хотите удалить этот адрес?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(
                                              context,
                                            ).pop(false),
                                        child: const Text('Отмена'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () =>
                                                Navigator.of(context).pop(true),
                                        child: const Text('Удалить'),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirmed == true) {
                              final token = await const FlutterSecureStorage()
                                  .read(key: 'auth_token');
                              final url = Uri.parse(
                                '${Env.apiBaseUrl}api/delete_address',
                              );
                              print(
                                'Deleting address with id: ${address['id']}',
                              );
                              final response = await http.post(
                                url,
                                headers: {
                                  'Content-Type': 'application/json',
                                  if (token != null)
                                    'Authorization': 'Bearer $token',
                                },
                                body: jsonEncode({'id': address['id']}),
                              );
                              if (response.statusCode == 200) {
                                Navigator.pop(context, true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Ошибка при удалении адреса'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

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

  // Add timer for auto-scroll
  Timer? _autoScrollTimer;
  String? _profileImageUrl;
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;

  List<Map<String, dynamic>> _userAddresses = [];
  bool _addressesLoading = true;

  List<String> _promotionImages = [];
  String? _workingHours;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAuthAndFetch();
    _fetchProfileImage();
    _fetchUserAddresses();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    // Auto scroll every 3 seconds
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_bannerController.hasClients) {
        final nextPage = (_currentBannerIndex + 1) % 3;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
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

        // Promotions
        _promotionImages =
            (data['promotions'] as List)
                .map(
                  (p) => 'https://back.wastefree247.com/public/${p['photo']}',
                )
                .toList();

        // Configs
        final configList = data['config'] as List;
        final workingHoursConfig = configList.firstWhere(
          (c) => c['name'] == 'working hours',
          orElse: () => null,
        );
        if (workingHoursConfig != null) {
          _workingHours = workingHoursConfig['value'];
        }
        final apiKeyConfig = configList.firstWhere(
          (c) => c['name'] == '2gis_API_KEY',
          orElse: () => null,
        );
        if (apiKeyConfig != null) {
          await _storage.write(
            key: '2gis_API_KEY',
            value: apiKeyConfig['value'],
          );
        }

        // Locations
        _userAddresses = List<Map<String, dynamic>>.from(
          data['locations'] ?? [],
        );

        // Notifications, tasks, offers as before...
        setState(() {
          _offers = List<Map<String, dynamic>>.from(data['offers'] ?? []);
          _notifications = List<Map<String, dynamic>>.from(
            data['notifications'] ?? [],
          );
          _tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
          // Add these:
          _promotionImages = _promotionImages;
          _workingHours = _workingHours;
          _userAddresses = _userAddresses;
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

  Future<void> _fetchProfileImage() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('${Env.apiBaseUrl}api/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _profileImageUrl = data['user']?['photo'];
        });
      }
    } catch (e) {
      print('Error fetching profile image: $e');
    }
  }

  Future<void> _fetchUserAddresses() async {
    setState(() => _addressesLoading = true);
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      setState(() {
        _userAddresses = [];
        _addressesLoading = false;
      });
      return;
    }
    try {
      final url = Uri.parse('${Env.apiBaseUrl}api/my_locations');
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
          _userAddresses = List<Map<String, dynamic>>.from(
            data['locations'] ?? [],
          );
          _addressesLoading = false;
        });
      } else {
        setState(() {
          _userAddresses = [];
          _addressesLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _userAddresses = [];
        _addressesLoading = false;
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

  Widget _buildPromotionalBanners() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: PageView.builder(
        controller: _bannerController,
        itemCount: _promotionImages.length,
        onPageChanged: (index) {
          setState(() {
            _currentBannerIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey[300],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                _promotionImages[index],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkingHours() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Часы работы',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ежедневно', style: theme.textTheme.bodyLarge),
              Text(
                _workingHours ?? '9:00 - 21:00',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mainContent(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Application Logo
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
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
                  'EcoPack',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // 2. Address Section
          if (!_addressesLoading && _isLoggedIn && _userAddresses.isNotEmpty)
            InkWell(
              onTap: () async {
                final result = await showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder:
                      (context) => AddressesBottomSheet(
                        addresses: _userAddresses,
                        onAddressChanged: () {
                          Navigator.of(context).pop(true);
                        },
                      ),
                );

                if (result == true) {
                  await _fetchHomeData();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ваш адрес',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userAddresses.isNotEmpty
                                ? '${_userAddresses[0]['street_number']}, д. ${_userAddresses[0]['building_number']}, кв. ${_userAddresses[0]['apartment_number']}'
                                : '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),

          // 3. Profile Picture Slider
          _buildPromotionalBanners(),

          // 4. Second Logo (Smaller)
          Center(
            child: Icon(Icons.eco, size: 40, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),

          // 5. Add Order Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SelectOfferScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Оформить заказ',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),

          // 6. Working Hours
          _buildWorkingHours(),

          // 7. Support Button (Telegram)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              onPressed: () async {
                final url = 'https://t.me/+963983820430';
                try {
                  await launchUrl(Uri.parse(url));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Не удалось открыть Telegram'),
                    ),
                  );
                }
              },
              icon: Icon(Icons.support_agent, color: theme.colorScheme.primary),
              label: const Text('Поддержка в Telegram'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
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
        title: const Text('EcoPack'),
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
