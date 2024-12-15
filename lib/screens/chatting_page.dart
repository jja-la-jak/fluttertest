import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_project/modules/custom_scaffold.dart';
import 'package:path_provider/path_provider.dart';

class Chatting extends StatefulWidget {
  const Chatting({Key? key}) : super(key: key);

  @override
  _ChattingState createState() => _ChattingState();
}

class _ChattingState extends State<Chatting> {
  int _currentIndex = 1;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final int _maxUploadableImages = 5;
  final int _maxInputLines = 5;
  List<Map<String, dynamic>> _messages = [];
  List<XFile> _uploadedImages = [];

  Future<String> _getLocalPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }



  final String chatServerUrl = "https://gnumusic.shop";
  // final String messageServerUrl = "http://117.16.153.90:8080";
  final String messageServerUrl = "http://54.173.148.216";

  bool _showScrollToBottomButton = false;

  @override
  void initState() {
    super.initState();
    //_fetchChatHistory();
    _loadChatHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.atEdge &&
        _scrollController.position.pixels != 0) {
      setState(() {
        _showScrollToBottomButton = false;
      });
    } else {
      setState(() {
        _showScrollToBottomButton = true;
      });
    }
  }

  Future<void> _saveChatHistory() async {
    final path = await _getLocalPath();
    final file = File('$path/chat_history.json');

    // 메시지 저장할 데이터 생성
    final data = _messages.map((message) {
      if (message['contentType'] == 'image') {
        return {
          'type': message['type'],
          'contentType': 'image',
          'imagePath': message['imagePath']
        };
      } else if(message['contentType'] == 'text'){
        if(message["type"] == "received"){
          return {
            'type': message['type'],
            'contentType': 'text',
            'text': message['text'],
            'artistName': message['artistName'],
            'songName': message['songName'],
          };
        }
        else {
          return {
            'type': message['type'],
            'contentType': 'text',
            'text': message['text']
          };
        }
      }
      else if(message['contentType'] == 'search_button'){
        return {
          'type': message['type'],
          'contentType': 'search_button',
          'artistName': message["artistName"],
          'songName': message["songName"]
        };
      }
    }).toList();

    // JSON으로 변환 후 파일 저장
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> _loadChatHistory() async {
    final path = await _getLocalPath();
    final file = File('$path/chat_history.json');

    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data);
      });

      // 스크롤을 맨 아래로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _deleteChatHistory() async {
    final path = await _getLocalPath();
    final file = File('$path/chat_history.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _saveImageFile(XFile image) async {
    final path = await _getLocalPath();
    final newFilePath = '$path/${image.name}';

    // 파일 복사
    await File(image.path).copy(newFilePath);

    setState(() {
      _messages.add({
        'type': 'sent',
        'contentType': 'image',
        'imagePath': newFilePath,
      });
      _saveChatHistory(); // 메시지 변경 후 저장
    });
  }


  Future<void> _fetchChatHistory() async {
    try {
      final response = await http.get(Uri.parse('$chatServerUrl/api/chats'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _messages = data
              .map((message) => {
            "type": message["type"],
            "text": message["text"]
          })
              .toList();
        });
      } else {
        print("Failed to load chat history: ${response.statusCode}");
      }
    } catch (error) {
      print("Error fetching chat history: $error");
    }
  }

  Future<void> _sendMessage() async {
    print("업로드한 이미지 개수 : ${_uploadedImages.length}");
    final text = _textController.text.trim();
    if (text.isNotEmpty || _uploadedImages.isNotEmpty) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$messageServerUrl/predict'),
        );

        // 텍스트 추가
        if (text.isNotEmpty) {
          request.fields['text'] = text;
        }

        // 이미지 추가
        if (_uploadedImages.isNotEmpty) {
          final image = _uploadedImages.first; // 첫 번째 이미지 가져오기
          request.files.add(await http.MultipartFile.fromPath('file', image.path));
        }
        // for (final image in _uploadedImages) {
        //   request.files.add(await http.MultipartFile.fromPath('file', image.path));
        // }

        final response = await request.send();
        print("메세지 전송 Response Status : ${response.statusCode}");
        print(response);
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final result = json.decode(responseData);

          setState(() async {
            if(_uploadedImages.isNotEmpty){
              final image = _uploadedImages.first; // 첫 번째 이미지 가져오기
              await _saveImageFile(image);
              // setState(() {
              //   _messages.add({
              //     "type": "sent",
              //     "contentType": "image",
              //     "imagePath": image.path
              //   });
              //   _saveChatHistory();
              // });

            }
            // 사용자가 보낸 메시지 추가
            if (text.isNotEmpty) {
              setState(() {
                _messages.add({
                  "type": "sent",
                  "contentType": "text",
                  "text": text
                });
                _saveChatHistory();
              });

            }


            // 서버 응답 메시지 추가
            print("Result : $result");
            final artistName = result["artistName"];
            final songName = result["songName"];
            final resultText = result["result"];
            final message = result["message"];
            print("Server Message : $message");
            setState(() {
              // 서버 응답 메세지
              _messages.add({
                "type": "received",
                "contentType": "text",
                "text": resultText,
                "artistName": artistName,
                "songName": songName
              });

              // 추천된 노래 검색 버튼 추가
              _messages.add({
                "type": "received",
                "contentType": "search_button",
                "artistName": artistName,
                "songName": songName,
              });
              _saveChatHistory();

              // 업로드한 이미지 초기화
              _uploadedImages.clear();
              // 텍스트 필드 초기화
              _textController.clear();
            });
          });

          // 스크롤 맨 아래로 이동
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          print("Failed to send message: ${response.statusCode}");
        }
      } catch (error) {
        print("Error sending message: $error");
      }
    }
  }

  Future<XFile?> compressImage(File file) async {
    final filePath = file.absolute.path;

    // 압축 파일 경로 생성
    final lastIndex = filePath.lastIndexOf('.');
    final outPath = filePath.substring(0, lastIndex) + '_compressed.jpg';

    final compressedImage = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outPath,
      quality: 70, // 압축 품질 (0 ~ 100)
    );

    return compressedImage;
  }

  Future<void> _attachFile() async {
    if (_uploadedImages.length >= _maxUploadableImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("이미지는 최대 $_maxUploadableImages개까지만 업로드할 수 있습니다.")),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final compressedFile = await compressImage(file);
      setState(() {
        _uploadedImages.add(compressedFile!);
      });

      // 채팅 저장 로직
      // try {
      //   final request = http.MultipartRequest(
      //     'POST',
      //     Uri.parse('$messageServerUrl/api/upload'),
      //   );
      //   request.files.add(await http.MultipartFile.fromPath('file', file.path));
      //
      //   final response = await request.send();
      //
      //   if (response.statusCode == 200) {
      //     setState(() {
      //       _uploadedImages.add(file);
      //       _messages.add({"type": "sent", "text": "[이미지 전송 완료]"});
      //     });
      //     print("Image uploaded successfully.");
      //   } else {
      //     print("Failed to upload image: ${response.statusCode}");
      //   }
      // } catch (error) {
      //   print("Error uploading image: $error");
      // }
    }
  }


  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      key: CustomScaffold.globalKey,
      currentIndex: _currentIndex,
      onTabTapped: (index) => setState(() {
        _currentIndex = index;
      }),
      body: Stack(
        children: [
          Column(
            children: [
              // Prompt 버튼
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == "delete") {
                        try {
                          await _deleteChatHistory();
                          setState(() {
                            _messages.clear();
                          });
                          print("Chat history deleted");
                        } catch (error) {
                          print("Failed to delete chat history: $error");
                          // 사용자에게 알림을 표시할 수도 있습니다.
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("채팅 기록 삭제에 실패했습니다.")),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: "delete",
                        child: Text("채팅 기록 삭제"),
                      ),
                    ],
                    child: TextButton(
                      onPressed: null,
                      child: Text(
                        "Prompt",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
              // 채팅 메시지 리스트
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    // if(message["type"] == "received"){
                    //   print("ArtistName : ${message["artistName"]}");
                    //   print("SongName : ${message["songName"]}");
                    // }
                    if (message["contentType"] == "text") {
                      return Align(
                        alignment: message["type"] == "sent"
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          decoration: BoxDecoration(
                            color: message["type"] == "sent"
                                ? Colors.blue[100]
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(message["text"]!),
                        ),
                      );
                    } else if (message["contentType"] == "search_button") {
                      // "해당 노래로 검색하기" 버튼
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            CustomScaffold.globalKey.currentState?.performSearchWithQuery("${message['artistName']} - ${message['songName']}");
                          },
                          child: Text(
                            "해당 노래로 검색하기",
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      );
                    } else {
                      // 기본 이미지 출력
                      return Align(
                        alignment: message["type"] == "sent"
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          child: Image.file(
                            File(message["imagePath"]),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }
                    // 기존 코드
                    // return Align(
                    //   alignment: message["type"] == "sent"
                    //       ? Alignment.centerRight
                    //       : Alignment.centerLeft,
                    //   child: message["contentType"] == "text"
                    //     ? Container(
                    //     padding: EdgeInsets.all(10),
                    //     margin:
                    //     EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    //     decoration: BoxDecoration(
                    //       color: message["type"] == "sent"
                    //           ? Colors.blue[100]
                    //           : Colors.grey[300],
                    //       borderRadius: BorderRadius.circular(8),
                    //     ),
                    //     child: Text(message["text"]!),
                    //   ) :
                    //   Container(
                    //     margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    //     child: Image.file(
                    //       File(message["imagePath"]),
                    //       width: 200, // 이미지 크기 조정
                    //       height: 200,
                    //       fit: BoxFit.cover,
                    //     ),
                    //   ),
                    // );
                  },
                ),
              ),
              // 입력 칸과 버튼
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // 업로드된 이미지 미리보기 영역
                    if (_uploadedImages.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _uploadedImages.map((image) {
                              return Stack(
                                children: [
                                  Container(
                                    margin: EdgeInsets.symmetric(horizontal: 4),
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: FileImage(File(image.path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _uploadedImages.remove(image);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    // 채팅 입력 영역
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.attach_file),
                          onPressed: _attachFile,
                        ),
                        Expanded(
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight: 100, // 최대 높이 설정
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.purple), // 테두리 색상
                              borderRadius: BorderRadius.circular(8), // 테두리 둥글게
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8.0), // 내부 여백
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: TextField(
                                controller: _textController,
                                keyboardType: TextInputType.multiline,
                                maxLines: null, // 줄 수 제한 없음
                                decoration: InputDecoration(
                                  border: InputBorder.none, // 내부 테두리 제거
                                  hintText: "메세지를 입력하세요",
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 스크롤 아래로 이동 버튼
          if (_showScrollToBottomButton)
            Positioned(
              bottom: 80,
              right: 20,
              child: FloatingActionButton(
                mini: true,
                onPressed: () {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: Icon(Icons.arrow_downward),
              ),
            ),
        ],
      ),
    );
  }
}