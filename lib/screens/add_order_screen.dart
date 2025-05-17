import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:smart_waste/env.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddOrderScreen extends StatefulWidget {
  final int offerId;
  final String? priceAfterDiscount;
  final String? offerPeriod;
  const AddOrderScreen({
    super.key,
    required this.offerId,
    this.priceAfterDiscount,
    this.offerPeriod,
  });

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

  // Location selection logic
  List<Map<String, dynamic>> _locations = [];
  int? _selectedLocationId;
  bool _showAddLocationForm = false;
  bool _locationsLoading = true;

  @override
  void initState() {
    super.initState();
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
    if (widget.priceAfterDiscount == null) return 0.0;
    // Remove spaces and handle both dot and comma as decimal separator
    final priceStr = widget.priceAfterDiscount!
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
    GeoPoint? point = await showSimplePickerLocation(
      context: context,
      title: "Выберите местоположение",
      initCurrentUserPosition: UserTrackingOption(),
    );
    if (point != null) {
      setState(() {
        lat = point.latitude;
        lng = point.longitude;
      });
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
      'offer_id': widget.offerId,
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

  Future<String?> _getToken() async {
    final storage = const FlutterSecureStorage();
    return await storage.read(key: 'auth_token');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_locationsLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Оформить заказ')),
      body: Center(
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
                          'Выберите место:',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ..._locations.map(
                          (loc) => RadioListTile<int>(
                            value: loc['id'],
                            groupValue: _selectedLocationId,
                            onChanged: (val) {
                              setState(() {
                                _selectedLocationId = val;
                              });
                            },
                            title: Text(
                              '${loc['building_number'] ?? ''}, ${loc['street_number'] ?? ''}, ${loc['apartment_number'] ?? ''}',
                            ),
                            subtitle: Text(loc['details'] ?? ''),
                          ),
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
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
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
                                  if (widget.offerPeriod == 'one_time') {
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
                                            keyboardType:
                                                TextInputType.datetime,
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
                                            keyboardType:
                                                TextInputType.datetime,
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
                      children: [
                        Text(
                          'Выбранное предложение: #${widget.offerId}',
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
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
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
                                  if (widget.offerPeriod == 'one_time') {
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
                                            keyboardType:
                                                TextInputType.datetime,
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
                                            keyboardType:
                                                TextInputType.datetime,
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
      ),
    );
  }
}
