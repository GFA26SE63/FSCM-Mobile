import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:fscm_mobile/core/network/api_exception.dart';
import 'package:fscm_mobile/data/models/map_place.dart';
import 'package:fscm_mobile/data/repositories/map_repository.dart';

/// Whether the address text is known to belong to the current pin.
enum _AddressState {
  /// No pin yet.
  none,

  /// From VietMap for this pin (Place / Reverse) or the location confirmed earlier.
  verified,

  /// Reverse geocoding for this pin is in flight.
  resolving,

  /// Reverse geocoding found nothing or failed.
  unresolved,

  /// The user typed the address after placing the pin.
  manual,
}

/// Selection stays local until the caller saves the retailer declaration.
class MapLocationPicker extends ConsumerStatefulWidget {
  const MapLocationPicker({
    super.key,
    required this.address,
    this.initial,
    @visibleForTesting this.tileProvider,
    @visibleForTesting this.searchDelay = const Duration(milliseconds: 450),
  });

  /// Current address text of the form.
  final String address;

  /// Location confirmed earlier; its [MapPlace.address] is the address that
  /// was confirmed together with the pin.
  final MapPlace? initial;
  final TileProvider? tileProvider;
  final Duration searchDelay;

  @override
  ConsumerState<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends ConsumerState<MapLocationPicker> {
  static const unresolvedMessage =
      'Chưa tìm được địa chỉ tại vị trí này. Vui lòng nhập hoặc kiểm tra lại địa chỉ.';

  final _map = MapController();
  late final TextEditingController _address;
  MapPlace? _selected;
  _AddressState _addressState = _AddressState.none;
  bool _addressChecked = false;
  List<MapSuggestion> _suggestions = const [];
  String? _searchError;
  String? _locationError;
  bool _searching = false;
  bool _searched = false;
  bool _resolvingPlace = false;
  String _lastQuery = '';
  bool _tileError = false;
  int _tileVersion = 0;
  Timer? _debounce;
  // Only the newest request of each kind may touch state; older ones are dropped.
  int _searchRequest = 0;
  int _selectionRequest = 0;

  MapRepository get _repo => ref.read(mapRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.address);
    final initial = widget.initial;
    if (initial != null) {
      _selected = initial;
      _addressState = initial.address.trim() == widget.address.trim()
          ? _AddressState.verified
          : _AddressState.manual;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _address.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onAddressChanged(String value) {
    // Typing wins over any address still being resolved for the pin.
    _selectionRequest++;
    setState(() {
      _resolvingPlace = false;
      _locationError = null;
      if (_selected != null) {
        _addressState = _AddressState.manual;
        _addressChecked = false;
      }
    });
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      _searchRequest++;
      setState(() {
        _suggestions = const [];
        _searching = false;
        _searched = false;
        _searchError = null;
      });
      return;
    }
    _debounce = Timer(widget.searchDelay, () => _search(query));
  }

  void _searchNow() {
    _debounce?.cancel();
    final query = _address.text.trim();
    if (query.length < 2) {
      setState(() => _searchError = 'Nhập ít nhất 2 ký tự để tìm địa chỉ.');
      return;
    }
    FocusScope.of(context).unfocus();
    _search(query, force: true);
  }

  Future<void> _search(String query, {bool force = false}) async {
    if (!mounted || !_repo.isSearchConfigured) {
      return;
    }
    if (!force && _searched && query == _lastQuery) {
      return;
    }
    final request = ++_searchRequest;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await _repo.search(query);
      if (!mounted || request != _searchRequest) {
        return;
      }
      setState(() {
        _suggestions = results;
        _searched = true;
        _lastQuery = query;
      });
    } on ApiException catch (error) {
      if (!mounted || request != _searchRequest) {
        return;
      }
      setState(() {
        _suggestions = const [];
        _searched = false;
        _searchError = error.message;
      });
    } finally {
      if (mounted && request == _searchRequest) {
        setState(() => _searching = false);
      }
    }
  }

  /// Drops pending searches and resolutions before a new pin is chosen.
  int _beginSelection() {
    _debounce?.cancel();
    _searchRequest++;
    return ++_selectionRequest;
  }

  Future<void> _choose(MapSuggestion suggestion) async {
    final request = _beginSelection();
    FocusScope.of(context).unfocus();
    setState(() {
      _resolvingPlace = true;
      _locationError = null;
      _suggestions = const [];
      _searching = false;
      _searched = false;
    });
    try {
      final place = await _repo.place(suggestion);
      if (!mounted || request != _selectionRequest) {
        return;
      }
      setState(() {
        _selected = place;
        _address.text = place.address;
        _addressState = _AddressState.verified;
        _addressChecked = false;
      });
      // The controller is only attached when the base map is rendered.
      if (_repo.isMapConfigured) {
        _map.move(LatLng(place.latitude, place.longitude), 17);
      }
    } on ApiException catch (error) {
      if (!mounted || request != _selectionRequest) {
        return;
      }
      setState(() => _locationError = error.message);
    } finally {
      if (mounted && request == _selectionRequest) {
        setState(() => _resolvingPlace = false);
      }
    }
  }

  Future<void> _onMapTap(LatLng location) async {
    if (_tileError) {
      return;
    }
    final request = _beginSelection();
    final latitude = location.latitude;
    final longitude = location.longitude;
    setState(() {
      // The marker moves at once; the old address is not reused for this pin.
      _selected =
          MapPlace(latitude: latitude, longitude: longitude, address: '');
      _addressState = _AddressState.resolving;
      _addressChecked = false;
      _locationError = null;
      _resolvingPlace = false;
      _suggestions = const [];
      _searching = false;
      _searched = false;
    });
    try {
      final address = await _repo.reverse(latitude, longitude);
      if (!mounted || request != _selectionRequest) {
        return;
      }
      setState(() {
        if (address == null) {
          _addressState = _AddressState.unresolved;
          _locationError = unresolvedMessage;
        } else {
          _address.text = address;
          _selected = MapPlace(
              latitude: latitude, longitude: longitude, address: address);
          _addressState = _AddressState.verified;
        }
      });
    } catch (error) {
      if (!mounted || request != _selectionRequest) {
        return;
      }
      setState(() {
        _addressState = _AddressState.unresolved;
        _locationError = error is ApiException
            ? '$unresolvedMessage\n${error.message}'
            : unresolvedMessage;
      });
    }
  }

  bool get _needsCheck =>
      _addressState == _AddressState.unresolved ||
      _addressState == _AddressState.manual;

  bool get _canConfirm =>
      _selected != null &&
      !_resolvingPlace &&
      _addressState != _AddressState.resolving &&
      _address.text.trim().isNotEmpty &&
      (!_needsCheck || _addressChecked);

  void _confirm() {
    final point = _selected!;
    final address = _address.text.trim();
    // A provider reference is kept only while the text is the provider's own.
    final verified = _addressState == _AddressState.verified &&
        address == point.address.trim();
    Navigator.of(context).pop(MapPlace(
        latitude: point.latitude,
        longitude: point.longitude,
        address: address,
        providerPlaceId: verified ? point.providerPlaceId : null));
  }

  @override
  Widget build(BuildContext context) {
    final point = _selected;
    final repo = ref.watch(mapRepositoryProvider);
    final mapReady = repo.isMapConfigured;
    final searchReady = repo.isSearchConfigured;
    final errorColor = Theme.of(context).colorScheme.error;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn vị trí điểm bán')),
      body: SafeArea(
        child: Column(children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _address,
                    onChanged: _onAddressChanged,
                    decoration: const InputDecoration(
                        labelText: 'Địa chỉ điểm bán',
                        hintText: 'Số nhà, đường, phường/xã, tỉnh/thành'),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchNow(),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: searchReady ? _searchNow : null,
                        icon: const Icon(Icons.search),
                        label: const Text('Tìm địa chỉ'),
                      )),
                  if (!searchReady)
                    Text(
                        'Chưa cấu hình dịch vụ tìm địa chỉ của bản đồ. '
                        'Vui lòng liên hệ quản trị viên.'
                        '${mapReady ? ' Bạn vẫn có thể chạm bản đồ để đặt ghim và nhập địa chỉ thủ công.' : ''}',
                        style: TextStyle(color: errorColor)),
                  if (_searching || _resolvingPlace)
                    const LinearProgressIndicator(),
                  if (_searchError != null)
                    Text(_searchError!, style: TextStyle(color: errorColor)),
                  if (_searched &&
                      _suggestions.isEmpty &&
                      _searchError == null &&
                      !_searching)
                    const Text(
                        'Không tìm thấy địa chỉ. Thử nhập chi tiết hơn hoặc chọn ghim trên bản đồ.'),
                  if (_addressState == _AddressState.resolving)
                    const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Row(children: <Widget>[
                          SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Đang tìm địa chỉ...'),
                        ])),
                  if (_locationError != null)
                    Text(_locationError!, style: TextStyle(color: errorColor)),
                ]),
          ),
          Expanded(
            child: Stack(children: <Widget>[
              if (mapReady) ...<Widget>[
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    // Initial viewport only; it is never saved as a selection.
                    initialCenter: point == null
                        ? const LatLng(10.7769, 106.7009)
                        : LatLng(point.latitude, point.longitude),
                    initialZoom: point == null ? 12 : 17,
                    minZoom: 3, maxZoom: 19,
                    onTap: (_, location) => _onMapTap(location),
                  ),
                  children: <Widget>[
                    TileLayer(
                      key: ValueKey(_tileVersion),
                      urlTemplate: repo.tileUrlTemplate,
                      userAgentPackageName: 'vn.edu.fpt.fscm.fscm_mobile',
                      tileProvider: widget.tileProvider,
                      errorTileCallback: (_, __, ___) {
                        if (!mounted || _tileError) {
                          return;
                        }
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => _tileError = true);
                          }
                        });
                      },
                    ),
                    if (point != null)
                      MarkerLayer(markers: <Marker>[
                        Marker(
                            point: LatLng(point.latitude, point.longitude),
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_pin,
                                size: 44, color: Colors.red)),
                      ]),
                  ],
                ),
                const Positioned(
                    bottom: 4,
                    right: 8,
                    child: ColoredBox(
                        color: Colors.white,
                        child:
                            Text('© VIETMAP', style: TextStyle(fontSize: 11)))),
                if (_tileError)
                  Align(
                      alignment: Alignment.topCenter,
                      child: Card(
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Text(
                                    'Không tải được bản đồ. Kiểm tra kết nối rồi thử lại.'),
                                TextButton(
                                    onPressed: () => setState(() {
                                          _tileError = false;
                                          _tileVersion++;
                                        }),
                                    child: const Text('Tải lại bản đồ')),
                              ],
                            )),
                      )),
              ] else
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Chưa cấu hình dịch vụ hiển thị bản đồ. '
                            'Vui lòng liên hệ quản trị viên.'))),
              // Suggestions float over the map so they stay visible while typing,
              // and still show when only the search key is configured.
              // Taps outside the card still reach the map.
              if (_suggestions.isNotEmpty)
                Positioned.fill(
                  left: 8,
                  right: 8,
                  child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.3),
                        child: Card(
                            margin: EdgeInsets.zero,
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _suggestions.length,
                              itemBuilder: (_, index) => ListTile(
                                leading: const Icon(Icons.place_outlined),
                                title: Text(_suggestions[index].display),
                                onTap: () => _choose(_suggestions[index]),
                              ),
                            )),
                      )),
                ),
            ]),
          ),
          if (!keyboardOpen)
            Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(point == null
                        ? 'Tìm địa chỉ hoặc chạm bản đồ để đặt ghim.'
                        : 'Tọa độ: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
                    if (point != null && _needsCheck)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _addressChecked,
                        onChanged: (value) =>
                            setState(() => _addressChecked = value ?? false),
                        title: const Text(
                            'Tôi đã kiểm tra địa chỉ khớp với vị trí ghim'),
                      )
                    else
                      const Text(
                          'Kiểm tra địa chỉ phù hợp với ghim đã chọn trước khi xác nhận.'),
                    const SizedBox(height: 8),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _canConfirm ? _confirm : null,
                          child: const Text('Dùng vị trí này'),
                        )),
                  ],
                )),
        ]),
      ),
    );
  }
}
