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
        final url = extractUrlFromResponse(response);

        if (url != null) {
          launchURL(url);
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
    final url = Uri.parse('https://ef05-35-199-174-69.ngrok.io/FRAME');
    final request = http.MultipartRequest('POST', url);
    request.files
        .add(await http.MultipartFile.fromPath('image', imageFile.path));

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
      body: SizedBox(
        height: screenHeight,
        width: screenWidth,
        child: OverflowBox(
          alignment: Alignment.center,
          child: CameraPreview(controller),
        ),
      ),
      floatingActionButton: Container(
        height: screenHeight * 0.9,
        width: screenHeight * 0.9,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed: captureImage,
            child: Image.asset(
              'assets/frame_idle.png',
              width: 50,
              height: 50,
            ),
            backgroundColor: Colors.transparent,
            elevation: 0.0,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
