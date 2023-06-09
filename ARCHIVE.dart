import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController controller;
  bool isCameraReady = false;
  bool isTextBoxVisible = true;
  TextEditingController textBoxController = TextEditingController();
  bool isPlusIconGreen = false;
  bool isFabVisible = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No cameras available');
        // TODO: Handle the case where no cameras are available
        return;
      }

      final camera = cameras.first;
      controller = CameraController(camera, ResolutionPreset.medium);

      await controller.initialize();
      setState(() {
        isCameraReady = true;
      });
    } catch (e) {
      print('Error initializing camera: $e');
      // TODO: Handle the error during camera initialization
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> captureImage() async {
    if (!isCameraReady) {
      return;
    }

    try {
      final XFile? imageFile = await controller.takePicture();
      if (imageFile != null) {
        final response = await sendImageToServer(imageFile);
        if (response.contains('Image archived successfully')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image Archived Successfully'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to Archive Image'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error capturing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing image'),
        ),
      );
    }
  }

  Future<String> sendImageToServer(XFile imageFile) async {
    final url = Uri.parse('https://b3f4-41-75-107-203.ngrok.io/ARCHIVE');
    final request = http.MultipartRequest('POST', url);
    request.files
        .add(await http.MultipartFile.fromPath('image', imageFile.path));
    request.fields['link'] = textBoxController.text;

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    return responseData;
  }

  String? extractUrlFromResponse(String response) {
    final regex = RegExp(r'<a href="(.*?)">');
    final match = regex.firstMatch(response);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  void launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  void toggleTextBoxVisibility() {
    setState(() {
      isTextBoxVisible = !isTextBoxVisible;
    });
  }

  void saveLink() {
    setState(() {
      isTextBoxVisible = false;
      isPlusIconGreen = true;
      isFabVisible = true;
    });
  }

  void editLink() {
    setState(() {
      isTextBoxVisible = true;
      isPlusIconGreen = false;
      isFabVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraReady) {
      return Container();
    }

    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;

    return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: Container(),
        ),
        body: Stack(
          children: [
            SizedBox(
              height: screenHeight,
              width: screenWidth,
              child: OverflowBox(
                alignment: Alignment.center,
                child: CameraPreview(controller),
              ),
            ),
            Visibility(
              visible: isTextBoxVisible,
              child: Positioned(
                left: 16,
                bottom: 16,
                right: 72,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: textBoxController,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: isTextBoxVisible,
              child: Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: saveLink,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            Visibility(
              visible: !isTextBoxVisible && isFabVisible,
              child: Positioned(
                top: screenHeight * 0.85,
                right: screenWidth * 0.44,
                child: GestureDetector(
                  onTap: editLink,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: Visibility(
          visible: !isTextBoxVisible && isFabVisible,
          child: FractionalTranslation(
            translation: Offset(-0.022, -0.6),
            child: Container(
              height: 360,
              width: 360,
              child: FloatingActionButton(
                onPressed: captureImage,
                child: Image.asset(
                  'assets/frame_idle.png',
                  width: 360,
                  height: 360,
                ),
                backgroundColor: Colors.transparent,
                elevation: 0.0,
              ),
            ),
          ),
        ));
  }
}
