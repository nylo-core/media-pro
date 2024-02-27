import 'package:flutter/material.dart';
import 'package:media_pro/media_pro.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // This is a simple example of how to use Media Pro.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Media Pro")),
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8),
          width: double.infinity,
          child: ListView(
            shrinkWrap: true,
            children: [
              SingleImagePicker.compact(
                maxSize: 1024 * 1024 * 7,
                // defaultImage: Image.asset("assets/local_image.png", height: 100,),
                // defaultImage: Image.network("https://via.placeholder.com/150", height: 100),
                // defaultImage: "https://via.placeholder.com/150",
                setImageUrlFromResponse: (response) {
                  if (response['media'] == null) return null;
                  dynamic media = response['media'];
                  return media['original_url'];
                },
                apiUploadImage: ApiRequest(
                  url: "https://mysite.com/upload/animals",
                  method: "post",
                  postData: {"name": "dog"},
                  headers: {"Authorization": "Bearer token here"},
                ),
                allowedMimeTypes: ["image/jpeg", "image/png"],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
