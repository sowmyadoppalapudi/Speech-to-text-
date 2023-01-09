import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_speech/google_speech.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mic Stream Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SpeechRecognize(),
    );
  }
}

class SpeechRecognize extends StatefulWidget {
  const SpeechRecognize({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SpeechRecognizeState();
}

class _SpeechRecognizeState extends State<SpeechRecognize> {
  final RecorderStream _recorderStream = RecorderStream();

  bool isRecognizing = false;
  bool isRecognizeFinished = false;
  String text = '';
  StreamSubscription<List<int>>? _audioStreamSubscription;
  BehaviorSubject<List<int>>? _audioStream;

  @override
  void initState() {
    super.initState();

    _recorderStream.initialize();
  }

  void startRecognizing() async {
    _audioStream = BehaviorSubject<List<int>>();
    _audioStreamSubscription = _recorderStream.audioStream.listen((event) {
      _audioStream!.add(event);
    });

    await _recorderStream.start();

    setState(() {
      isRecognizing = true;
    });
    final serviceAccount = ServiceAccount.fromString(
        (await rootBundle.loadString('assets/test_service_account.json')));
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final config = speechConfig();

    final responseStream = speechToText.streamingRecognize(
        StreamingRecognitionConfig(config: config, interimResults: true),
        _audioStream!);

    var responseText = '';

    responseStream.listen((data) {
      final currentText =
      data.results.map((e) => e.alternatives.first.transcript).join('\n');

      if (data.results.first.isFinal) {
        responseText += '\n' + currentText;
        setState(() {
          text = responseText;
          isRecognizeFinished = true;
        });
      } else {
        setState(() {
          text = responseText + '\n' + currentText;
          isRecognizeFinished = true;
        });
      }
    }, onDone: () {
      setState(() {
        isRecognizing = false;
      });
    });
  }

  void stopRecognizing() async {
    await _recorderStream.stop();
    await _audioStreamSubscription?.cancel();
    await _audioStream?.close();
    setState(() {
      isRecognizing = false;
    });
    print("stopped recording...");
    //_write("i have written this text ...");
  }

  Future<void> _write(String text) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    print({directory.path});
    final File file = File('${directory.path}/recognized_text.txt');
    await file.writeAsString(text);
    print("successfully wrote files");
    final contents = await file.readAsString();
    print(contents);
  }

  RecognitionConfig speechConfig() => RecognitionConfig(
      encoding: AudioEncoding.LINEAR16,
      model: RecognitionModel.basic,
      enableAutomaticPunctuation: true,
      sampleRateHertz: 16000,
      languageCode: 'en-US');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud - Speech to Text'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            if (isRecognizeFinished)
              RecognizerTextWidget(
                recognitionResult: text,
              ),
            ElevatedButton(
              onPressed: isRecognizing ? stopRecognizing : startRecognizing,
              child: isRecognizing
                  ? const Text('Stop Recognizing')
                  : const Text('Start Recognizing'),
            ),
          ],
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class RecognizerTextWidget extends StatelessWidget {
  final String? recognitionResult;
  const RecognizerTextWidget({Key? key, this.recognitionResult}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          const Text(
            'The text recognized by the Google Speech Api:',
          ),
          const SizedBox(
            height:20,
          ),
          Text(
            recognitionResult ?? '-----',
            style: const TextStyle(color: Colors.black,fontSize: 14),
          ),
        ],
      ),
    );
  }
}
