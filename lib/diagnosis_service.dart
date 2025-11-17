import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class DiagnosisService extends ChangeNotifier {
  static const String MODEL_PATH = 'assets/disease_model2.tflite';
  static const String LABELS_PATH = 'assets/class_names_final.json';

  static const Map<String, String> KOREAN_LABELS = {
    'Apple___Apple_scab': '사과 - 사과부패병',
    'Apple___Black_rot': '사과 - 검은 썩음병',
    'Apple___Cedar_apple_rust': '사과 - 사과 적성병',
    'Apple___healthy': '사과 - 건강',
    'Blueberry___healthy': '블루베리 - 건강',
    'Cherry_(including_sour)___Powdery_mildew': '버찌(신맛 포함) - 흰가루병',
    'Cherry_(including_sour)___healthy': '버찌(신맛 포함) - 건강',
    'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot': '옥수수 - 세르코스포라 잎반점 및 회색 잎반점',
    'Corn_(maize)___Common_rust_': '옥수수 - 일반 녹병',
    'Corn_(maize)___Northern_Leaf_Blight': '옥수수 - 북부 잎마름병',
    'Corn_(maize)___healthy': '옥수수 - 건강',
    'Grape___Black_rot': '포도 - 검은 썩음병',
    'Grape___Esca_(Black_Measles)': '포도 - 에스카(블랙 홍역)',
    'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)': '포도 - 잎마름병',
    'Grape___healthy': '포도 - 건강',
    'Orange___Haunglongbing_(Citrus_greening)': '오렌지 - 황룽병(감귤 녹화병)',
    'Peach___Bacterial_spot': '복숭아 - 세균성 반점병',
    'Peach___healthy': '복숭아 - 건강',
    'Pepper,_bell___Bacterial_spot': '피망 - 세균성 반점병',
    'Pepper,_bell___healthy': '피망 - 건강',
    'Potato___Early_blight': '감자 - 초기 마름병',
    'Potato___Late_blight': '감자 - 후기 마름병',
    'Potato___healthy': '감자 - 건강',
    'Raspberry___healthy': '라즈베리 - 건강',
    'Soybean___healthy': '콩 - 건강',
    'Squash___Powdery_mildew': '호박 - 흰가루병',
    'Strawberry___Leaf_scorch': '딸기 - 잎마름병',
    'Strawberry___healthy': '딸기 - 건강',
    'Tomato___Bacterial_spot': '토마토 - 세균성 반점병',
    'Tomato___Early_blight': '토마토 - 초기 마름병',
    'Tomato___Late_blight': '토마토 - 후기 마름병',
    'Tomato___Leaf_Mold': '토마토 - 잎 곰팡이',
    'Tomato___Septoria_leaf_spot': '토마토 - 셉토리아 잎반점',
    'Tomato___Spider_mites Two-spotted_spider_mite': '토마토 - 응애류 (두점박이응애)',
    'Tomato___Target_Spot': '토마토 - 표적 반점',
    'Tomato___Tomato_Yellow_Leaf_Curl_Virus': '토마토 - 토마토 황화잎말림 바이러스',
    'Tomato___Tomato_mosaic_virus': '토마토 - 토마토 모자이크 바이러스',
    'Tomato___healthy': '토마토 - 건강',
  };

  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isDiagnosing = false;
  String _diagnosisResult = '진단을 원하시는 사진을 업로드하고 \'진단하기\' 버튼을 눌러주세요.';
  Interpreter? _interpreter;
  List<String>? _labels;
  String _currentDiagnosisLabel = '';

  static const int INPUT_SIZE = 224;

  File? get image => _image;
  bool get isDiagnosing => _isDiagnosing;
  String get diagnosisResult => _diagnosisResult;
  String get currentDiagnosisLabel => _currentDiagnosisLabel;
  bool get isModelLoaded => _interpreter != null && _labels != null;

  DiagnosisService() {
    // _loadModelAndLabels() is now called in the initialize method
  }

  Future<void> initialize() async {
    await _loadModelAndLabels();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  Future<void> launchGoogleSearch(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse('https://www.google.com/search?q=$encodedQuery');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print('Google 검색 오류: $url을 실행할 수 없습니다.');
    }
  }

  Future<void> launchRdaPortal(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse('https://ncpms.rda.go.kr/npms/UntySrchListR.np?srchWord=$encodedQuery');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print('농촌진흥청 포털 연결 오류: $url을 실행할 수 없습니다.');
    }
  }

  List<List<List<List<double>>>> _processImage(File imageFile) {
    final originalImage = img.decodeImage(imageFile.readAsBytesSync());
    if (originalImage == null) {
      throw Exception("이미지 디코딩 실패");
    }

    final resizedImage = img.copyResize(originalImage, width: INPUT_SIZE, height: INPUT_SIZE);

    final inputTensor = List.generate(
      1,
      (i) => List.generate(
        INPUT_SIZE,
        (y) => List.generate(
          INPUT_SIZE,
          (x) {
            final pixel = resizedImage.getPixel(x, y);
            final r = pixel.r.toInt();
            final g = pixel.g.toInt();
            final b = pixel.b.toInt();

            return [
              r / 255.0,
              g / 255.0,
              b / 255.0,
            ];
          },
        ),
      ),
    );
    return inputTensor.cast<List<List<List<double>>>>();
  }

  Map<String, dynamic> _postProcessResult(List<List<double>> output) {
    if (_labels == null || _labels!.isEmpty) {
      return {'label': '레이블을 찾을 수 없습니다.', 'confidence': 0.0};
    }

    final probabilities = output[0];
    double maxConfidence = 0.0;
    int maxIndex = -1;
    String originalLabel = '진단 실패';

    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxConfidence) {
        maxConfidence = probabilities[i];
        maxIndex = i;
      }
    }

    if (maxIndex != -1 && maxIndex < _labels!.length) {
      originalLabel = _labels![maxIndex];
      final koreanLabel = KOREAN_LABELS[originalLabel] ?? originalLabel;

      return {
        'label': koreanLabel,
        'confidence': maxConfidence,
        'originalLabel': originalLabel,
      };
    } else {
      return {'label': '진단 실패: 알 수 없는 결과', 'confidence': 0.0};
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      _image = File(pickedFile.path);
      _isDiagnosing = false;
      _diagnosisResult = '사진이 준비되었습니다. 진단하기 버튼을 눌러주세요.';
      notifyListeners();
      print('이미지 선택 성공: ${_image!.path}');
    } else {
      print('이미지 선택 취소');
    }
  }

  Future<void> _loadModelAndLabels() async {
    try {
      _interpreter = await Interpreter.fromAsset(MODEL_PATH);
      print("✅ TFLite 모델 로드 성공!");

      final labelsData = await rootBundle.loadString(LABELS_PATH);

      final List<dynamic> jsonList = jsonDecode(labelsData);
      _labels = jsonList.map((e) => e.toString()).toList();

      print("✅ 레이블 로드 성공! 레이블 수: ");
      print(_labels!.length);

      _diagnosisResult = "모델 및 레이블 로드 완료. 사진을 선택해 진단을 시작하세요.";
      notifyListeners();
    } catch (e) {
      print("❌ 모델 또는 레이블 로드 실패: $e");
      _diagnosisResult = "모델 로드에 실패했습니다. 파일 경로 및 형식을 확인해 주세요: $e";
      notifyListeners();
    }
  }

  Future<void> runDiagnosis() async {
    if (_image == null) return;
    if (_interpreter == null || _labels == null) {
      _diagnosisResult = '모델 로드 중이거나 로드에 실패했습니다.';
      notifyListeners();
      return;
    }

    _isDiagnosing = true;
    _diagnosisResult = '진단 중입니다... 잠시만 기다려주세요.';
    notifyListeners();

    try {
      final input = _processImage(_image!);
      final output = List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);

      _interpreter!.run(input, output);
      print('✅ 모델 실행 완료');

      final result = _postProcessResult(output.cast<List<double>>());

      _currentDiagnosisLabel = result['label'];

      final confidencePercent = (result['confidence'] * 100).toStringAsFixed(2);

      _isDiagnosing = false;
      _diagnosisResult =
          "진단 결과: ${result['label']}\n\n"
          "신뢰도: ${confidencePercent}%\n\n"
          "식물의 상태와 병충해에 대한 자세한 정보는 아래 '자세히 검색하기' 버튼을 이용해 주세요.";
      notifyListeners();
    } catch (e) {
      print('❌ 모델 실행 또는 전처리 오류: $e');
      _isDiagnosing = false;
      _diagnosisResult = '진단 중 오류가 발생했습니다: $e';
      notifyListeners();
    }
  }
}
