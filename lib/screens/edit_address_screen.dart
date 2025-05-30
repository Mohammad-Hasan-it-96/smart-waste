import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:smart_waste/env.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../widgets/dgis_location_picker.dart';

class EditAddressScreen extends StatefulWidget {
  final int locationId;
  final double? initialLat;
  final double? initialLong;
  final String? buildingNumber;
  final String? streetNumber;
  final String? apartmentNumber;
  final String? details;

  const EditAddressScreen({
    super.key,
    required this.locationId,
    this.initialLat,
    this.initialLong,
    this.buildingNumber,
    this.streetNumber,
    this.apartmentNumber,
    this.details,
  });

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  late TextEditingController _buildingController;
  late TextEditingController _streetController;
  late TextEditingController _apartmentController;
  late TextEditingController _detailsController;

  double? _lat;
  double? _long;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _buildingController = TextEditingController(
      text: widget.buildingNumber ?? '',
    );
    _streetController = TextEditingController(text: widget.streetNumber ?? '');
    _apartmentController = TextEditingController(
      text: widget.apartmentNumber ?? '',
    );
    _detailsController = TextEditingController(text: widget.details ?? '');
    _lat = widget.initialLat;
    _long = widget.initialLong;
  }

  @override
  void dispose() {
    _buildingController.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickLocationOnMap() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => DGisLocationPicker(
              initialLat: _lat ?? 55.7558,
              initialLng: _long ?? 37.6173,
              onPicked: (pickedLat, pickedLng) {
                setState(() {
                  _lat = pickedLat;
                  _long = pickedLng;
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
        _lat = position.latitude;
        _long = position.longitude;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка получения геолокации: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _lat == null || _long == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Пожалуйста, заполните все обязательные поля и выберите местоположение на карте.',
          ),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'auth_token');
    final url = Uri.parse('${Env.apiBaseUrl}api/update_address');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id': widget.locationId,
          'lat': _lat?.toString(), // send as string if backend expects string
          'long': _long?.toString(),
          'building_number': _buildingController.text,
          'street_number': _streetController.text,
          'apartment_number': _apartmentController.text,
          'details':
              _detailsController.text.isNotEmpty
                  ? _detailsController.text
                  : null,
        }),
      );
      setState(() => _isLoading = false);
      if (response.statusCode == 200) {
        Navigator.of(context).pop(true); // Return success
      } else {
        String errorMsg = 'Ошибка при обновлении адреса';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('message')) {
            errorMsg = data['message'];
          }
        } catch (_) {
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
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать адрес')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Местоположение', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickLocationOnMap,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child:
                        _lat != null && _long != null
                            ? Text('Выбрано: $_lat, $_long')
                            : Text('Нажмите, чтобы выбрать на карте'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _useCurrentLocation,
                icon: Icon(Icons.my_location),
                label: Text('Использовать моё местоположение'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _buildingController,
                decoration: const InputDecoration(
                  labelText: 'Номер здания',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Обязательное поле'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Номер улицы',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Обязательное поле'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apartmentController,
                decoration: const InputDecoration(
                  labelText: 'Номер квартиры',
                  border: OutlineInputBorder(),
                ),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Обязательное поле'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsController,
                decoration: const InputDecoration(
                  labelText: 'Детали (необязательно)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child:
                    _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
