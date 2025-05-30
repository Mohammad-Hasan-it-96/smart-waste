import 'package:flutter/material.dart';
import 'package:smart_waste/env.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../widgets/dgis_location_picker.dart';

class AddOrderScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedOffer;
  const AddOrderScreen({super.key, this.selectedOffer});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  int numberOfBags = 1;
  double? lat, lng;
  String? buildingNumber, streetNumber, apartmentNumber, details;
  List<String> selectedDays = [];
  Map<String, Map<String, String>> orderTimes = {};
  bool isSubmitting = false;

  // Offers logic
  List<Map<String, dynamic>> _offers = [];
  bool _offersLoading = true;
  Map<String, dynamic>? _selectedOffer;
  String? _selectedOfferPeriod;
  String? _selectedOfferPrice;

  // Location selection logic
  List<Map<String, dynamic>> _locations = [];
  int? _selectedLocationId;
  bool _showAddLocationForm = false;
  bool _locationsLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.selectedOffer != null) {
      _selectedOffer = widget.selectedOffer;
      _selectedOfferPeriod = widget.selectedOffer!['offer_period']?.toString();
      _selectedOfferPrice =
          widget.selectedOffer!['price_after_discount']?.toString() ??
          widget.selectedOffer!['price']?.toString();
      _fetchLocations();
      _offersLoading = false;
    } else {
      _fetchOffers();
    }
  }

  Future<void> _fetchOffers() async {
    setState(() => _offersLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${Env.apiBaseUrl}api/get_offers'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _offers = List<Map<String, dynamic>>.from(data['offers'] ?? []);
          _offersLoading = false;
        });
      } else {
        setState(() {
          _offers = [];
          _offersLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _offers = [];
        _offersLoading = false;
      });
    }
  }

  Future<String?> _getToken() async {
    final storage = const FlutterSecureStorage();
    return await storage.read(key: 'auth_token');
  }

  Future<void> _onOfferTap(Map<String, dynamic> offer) async {
    final token = await _getToken();
    if (token == null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Войти или зарегистрироваться'),
              content: const Text(
                'Для оформления заказа войдите или зарегистрируйтесь.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  child: const Text('Войти'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => RegisterScreen()),
                    );
                  },
                  child: const Text('Зарегистрироваться'),
                ),
              ],
            ),
      );
      return;
    }
    setState(() {
      _selectedOffer = offer;
      _selectedOfferPeriod = offer['offer_period']?.toString();
      _selectedOfferPrice =
          offer['price_after_discount']?.toString() ??
          offer['price']?.toString();
    });
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    setState(() {
      _locationsLoading = true;
    });
    final token = await _getToken();
    if (token == null) {
      setState(() {
        _locations = [];
        _locationsLoading = false;
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
          _locations = List<Map<String, dynamic>>.from(data['locatios'] ?? []);
          _locationsLoading = false;
        });
      } else {
        setState(() {
          _locations = [];
          _locationsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _locations = [];
        _locationsLoading = false;
      });
    }
  }

  double get _unitPrice {
    if (_selectedOfferPrice == null) return 0.0;
    // Remove spaces and handle both dot and comma as decimal separator
    final priceStr = _selectedOfferPrice!
        .replaceAll(' ', '')
        .replaceAll(',', '.');
    return double.tryParse(priceStr) ?? 0.0;
  }

  double get _totalPrice => numberOfBags * _unitPrice;

  static const weekDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  static const weekDaysRu = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  Future<void> _pickLocation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => DGisLocationPicker(
              initialLat: lat ?? 55.7558,
              initialLng: lng ?? 37.6173,
              onPicked: (pickedLat, pickedLng) {
                setState(() {
                  lat = pickedLat;
                  lng = pickedLng;
                });
              },
            ),
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Включить геолокацию?'),
                content: Text(
                  'Для использования этой функции включите геолокацию на устройстве.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Открыть настройки'),
                  ),
                ],
              ),
        );
        if (shouldOpen == true) {
          await Geolocator.openLocationSettings();
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет разрешения на геолокацию.')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Геолокация запрещена навсегда.')),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        lat = position.latitude;
        lng = position.longitude;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка получения геолокации: $e')),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, String day, String field) async {
    final initial = orderTimes[day]?[field];
    TimeOfDay initialTime;
    if (initial != null && initial.isNotEmpty) {
      final parts = initial.split(":");
      if (parts.length == 2) {
        initialTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 10,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      } else {
        initialTime = const TimeOfDay(hour: 10, minute: 0);
      }
    } else {
      initialTime = const TimeOfDay(hour: 10, minute: 0);
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        orderTimes[day]![field] = picked.format(context);
        // Convert to HH:mm format if needed
        final formatted =
            picked.hour.toString().padLeft(2, '0') +
            ':' +
            picked.minute.toString().padLeft(2, '0');
        orderTimes[day]![field] = formatted;
      });
    }
  }

  Future<void> _submit() async {
    if (_locations.isNotEmpty && !_showAddLocationForm) {
      if (_selectedLocationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пожалуйста, выберите место.')),
        );
        return;
      }
    }
    if (_locations.isEmpty || _showAddLocationForm) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пожалуйста, выберите местоположение на карте.'),
          ),
        );
        return;
      }
    }
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите дни недели.')),
      );
      return;
    }
    for (final day in selectedDays) {
      if (orderTimes[day] == null ||
          orderTimes[day]!['start_time']!.isEmpty ||
          orderTimes[day]!['end_time']!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Пожалуйста, выберите время для $day.')),
        );
        return;
      }
    }
    _formKey.currentState?.save();
    setState(() => isSubmitting = true);
    final token = await _getToken();
    final url = Uri.parse('${Env.apiBaseUrl}api/add_order');
    final payload = <String, dynamic>{
      'offer_id': _selectedOffer!['id'],
      'number_of_bags': numberOfBags,
      'order_time': [
        for (final day in selectedDays)
          {
            'day': day,
            'start_time': orderTimes[day]!['start_time'],
            'end_time': orderTimes[day]!['end_time'],
          },
      ],
      'total_price': _totalPrice,
    };
    if (_locations.isNotEmpty && !_showAddLocationForm) {
      payload['location_id'] = _selectedLocationId;
    } else {
      payload.addAll({
        'lat': lat,
        'long': lng,
        'building_number': buildingNumber,
        'street_number': streetNumber,
        'apartment_number': apartmentNumber,
        'details': details,
      });
    }
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      setState(() => isSubmitting = false);
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Заказ успешно создан!')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: ${response.body}')));
      }
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  String _periodRu(String? period) {
    switch (period) {
      case 'one_time':
        return 'Разовый';
      case 'weekly':
        return 'Две недели';
      case 'monthly':
        return 'Месяц';
      default:
        return period ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_offersLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Оформить заказ')),
      body:
          _selectedOffer == null
              ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _offers.length,
                itemBuilder: (context, index) {
                  final offer = _offers[index];
                  final hasDiscount =
                      (offer['discount'] ?? 0) > 0 &&
                      offer['price'] != offer['price_after_discount'];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _onOfferTap(offer),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_offer,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    offer['title'] ?? 'Предложение',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (hasDiscount) ...[
                                  Text(
                                    '${offer['price']} ₽',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${offer['price_after_discount']} ₽',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ] else ...[
                                  Text(
                                    '${offer['price_after_discount'] ?? offer['price'] ?? 0} ₽',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                            if (offer['body'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                offer['body'],
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Пакетов: ${offer['number_of_bags']}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Период: ${_periodRu(offer['offer_period'])}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                if (hasDiscount) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '-${offer['discount']}%',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _onOfferTap(offer),
                                  child: const Text('Выбрать'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )
              : _buildOrderForm(context, theme),
    );
  }

  Widget _buildOrderForm(BuildContext context, ThemeData theme) {
    if (_locationsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24.0),
        child:
            _locations.isNotEmpty && !_showAddLocationForm
                ? SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Выбранное предложение: #${_selectedOffer!['id']}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      // Number of bags selector
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.redAccent,
                                size: 32,
                              ),
                              onPressed:
                                  numberOfBags > 1
                                      ? () => setState(() => numberOfBags--)
                                      : null,
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.shopping_bag,
                                    color: Colors.green,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder:
                                        (child, anim) => ScaleTransition(
                                          scale: anim,
                                          child: child,
                                        ),
                                    child: Text(
                                      '$numberOfBags',
                                      key: ValueKey<int>(numberOfBags),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                                size: 32,
                              ),
                              onPressed: () => setState(() => numberOfBags++),
                            ),
                          ],
                        ),
                      ),
                      if (_unitPrice > 0.0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Row(
                                key: ValueKey(_totalPrice),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Итого: ',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    _totalPrice.toStringAsFixed(2),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '₽',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Text(
                        'Выберите дни недели и время:',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(weekDays.length, (i) {
                          final day = weekDays[i];
                          final dayRu = weekDaysRu[i];
                          final selected = selectedDays.contains(day);
                          return FilterChip(
                            label: Text(dayRu),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (_selectedOfferPeriod == 'one_time') {
                                  if (val) {
                                    selectedDays = [day];
                                    orderTimes = {
                                      day: {'start_time': '', 'end_time': ''},
                                    };
                                  } else {
                                    selectedDays.clear();
                                    orderTimes.clear();
                                  }
                                } else {
                                  if (val) {
                                    selectedDays.add(day);
                                    orderTimes[day] = {
                                      'start_time': '',
                                      'end_time': '',
                                    };
                                  } else {
                                    selectedDays.remove(day);
                                    orderTimes.remove(day);
                                  }
                                }
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          for (final day in selectedDays)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      weekDaysRu[weekDays.indexOf(day)],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => _pickTime(
                                            context,
                                            day,
                                            'start_time',
                                          ),
                                      child: AbsorbPointer(
                                        child: TextFormField(
                                          decoration: const InputDecoration(
                                            labelText: 'Начало',
                                            hintText: '10:00',
                                          ),
                                          keyboardType: TextInputType.datetime,
                                          controller: TextEditingController(
                                            text:
                                                orderTimes[day]?['start_time'] ??
                                                '',
                                          ),
                                          validator:
                                              (v) =>
                                                  v == null || v.isEmpty
                                                      ? 'Введите время'
                                                      : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => _pickTime(
                                            context,
                                            day,
                                            'end_time',
                                          ),
                                      child: AbsorbPointer(
                                        child: TextFormField(
                                          decoration: const InputDecoration(
                                            labelText: 'Конец',
                                            hintText: '20:00',
                                          ),
                                          keyboardType: TextInputType.datetime,
                                          controller: TextEditingController(
                                            text:
                                                orderTimes[day]?['end_time'] ??
                                                '',
                                          ),
                                          validator:
                                              (v) =>
                                                  v == null || v.isEmpty
                                                      ? 'Введите время'
                                                      : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Добавить новое место'),
                          onPressed: () {
                            setState(() {
                              _showAddLocationForm = true;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : _submit,
                          child:
                              isSubmitting
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text('Оформить заказ'),
                        ),
                      ),
                    ],
                  ),
                )
                : Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        'Выбранное предложение: #${_selectedOffer!['id']}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      // Number of bags selector
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.redAccent,
                                size: 32,
                              ),
                              onPressed:
                                  numberOfBags > 1
                                      ? () => setState(() => numberOfBags--)
                                      : null,
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.shopping_bag,
                                    color: Colors.green,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder:
                                        (child, anim) => ScaleTransition(
                                          scale: anim,
                                          child: child,
                                        ),
                                    child: Text(
                                      '$numberOfBags',
                                      key: ValueKey<int>(numberOfBags),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.green,
                                size: 32,
                              ),
                              onPressed: () => setState(() => numberOfBags++),
                            ),
                          ],
                        ),
                      ),
                      if (_unitPrice > 0.0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Row(
                                key: ValueKey(_totalPrice),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Итого: ',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    _totalPrice.toStringAsFixed(2),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '₽',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: _pickLocation,
                        icon: const Icon(Icons.map),
                        label: Text(
                          lat == null
                              ? 'Выбрать местоположение'
                              : 'Местоположение выбрано',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (lat != null && lng != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Координаты: ${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}',
                          ),
                        ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _useCurrentLocation,
                        icon: Icon(Icons.my_location),
                        label: Text('Использовать моё местоположение'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Номер дома',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Введите номер дома'
                                    : null,
                        onSaved: (v) => buildingNumber = v,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Номер улицы',
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Введите номер улицы'
                                    : null,
                        onSaved: (v) => streetNumber = v,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Квартира',
                          border: OutlineInputBorder(),
                        ),
                        onSaved: (v) => apartmentNumber = v,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Детали (например, подъезд, этаж)',
                          border: OutlineInputBorder(),
                        ),
                        onSaved: (v) => details = v,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Выберите дни недели и время:',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: List.generate(weekDays.length, (i) {
                          final day = weekDays[i];
                          final dayRu = weekDaysRu[i];
                          final selected = selectedDays.contains(day);
                          return FilterChip(
                            label: Text(dayRu),
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                if (_selectedOfferPeriod == 'one_time') {
                                  if (val) {
                                    selectedDays = [day];
                                    orderTimes = {
                                      day: {'start_time': '', 'end_time': ''},
                                    };
                                  } else {
                                    selectedDays.clear();
                                    orderTimes.clear();
                                  }
                                } else {
                                  if (val) {
                                    selectedDays.add(day);
                                    orderTimes[day] = {
                                      'start_time': '',
                                      'end_time': '',
                                    };
                                  } else {
                                    selectedDays.remove(day);
                                    orderTimes.remove(day);
                                  }
                                }
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          for (final day in selectedDays)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      weekDaysRu[weekDays.indexOf(day)],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => _pickTime(
                                            context,
                                            day,
                                            'start_time',
                                          ),
                                      child: AbsorbPointer(
                                        child: TextFormField(
                                          decoration: const InputDecoration(
                                            labelText: 'Начало',
                                            hintText: '10:00',
                                          ),
                                          keyboardType: TextInputType.datetime,
                                          controller: TextEditingController(
                                            text:
                                                orderTimes[day]?['start_time'] ??
                                                '',
                                          ),
                                          validator:
                                              (v) =>
                                                  v == null || v.isEmpty
                                                      ? 'Введите время'
                                                      : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => _pickTime(
                                            context,
                                            day,
                                            'end_time',
                                          ),
                                      child: AbsorbPointer(
                                        child: TextFormField(
                                          decoration: const InputDecoration(
                                            labelText: 'Конец',
                                            hintText: '20:00',
                                          ),
                                          keyboardType: TextInputType.datetime,
                                          controller: TextEditingController(
                                            text:
                                                orderTimes[day]?['end_time'] ??
                                                '',
                                          ),
                                          validator:
                                              (v) =>
                                                  v == null || v.isEmpty
                                                      ? 'Введите время'
                                                      : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              isSubmitting
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text('Оформить заказ'),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
