import 'package:flutter/material.dart';
// Note: You must add 'http', 'just_audio', and 'file_picker' to your pubspec.yaml
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

// --- Global Constants & Theme ---
const Color primaryColor = Color(0xFF673AB7); // Deep Purple
const Color accentColor = Color(0xFFE91E63); // Pink
const TextStyle infoTextStyle = TextStyle(color: Colors.white70, fontSize: 14);

// --- Main Application Widget ---
void main() {
  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal Music Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor, brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const MusicPlayerScreen(),
    );
  }
}

// --- Player Screen ---
class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  // Audio Player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Configuration and State
  final TextEditingController _baseApiUrlController = TextEditingController(text: "https://tidal.401658.xyz");
  final TextEditingController _searchController = TextEditingController(text: "Consequence");

  String _currentTrackTitle = "No Track Loaded";
  String _currentTrackArtist = "Ready";
  String? _currentStreamUrl;
  String? _localFilePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.ready) {
        setState(() => _isLoading = false);
      }
      if (state.processingState == ProcessingState.loading) {
        setState(() => _isLoading = true);
      }
    });
  }

  // --- API Handlers ---

  Future<void> _searchTrack() async {
    final query = _searchController.text.trim();
    final baseUrl = _baseApiUrlController.text.trim();
    if (query.isEmpty || baseUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentTrackTitle = "Searching...";
      _currentTrackArtist = "";
    });

    final searchUrl = Uri.parse('$baseUrl/search/?s=$query');

    try {
      final response = await http.get(searchUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;

        if (items.isNotEmpty) {
          final track = items[0];
          final trackId = track['id'];
          final title = track['title'];
          final artist = track['artist']['name'];

          setState(() {
            _currentTrackTitle = title;
            _currentTrackArtist = artist;
          });

          await _fetchStreamUrl(trackId, baseUrl);
        } else {
          _updateStatus("No results found for '$query'.", isError: true);
        }
      } else {
        _updateStatus("Search API failed: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _updateStatus("Network Error during search: $e", isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchStreamUrl(int trackId, String baseUrl) async {
    _updateStatus("Fetching high-quality stream link...", isError: false);
    final songUrl = Uri.parse('$baseUrl/song/?id=$trackId&quality=HI_RES');

    try {
      final response = await http.get(songUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final streamUrl = data['OriginalTrackUrl'];

        if (streamUrl is String && streamUrl.isNotEmpty) {
          setState(() {
            _currentStreamUrl = streamUrl;
            _updateStatus("Stream link ready.");
          });
        } else {
          _updateStatus("Stream URL not found in response.", isError: true);
        }
      } else {
        _updateStatus("Song API failed: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _updateStatus("Network Error fetching stream link: $e", isError: true);
    }
  }

  // --- Playback Handlers ---

  Future<void> _playStream() async {
    if (_currentStreamUrl != null) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(_currentStreamUrl!);
        await _audioPlayer.play();
        _updateStatus("Streaming: $_currentTrackTitle");
      } catch (e) {
        _updateStatus("Error loading stream: $e", isError: true);
      }
    } else {
      _updateStatus("No stream URL available. Please search first.", isError: true);
    }
  }

  Future<void> _selectLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _localFilePath = result.files.single.path;
          _currentTrackTitle = result.files.single.name;
          _currentTrackArtist = "Local File";
          _currentStreamUrl = null; // Clear stream URL context
          _updateStatus("Local file selected.");
        });
      }
    } catch (e) {
      _updateStatus("Error selecting local file: $e", isError: true);
    }
  }

  Future<void> _playLocalFile() async {
    if (_localFilePath != null) {
      try {
        await _audioPlayer.stop();
        // Use setFilePath for local files
        await _audioPlayer.setFilePath(_localFilePath!); 
        await _audioPlayer.play();
        _updateStatus("Playing local file: $_currentTrackTitle");
      } catch (e) {
        _updateStatus("Error playing local file: $e", isError: true);
      }
    } else {
      _updateStatus("No local file selected.", isError: true);
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    _updateStatus("Playback stopped.");
  }

  // --- Utility ---

  void _updateStatus(String message, {bool isError = false}) {
    // Use a temporary snackbar for notifications
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? accentColor : primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
    // Also update main status, though this example uses title/artist for main display
    print("Status: $message");
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _baseApiUrlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- UI Builder ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal Music Player'),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // API Configuration Card
            _buildConfigCard(),
            const SizedBox(height: 20),

            // Music Card (Info Display and Controls)
            _buildMusicCard(),
            const SizedBox(height: 30),
            
            // Local Playback Section
            _buildLocalPlaybackSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("API Configuration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 10),
            TextField(
              controller: _baseApiUrlController,
              decoration: InputDecoration(
                labelText: "Base API URL",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.api, color: accentColor),
              ),
              style: infoTextStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicCard() {
    final bool canPlayStream = _currentStreamUrl != null;
    final bool canPlayLocal = _localFilePath != null;
    final bool isPlaying = _audioPlayer.playerState.playing;

    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E2C), Color(0xFF3A005F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Track Info Display
            const Icon(Icons.music_note, size: 48, color: accentColor),
            const SizedBox(height: 10),
            Text(
              _currentTrackTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              _currentTrackArtist,
              textAlign: TextAlign.center,
              style: infoTextStyle,
            ),
            const SizedBox(height: 20),

            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search for a song...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                    ),
                    onSubmitted: (_) => _searchTrack(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _searchTrack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stream Playback Control
            ElevatedButton.icon(
              onPressed: canPlayStream && !_isLoading ? _playStream : null,
              icon: const Icon(Icons.cloud_download, color: Colors.white),
              label: const Text('Play Streamed Track'),
              style: ElevatedButton.styleFrom(
                backgroundColor: canPlayStream ? accentColor : Colors.grey,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 15),

            // Universal Playback Controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPlaying ? () => _audioPlayer.pause() : () => _audioPlayer.play(),
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 30),
                    label: Text(isPlaying ? 'Pause' : 'Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPlaying ? Colors.orange : Colors.green,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stopPlayback,
                    icon: const Icon(Icons.stop_circle_filled, size: 30),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalPlaybackSection() {
    final bool canPlayLocal = _localFilePath != null;
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Local Playback", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _localFilePath ?? "No local file selected.",
                    overflow: TextOverflow.ellipsis,
                    style: infoTextStyle,
                  ),
                ),
                ElevatedButton(
                  onPressed: _selectLocalFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Browse File'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: canPlayLocal ? _playLocalFile : null,
              icon: const Icon(Icons.folder_open, color: Colors.white),
              label: const Text('Play Local File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: canPlayLocal ? primaryColor : Colors.grey,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

