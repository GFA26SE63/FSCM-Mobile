import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:fscm_mobile/core/config/env.dart';
import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/map_place.dart';
import 'package:fscm_mobile/data/repositories/map_repository.dart';

/// Selection stays local until the caller saves the retailer declaration.
class MapLocationPicker extends ConsumerStatefulWidget {
  const MapLocationPicker({super.key, required this.address, this.initial});

  final String address;
  final MapPlace? initial;

  @override
  ConsumerState<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends ConsumerState<MapLocationPicker> {
  final _map = MapController();
  late final TextEditingController _address;
  MapPlace? _selected;
  List<MapSuggestion> _suggestions = const [];
  String? _error;
  bool _busy = false;
  bool _searched = false;
  bool _tileError = false;
  int _tileVersion = 0;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.address);
    _selected = widget.initial;
  }

  @override
  void dispose() {
    _address.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _address.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Nhập ít nhất 2 ký tự để tìm địa chỉ.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _error = null; _suggestions = const []; _searched = false; });
    try {
      final results = await ref.read(mapRepositoryProvider).search(query);
      if (!mounted) { return; }
      setState(() { _suggestions = results; _searched = true; });
    } on ApiException catch (error) {
      if (mounted) { setState(() => _error = error.message); }
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  Future<void> _choose(MapSuggestion suggestion) async {
    setState(() { _busy = true; _error = null; });
    try {
      final place = await ref.read(mapRepositoryProvider).place(suggestion);
      if (!mounted) { return; }
      setState(() { _selected = place; _address.text = place.address; _suggestions = const []; _searched = false; });
      _map.move(LatLng(place.latitude, place.longitude), 17);
    } on ApiException catch (error) {
      if (mounted) { setState(() => _error = error.message); }
    } finally {
      if (mounted) { setState(() => _busy = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = _selected;
    final hasKey = Env.vietMapApiKey.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn vị trí điểm bán')),
      body: SafeArea(
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: <Widget>[
              TextField(
                controller: _address,
                readOnly: _busy,
                onChanged: (_) => setState(() { _suggestions = const []; _searched = false; }),
                decoration: const InputDecoration(labelText: 'Địa chỉ điểm bán',
                    hintText: 'Số nhà, đường, phường/xã, tỉnh/thành'),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) { if (!_busy) { _search(); } },
              ),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _busy || !hasKey ? null : _search,
                icon: const Icon(Icons.search), label: const Text('Tìm địa chỉ'),
              )),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_searched && _suggestions.isEmpty && _error == null)
                const Text('Không tìm thấy địa chỉ. Thử nhập chi tiết hơn hoặc chọn ghim trên bản đồ.'),
            ]),
          ),
          if (_suggestions.isNotEmpty && MediaQuery.viewInsetsOf(context).bottom == 0)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.24),
              child: ListView.builder(
                shrinkWrap: true, itemCount: _suggestions.length,
                itemBuilder: (_, index) => ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(_suggestions[index].display),
                  onTap: _busy ? null : () => _choose(_suggestions[index]),
                ),
              ),
            ),
          Expanded(
            child: hasKey ? Stack(children: <Widget>[
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  // Initial viewport only; it is never saved as a selection.
                  initialCenter: point == null ? const LatLng(10.7769, 106.7009)
                      : LatLng(point.latitude, point.longitude),
                  initialZoom: point == null ? 12 : 17,
                  minZoom: 3, maxZoom: 19,
                  onTap: (_, location) {
                    if (_busy || _tileError) { return; }
                    setState(() {
                      _selected = MapPlace(latitude: location.latitude,
                          longitude: location.longitude, address: _address.text.trim());
                      _suggestions = const []; _searched = false;
                    });
                  },
                ),
                children: <Widget>[
                  TileLayer(
                    key: ValueKey(_tileVersion),
                    urlTemplate: 'https://maps.vietmap.vn/maps/tiles/st/{z}/{x}/{y}.png?apikey=${Uri.encodeQueryComponent(Env.vietMapApiKey.trim())}',
                    userAgentPackageName: 'vn.edu.fpt.fscm.fscm_mobile',
                    errorTileCallback: (_, __, ___) {
                      if (!mounted || _tileError) { return; }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) { setState(() => _tileError = true); }
                      });
                    },
                  ),
                  if (point != null) MarkerLayer(markers: <Marker>[
                    Marker(point: LatLng(point.latitude, point.longitude),
                        width: 44, height: 44, alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_pin, size: 44, color: Colors.red)),
                  ]),
                ],
              ),
              const Positioned(bottom: 4, right: 8, child: ColoredBox(
                color: Colors.white, child: Text('© VIETMAP', style: TextStyle(fontSize: 11)))),
              if (_tileError) Align(alignment: Alignment.topCenter, child: Card(
                child: Padding(padding: const EdgeInsets.all(8), child: Column(
                  mainAxisSize: MainAxisSize.min, children: <Widget>[
                    const Text('Không tải được bản đồ. Kiểm tra kết nối rồi thử lại.'),
                    TextButton(onPressed: () => setState(() { _tileError = false; _tileVersion++; }),
                        child: const Text('Tải lại bản đồ')),
                  ],
                )),
              )),
            ]) : const Center(child: Padding(padding: EdgeInsets.all(16),
                child: Text('Dịch vụ bản đồ chưa sẵn sàng. Vui lòng thử lại sau.'))),
          ),
          Padding(padding: const EdgeInsets.all(12), child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(point == null ? 'Tìm địa chỉ hoặc chạm bản đồ để đặt ghim.'
                  : 'Tọa độ: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
              const Text('Kiểm tra địa chỉ phù hợp với ghim đã chọn trước khi xác nhận.'),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: point == null || _busy || _address.text.trim().isEmpty ? null : () {
                  Navigator.of(context).pop(MapPlace(latitude: point.latitude,
                      longitude: point.longitude, address: _address.text.trim(),
                      providerPlaceId: _address.text.trim() == point.address
                          ? point.providerPlaceId : null));
                },
                child: const Text('Dùng vị trí này'),
              )),
            ],
          )),
        ]),
      ),
    );
  }
}
