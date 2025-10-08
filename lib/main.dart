import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const TidalPlayerApp());
}

class TidalPlayerApp extends StatelessWidget {
  const TidalPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tidal Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const SearchPage(),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _player = AudioPlayer();

  bool _loading = false;
  bool _isPlaying = false;
  String? _currentTitle;

  List<dynamic> _tracks = [];
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _playlist = [];

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((event) {
      _playNextInQueue();
    });
  }

  Future<void> _searchTrack() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _tracks = [];
    });

    final url = Uri.parse('https://tidal.401658.xyz/search/?s=$query');
    print('🔍 Searching tracks for query: $query');
    print('🌍 API Request: $url');

    try {
      final res = await http.get(url);
      print('✅ Response Status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded.containsKey('items')) {
          setState(() => _tracks = decoded['items']);
        } else {
          setState(() => _tracks = []);
        }
      }
    } catch (e) {
      print('🚨 Exception during search: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _playTrack(Map<String, dynamic> track) async {
    final id = track['id'];
    final title = track['title'] ?? 'Unknown Title';
    final quality = track['audioQuality'] ?? 'LOSSLESS';

    print('▶ Playing track: $title (ID: $id)');
    final url = Uri.parse('https://tidal.401658.xyz/track/?id=$id&quality=$quality');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.length > 2) {
          final trackUrl = decoded[2]['OriginalTrackUrl'];
          if (trackUrl != null && trackUrl.toString().isNotEmpty) {
            await _player.stop();
            await _player.play(UrlSource(trackUrl));
            setState(() {
              _isPlaying = true;
              _currentTitle = title;
            });
          }
        }
      }
    } catch (e) {
      print('🚨 Failed to play track: $e');
    }
  }

  void _playNextInQueue() {
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _playTrack(next);
    } else {
      setState(() {
        _isPlaying = false;
        _currentTitle = null;
      });
    }
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.resume();
      setState(() => _isPlaying = true);
    }
  }

  void _addToQueue(Map<String, dynamic> track) {
    _queue.add(track);
    print('➕ Added to queue: ${track['title']}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to queue: ${track['title']}')),
    );
  }

  void _addToPlaylist(Map<String, dynamic> track) {
    _playlist.add(track);
    print('🎵 Added to playlist: ${track['title']}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added to playlist: ${track['title']}')),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _showQueue() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: _queue.length,
        itemBuilder: (_, index) {
          final track = _queue[index];
          return ListTile(
            title: Text(track['title']),
            subtitle: Text(track['artist']?['name'] ?? 'Unknown Artist'),
            onTap: () {
              Navigator.pop(context);
              _playTrack(track);
            },
          );
        },
      ),
    );
  }

  void _showPlaylist() {
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: _playlist.length,
        itemBuilder: (_, index) {
          final track = _playlist[index];
          return ListTile(
            title: Text(track['title']),
            subtitle: Text(track['artist']?['name'] ?? 'Unknown Artist'),
            onTap: () {
              Navigator.pop(context);
              _playTrack(track);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tidal Player'),
        actions: [
          IconButton(icon: const Icon(Icons.queue_music), onPressed: _showQueue),
          IconButton(icon: const Icon(Icons.playlist_play), onPressed: _showPlaylist),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter track name',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _controller.clear,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _searchTrack,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_tracks.isEmpty)
              const Text('No results found.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _tracks.length,
                  itemBuilder: (context, index) {
                    final track = _tracks[index];
                    final title = track['title'] ?? 'Unknown Title';
                    final artist = track['artist']?['name'] ?? 'Unknown Artist';
                    final album = track['album']?['title'] ?? 'Unknown Album';
                    final duration = track['duration'] ?? 0;

                    final coverId = track['album']?['cover'];
                    final imageUrl = coverId != null
                        ? 'https://resources.tidal.com/images/$coverId/320x320.jpg'
                        : null;

                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  width: 55,
                                  height: 55,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.music_note),
                                )
                              : const Icon(Icons.music_note, size: 40),
                        ),
                        title: Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('$artist • $album'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () => _playTrack(track),
                            ),
                            IconButton(
                              icon: const Icon(Icons.queue),
                              onPressed: () => _addToQueue(track),
                            ),
                            IconButton(
                              icon: const Icon(Icons.playlist_add),
                              onPressed: () => _addToPlaylist(track),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (_isPlaying && _currentTitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: _togglePlayPause,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        "🎶 Now Playing: $_currentTitle",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
