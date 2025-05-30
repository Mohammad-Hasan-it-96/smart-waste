import 'package:flutter/material.dart';
import 'package:dgis_flutter/dgis_flutter.dart' as dgis;
import 'package:smart_waste/env.dart';

class DGisLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final void Function(double lat, double lng) onPicked;

  const DGisLocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    required this.onPicked,
  });

  @override
  State<DGisLocationPicker> createState() => _DGisLocationPickerState();
}

class _DGisLocationPickerState extends State<DGisLocationPicker> {
  late dgis.GisMapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = dgis.GisMapController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите местоположение')),
      body: Stack(
        children: [
          dgis.GisMap(
            mapKey: Env.dgApiKey,
            directoryKey: Env.dgApiKey,
            controller: _mapController,
            startCameraPosition: dgis.GisCameraPosition(
              latitude: widget.initialLat ?? 55.751244,
              longitude: widget.initialLng ?? 37.618423,
              zoom: 15,
            ),
            onTapMarker: (dgis.GisMapMarker marker) {
              print("Marker tapped: ${marker.id}");
            },
          ),
          const Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Icon(Icons.location_pin, color: Colors.red, size: 50),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  final currentPosition =
                      await _mapController.getCameraPosition();
                  widget.onPicked(
                    currentPosition.latitude,
                    currentPosition.longitude,
                  );
                  Navigator.of(context).pop();
                } catch (e) {
                  print("Error getting current camera position: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ошибка при выборе местоположения.'),
                    ),
                  );
                }
              },
              child: const Text('Выбрать это место'),
            ),
          ),
        ],
      ),
    );
  }
}
