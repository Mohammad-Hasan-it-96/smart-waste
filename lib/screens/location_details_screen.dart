import 'package:flutter/material.dart';

class LocationDetailsScreen extends StatefulWidget {
  final double lat;
  final double lng;

  const LocationDetailsScreen({
    super.key,
    required this.lat,
    required this.lng,
  });

  @override
  State<LocationDetailsScreen> createState() => _LocationDetailsScreenState();
}

class _LocationDetailsScreenState extends State<LocationDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  String? street, building, apartment, other;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Детали адреса')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Координаты: ${widget.lat.toStringAsFixed(6)}, ${widget.lng.toStringAsFixed(6)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Улица'),
                onSaved: (v) => street = v,
                validator:
                    (v) => v == null || v.isEmpty ? 'Введите улицу' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Номер дома'),
                onSaved: (v) => building = v,
                validator:
                    (v) => v == null || v.isEmpty ? 'Введите номер дома' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Квартира'),
                onSaved: (v) => apartment = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Дополнительно'),
                onSaved: (v) => other = v,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    // TODO: Use the collected data as needed
                    Navigator.of(context).pop(); // Or navigate further
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
