import 'package:flutter/material.dart';
import 'package:flutter_project/screens/playlist_page.dart';
import 'package:flutter_project/screens/chatting.dart';
import 'package:flutter_project/modules/search_music.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class CustomScaffold extends StatefulWidget {
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onTabTapped;

  const CustomScaffold({
    Key? key,
    required this.body,
    required this.currentIndex,
    required this.onTabTapped,
  }) : super(key: key);

  @override
  State<CustomScaffold> createState() => _CustomScaffoldState();
}

class _CustomScaffoldState extends State<CustomScaffold> {
  static const double _kAppBarHeight = 56.0;
  static const double _kBottomNavBarHeight = 60.0;
  static const double _kIconSize = 36.0;
  static const double _kSearchBarBorderRadius = 20.0;
  static const double _kSearchIconPadding = 8.0;

  final TextEditingController _searchController = TextEditingController();
  List<Music> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      final results = await searchMusic(query);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검색 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2D7B6),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_showResults)
            Expanded(
              child: _searchResults.isEmpty && !_isSearching
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final music = _searchResults[index];
                  return ListTile(
                    title: Text(music.title),
                    subtitle: Text(music.artist),
                    trailing: Text('조회수: ${music.viewCount}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => YoutubePlayerScreen(youtubeUrl: music.url),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          else
            Expanded(child: widget.body),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(_kAppBarHeight),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: _buildSearchBar(),
        actions: _buildAppBarActions(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(_kSearchBarBorderRadius),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black54),
            onPressed: _performSearch,
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '검색',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black54),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                  _showResults = false;
                });
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      _buildCircleAvatarButton('assets/profile.png', () {}),
      _buildCircleAvatarButton('assets/profile.png', () {}),
    ];
  }

  Widget _buildCircleAvatarButton(String assetName, VoidCallback onPressed) {
    return IconButton(
      icon: CircleAvatar(
        radius: 18,
        backgroundImage: AssetImage(assetName),
        backgroundColor: Colors.transparent,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return SizedBox(
      height: _kBottomNavBarHeight,
      child: Row(
        children: [
          _buildNavItem(context, Icons.tiktok, 0, const Color(0xFFF6C48A)),
          _buildNavItem(context, Icons.chat_bubble_outline, 1, const Color(0xFFE89D63)),
          _buildNavItem(context, Icons.star_border, 2, const Color(0xFFF6C48A)),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, int index, Color color) {
    final isSelected = widget.currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          widget.onTabTapped(index);
          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PlaylistPage()),
            );
          }
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Chatting()),
            );
          }
        },
        child: Container(
          color: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black : Colors.black54,
                size: _kIconSize,
              ),
              const SizedBox(height: 4),
              Container(
                height: 4,
                width: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.black : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class YoutubePlayerScreen extends StatefulWidget {
  final String youtubeUrl;

  const YoutubePlayerScreen({Key? key, required this.youtubeUrl}) : super(key: key);

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl);
    _controller = YoutubePlayerController(
      initialVideoId: videoId!,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Player'),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}