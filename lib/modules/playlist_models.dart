class PlaylistPreViewListDto {
  final List<PlaylistPreViewDto> playlistPreviewList;
  final int listSize;
  final int totalPage;
  final int totalElements;
  final bool isFirst;
  final bool isLast;

  PlaylistPreViewListDto({
    required this.playlistPreviewList,
    required this.listSize,
    required this.totalPage,
    required this.totalElements,
    required this.isFirst,
    required this.isLast,
  });

  factory PlaylistPreViewListDto.fromJson(Map<String, dynamic> json) {
    return PlaylistPreViewListDto(
      playlistPreviewList: (json['playlistPreviewList'] as List)
          .map((i) => PlaylistPreViewDto.fromJson(i))
          .toList(),
      listSize: json['listSize'],
      totalPage: json['totalPage'],
      totalElements: json['totalElements'],
      isFirst: json['isFirst'],
      isLast: json['isLast'],
    );
  }
}

class PlaylistPreViewDto {
  final int playlistId;
  final String name;
  final DateTime createdDate;

  PlaylistPreViewDto({
    required this.playlistId,
    required this.name,
    required this.createdDate,
  });

  factory PlaylistPreViewDto.fromJson(Map<String, dynamic> json) {
    return PlaylistPreViewDto(
      playlistId: json['playlistId'],
      name: json['name'],
      createdDate: DateTime.parse(json['createdDate']),
    );
  }
}

class PlaylistMusicListDto {
  final List<PlaylistMusicDto> musicList;
  final int listSize;
  final int totalPage;
  final int totalElements;
  final bool isFirst;
  final bool isLast;

  PlaylistMusicListDto({
    required this.musicList,
    required this.listSize,
    required this.totalPage,
    required this.totalElements,
    required this.isFirst,
    required this.isLast,
  });

  factory PlaylistMusicListDto.fromJson(Map<String, dynamic> json) {
    return PlaylistMusicListDto(
      musicList: (json['musicList'] as List)
          .map((i) => PlaylistMusicDto.fromJson(i))
          .toList(),
      listSize: json['listSize'],
      totalPage: json['totalPage'],
      totalElements: json['totalElements'],
      isFirst: json['isFirst'],
      isLast: json['isLast'],
    );
  }
}

class PlaylistMusicDto {
  final int playlistMusicMappingId;
  final int musicId;
  final String title;
  final String artist;
  final String url;
  final int viewCount;
  final String thumbnail;

  PlaylistMusicDto({
    required this.playlistMusicMappingId,
    required this.musicId,
    required this.title,
    required this.artist,
    required this.url,
    required this.viewCount,
    required this.thumbnail,
  });

  factory PlaylistMusicDto.fromJson(Map<String, dynamic> json) {
    return PlaylistMusicDto(
      playlistMusicMappingId: json['playlistMusicMappingId'] ?? 0,
      musicId: json['musicId'] ?? 0,  // 'musicId' 대신 'id' 사용
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      url: json['url'] ?? '',
      viewCount: json['viewCount'] ?? 0,
      thumbnail: json['thumbnail'] ?? '',
    );
  }
}

class PlaylistDetailDto {
  final int playlistId;
  final String name;
  final DateTime createdDate;
  final List<PlaylistMusicDto> playlistMusicList;

  PlaylistDetailDto({
    required this.playlistId,
    required this.name,
    required this.createdDate,
    required this.playlistMusicList,
  });

  factory PlaylistDetailDto.fromJson(Map<String, dynamic> json) {
    return PlaylistDetailDto(
      playlistId: json['playlistId'],
      name: json['name'],
      createdDate: DateTime.parse(json['createdDate']),
      playlistMusicList: (json['playlistMusicList'] as List)
          .map((music) => PlaylistMusicDto.fromJson(music))
          .toList(),
    );
  }
}