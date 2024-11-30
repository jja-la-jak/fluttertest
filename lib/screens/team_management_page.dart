import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_project/services/token_storage.dart';

import '../config/environment.dart';
import '../modules/team_playlist_models.dart';
import '../service/team_playlist_service.dart';
import 'package:http/http.dart' as http;


class TeamManagementPage extends StatefulWidget {
  final int teamPlaylistId;

  const TeamManagementPage({
    Key? key,
    required this.teamPlaylistId,
  }) : super(key: key);

  @override
  State<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends State<TeamManagementPage> {
  late final TeamPlaylistApiService _teamPlaylistApiService;
  late final TeamPlaylistCollaborationService _collaborationService;
  final TokenStorage _tokenStorage = TokenStorage();

  List<TeamPlaylistMemberDto> _members = [];
  List<FriendDto> _friends = [];
  bool _isLoading = true;
  bool _showInvitePage = false;
  bool _isCurrentUserAdmin = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final accessToken = await _tokenStorage.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인이 필요합니다')),
          );
          Navigator.of(context).pop();
          return;
        }
      }

      setState(() {
        _teamPlaylistApiService = TeamPlaylistApiService(accessToken: accessToken);
        _collaborationService = TeamPlaylistCollaborationService(accessToken: accessToken);
      });

      await Future.wait([
        _loadMembers(),
        _loadFriends(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초기화 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _loadMembers() async {
    try {
      setState(() => _isLoading = true);
      final members = await _teamPlaylistApiService.getTeamPlaylistMembers(widget.teamPlaylistId);

      // 현재 사용자가 관리자인지 확인하는 부분 추가
      final currentUser = await _getCurrentUser();
      final isAdmin = members.any((member) =>
      member.isAdmin && member.email == currentUser['email']);

      if (mounted) {
        setState(() {
          _members = members;
          _isCurrentUserAdmin = isAdmin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('팀원 목록을 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _loadFriends() async {
    try {
      final String? accessToken = await _tokenStorage.getAccessToken();

      if (accessToken != null) {
        final response = await http.get(
          Uri.parse('${Environment.apiUrl}/teamPlaylists/${widget.teamPlaylistId}/invitable-members'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
          if (jsonResponse['isSuccess']) {
            final friendsList = List<Map<String, dynamic>>.from(jsonResponse['result']['members']);

            if (mounted) {
              setState(() {
                _friends = friendsList.map((friend) => FriendDto(
                  id: friend['user']['id'],
                  name: friend['user']['name'],
                  email: friend['user']['email'],
                  invited: friend['invited'],
                )).toList();
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('친구 목록을 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Widget _buildMainPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2D7B6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6C38A),
        elevation: 0,
        title: const Text(
          '팀원 관리',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,  // 추가
                children: [
                  const Text(
                    '팀원 목록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isCurrentUserAdmin) ...[
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _showInvitePage = true);
                      },
                      icon: const Icon(Icons.person_add, size: 20, color: Colors.blue),
                      label: const Text('팀원 초대', style: TextStyle(color: Colors.blue)),
                    ),
                  ] else ...[
                    TextButton.icon(
                      onPressed: _showLeaveConfirmDialog,
                      icon: const Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                      label: const Text('나가기', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_members.any((m) => m.isAdmin)) ...[
                  const Text(
                    '관리자',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._members.where((m) => m.isAdmin).map(_buildMemberCard),
                  const SizedBox(height: 16),
                ],
                if (_members.any((m) => !m.isAdmin)) ...[
                  const Text(
                    '팀원',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._members.where((m) => !m.isAdmin).map(_buildMemberCard),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitePage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2D7B6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6C38A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => setState(() => _showInvitePage = false),
        ),
        title: const Text(
          '팀원 초대',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: const [
                  Text(
                    '친구 목록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '(초대 가능한 친구)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _friends.length,
              itemBuilder: (context, index) {
                final friend = _friends[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      child: const Icon(Icons.person, color: Colors.grey),
                    ),
                    title: Text(friend.name),
                    subtitle: Text(friend.email),
                    trailing: friend.invited
                        ? ElevatedButton(
                      onPressed: () => _inviteFriend(friend),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black54,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('취소'),
                    )
                        : ElevatedButton(
                      onPressed: () => _inviteFriend(friend),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('초대'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(TeamPlaylistMemberDto member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: member.isAdmin ? Colors.orange[200] : Colors.grey[200],
          child: Icon(
            Icons.person,
            color: member.isAdmin ? Colors.orange[800] : Colors.grey[600],
          ),
        ),
        title: Text(member.name),
        subtitle: Text(member.email),
        trailing: _isCurrentUserAdmin && !member.isAdmin
            ? IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showMemberSettingsDialog(member),
        )
            : member.isAdmin
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '관리자',
            style: TextStyle(
              fontSize: 12,
              color: Colors.deepOrange,
            ),
          ),
        )
            : null,
      ),
    );
  }

  void _showMemberSettingsDialog(TeamPlaylistMemberDto member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('팀원 설정'),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.admin_panel_settings, color: Colors.blue[600]),
              title: const Text('관리자로 변경'),
              subtitle: const Text('플레이리스트 관리, 팀원 관리 권한 부여'),
              onTap: () {
                Navigator.pop(context);
                _updateMemberRole(member);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text('팀원 추방하기', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _removeMember(member);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteFriend(FriendDto friend) async {
    try {
      if (friend.invited) {
        await _collaborationService.cancelInvite(
          teamPlaylistId: widget.teamPlaylistId,
          friendId: friend.id,
        );

        if (mounted) {
          setState(() => friend.invited = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${friend.name}님의 초대를 취소했습니다')),
          );
        }
      } else {
        await _collaborationService.inviteFriend(
          teamPlaylistId: widget.teamPlaylistId,
          friendId: friend.id,
        );

        if (mounted) {
          setState(() => friend.invited = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${friend.name}님을 초대했습니다')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friend.invited ? '초대 취소' : '초대'}에 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _updateMemberRole(TeamPlaylistMemberDto member) async {
    try {
      await _teamPlaylistApiService.updateTeamPlaylistMemberRole(
        teamPlaylistId: widget.teamPlaylistId,
        memberId: member.memberId,
      );

      await _loadMembers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name}님을 ${!member.isAdmin ? '관리자로 변경' : '일반 팀원으로 변경'}했습니다'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('권한 변경에 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(TeamPlaylistMemberDto member) async {
    try {
      await _teamPlaylistApiService.removeTeamPlaylistMember(
        teamPlaylistId: widget.teamPlaylistId,
        memberId: member.memberId,
      );

      // 팀원 목록과 초대 가능한 친구 목록을 모두 새로고침
      await Future.wait([
        _loadMembers(),
        _loadFriends(),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name}님을 팀에서 제외했습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('팀원 삭제에 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _showLeaveConfirmDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('팀 나가기'),
          content: const Text('정말로 이 팀을 나가시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('나가기', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _leaveTeam();
              },
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getCurrentUser() async {
    final accessToken = await _tokenStorage.getAccessToken();
    final response = await http.get(
      Uri.parse('${Environment.apiUrl}/users/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
      return jsonResponse['result'];
    }
    throw Exception('Failed to get current user');
  }

  Future<void> _leaveTeam() async {
    try {
      final currentUser = await _getCurrentUser();
      final currentMember = _members.firstWhere(
              (member) => member.email == currentUser['email']
      );

      await _teamPlaylistApiService.removeTeamPlaylistMember(
        teamPlaylistId: widget.teamPlaylistId,
        memberId: currentMember.memberId,
      );

      if (mounted) {
        Navigator.of(context).pop(true); // 팀 관리 페이지 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('팀을 나갔습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('팀 나가기에 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _showInvitePage ? _buildInvitePage() : _buildMainPage();
  }
}

class FriendDto {
  final int id;
  final String name;
  final String email;
  late bool invited;

  FriendDto({
    required this.id,
    required this.name,
    required this.email,
    required this.invited,
  });
}