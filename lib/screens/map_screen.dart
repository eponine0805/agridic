import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../utils/app_colors.dart';
import 'detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Post? _selectedPost;

  static const _gatanga = LatLng(-0.95, 36.87);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().detectLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final center = state.locationReady
            ? LatLng(state.currentLocation.$1, state.currentLocation.$2)
            : _gatanga;

        final officialPosts = state.visiblePosts.where((p) => p.isOfficial && p.location != null).toList();
        final farmerPosts = state.visiblePosts.where((p) => !p.isOfficial && p.location != null).toList();

        final markers = <Marker>[
          // Current location blue dot
          if (state.locationReady)
            Marker(
              point: center,
              width: 24,
              height: 24,
              child: const _CurrentLocationDot(),
            ),
          ...officialPosts.map((p) => Marker(
            point: LatLng(p.location!.$1, p.location!.$2),
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () => setState(() => _selectedPost = p),
              child: const Icon(Icons.location_on, color: Color(0xFFD32F2F), size: 30),
            ),
          )),
          ...farmerPosts.map((p) => Marker(
            point: LatLng(p.location!.$1, p.location!.$2),
            width: 16,
            height: 16,
            child: GestureDetector(
              onTap: () => setState(() => _selectedPost = p),
              child: const Icon(Icons.circle, color: AppColors.accent, size: 12),
            ),
          )),
        ];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Container(
                color: AppColors.primary,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Icon(Icons.map, color: Colors.white, size: 22),
                            const SizedBox(width: 4),
                            const Text('Map', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        if (state.isDetectingLocation)
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        else
                          Text(
                            '${officialPosts.length} reports',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 11.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.agridic.app',
                          maxZoom: 19,
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                    // Legend
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CurrentLocationDot(),
                            SizedBox(width: 4),
                            Text('You', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            SizedBox(width: 12),
                            Icon(Icons.location_on, color: Color(0xFFD32F2F), size: 16),
                            SizedBox(width: 4),
                            Text('Official', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            SizedBox(width: 12),
                            Icon(Icons.circle, color: AppColors.accent, size: 10),
                            SizedBox(width: 4),
                            Text('Farmer', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedPost != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: _buildInfoPanel(state, _selectedPost!),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoPanel(AppState state, Post post) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post.content.textShort,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'by ${post.userName} • ${state.formatTime(post.timestamp)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(post: post)));
            },
          ),
        ],
      ),
    );
  }
}

// Google Maps スタイルの現在地ドット
class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4285F4).withOpacity(0.18),
          ),
        ),
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 3, spreadRadius: 1),
            ],
          ),
        ),
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4285F4),
          ),
        ),
      ],
    );
  }
}
