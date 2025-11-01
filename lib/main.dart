import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

import 'package:flutter/material.dart';

import 'dart:convert';

void main() {
  runApp(const DiseaseDiagnosisApp());
}

class DiseaseDiagnosisApp extends StatelessWidget {
  const DiseaseDiagnosisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '병충해 진단 서비스',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
      ),
      home: const HomeScreen(),
    );
  }
}

// 메인 화면 (StatefulWidget)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {

  static const String MODEL_PATH = 'assets/disease_model2.tflite';
  static const String LABELS_PATH = 'assets/class_names_final.json';

  File? _image; 
  final ImagePicker _picker = ImagePicker();
  bool _isDiagnosing = false; 
  String _diagnosisResult = '진단을 원하시는 사진을 업로드하고 \'진단하기\' 버튼을 눌러주세요.';
  Interpreter? _interpreter;
  List<String>? _labels;

  static const int INPUT_SIZE = 224; 

  // 3.3 이미지 전처리 함수
  List<List<List<List<double>>>> _processImage(File imageFile) {
      // 1. 이미지 디코딩 및 크기 조정
      final originalImage = img.decodeImage(imageFile.readAsBytesSync());
      if (originalImage == null) {
        throw Exception("이미지 디코딩 실패");
      }
      
      // 모델 입력 크기로 리사이즈
      final resizedImage = img.copyResize(originalImage, width: INPUT_SIZE, height: INPUT_SIZE);

      // 2. 텐서 형식 초기화: [1, 224, 224, 3] 형태
      final inputTensor = List.generate(
        1, // 배치 크기
        (i) => List.generate(
          INPUT_SIZE, // 높이
          (y) => List.generate(
            INPUT_SIZE, // 너비
            (x) {
              // getPixel은 이제 Pixel 객체를 반환합니다.
              final pixel = resizedImage.getPixel(x, y);
              
              // 🚨 [최종 수정] 🚨 Pixel 객체의 r, g, b 속성에 직접 접근합니다.
              // 최신 image 패키지에서는 pixel.r.toInt() 와 같이 접근합니다.
              final r = pixel.r.toInt(); 
              final g = pixel.g.toInt(); 
              final b = pixel.b.toInt();
              
              // 3. 픽셀 값 정규화 (0.0 ~ 1.0)
              return [
                r / 255.0,
                g / 255.0,
                b / 255.0,
              ];
            },
          ),
        ),
      );

      // List<dynamic> 타입이 List<double>로 변환되도록 명시적 cast를 추가
      return inputTensor.cast<List<List<List<double>>>>();
  }

  Map<String, dynamic> _postProcessResult(List<List<double>> output) {
    if (_labels == null || _labels!.isEmpty) {
      return {'label': '레이블을 찾을 수 없습니다.', 'confidence': 0.0};
    }

    final probabilities = output[0];
    double maxConfidence = 0.0;
    int maxIndex = -1;

    // 가장 높은 확률을 가진 클래스(인덱스) 찾기
    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxConfidence) {
        maxConfidence = probabilities[i];
        maxIndex = i;
      }
    }

    if (maxIndex != -1 && maxIndex < _labels!.length) {
      return {
        'label': _labels![maxIndex],
        'confidence': maxConfidence,
      };
    } 
    else {
      return {'label': '진단 실패: 알 수 없는 결과', 'confidence': 0.0};
    }
  }


  @override
  void initState() {
    super.initState();
    _loadModelAndLabels();
  }

  @override
  void dispose() {
    _interpreter?.close(); 
    super.dispose();
  }
  
  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path); 
        _isDiagnosing = false;
        _diagnosisResult = '사진이 준비되었습니다. 진단하기 버튼을 눌러주세요.';
      });
      print('이미지 선택 성공: ${_image!.path}');
    } 
    else {
      print('이미지 선택 취소');
    }
  }

  Future<void> _loadModelAndLabels() async {
    try {
      
      _interpreter = await Interpreter.fromAsset(MODEL_PATH); 
      print("✅ TFLite 모델 로드 성공!");

     
      final labelsData = await DefaultAssetBundle.of(context).loadString(LABELS_PATH); 

      final List<dynamic> jsonList = jsonDecode(labelsData); 
      _labels = jsonList.map((e) => e.toString()).toList(); 

      print("✅ 레이블 로드 성공! 레이블 수: ${_labels!.length}");

      setState(() {
        _diagnosisResult = "모델 및 레이블 로드 완료. 사진을 선택해 진단을 시작하세요.";
      });
    } catch (e) {
      print("❌ 모델 또는 레이블 로드 실패: $e");
      setState(() {
        _diagnosisResult = "모델 로드에 실패했습니다. 파일 경로 및 형식을 확인해 주세요: $e";
      });
    }
  }

  Future<void> _runDiagnosis() async {
    if (_image == null) return;
    if (_interpreter == null || _labels == null) {
      setState(() {
        _diagnosisResult = '모델 로드 중이거나 로드에 실패했습니다.';
      });
      return;
    }

    setState(() {
      _isDiagnosing = true;
      _diagnosisResult = '진단 중입니다... 잠시만 기다려주세요.';
    });

    try {
      // 1. 전처리 실행 (3.3 단계)
      final input = _processImage(_image!);

      // 2. 모델 출력 버퍼 준비
      // [1, 클래스 수] 형태의 출력 텐서를 가정합니다.
      // 클래스 수는 _labels의 길이와 같아야 합니다.
      final output = List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);

      // 🚨 [추가] 🚨 3. 모델 실행
      // input(전처리된 이미지)을 모델에 넣고 output 버퍼에 결과를 받습니다.
      _interpreter!.run(input, output);
      print('✅ 모델 실행 완료');

      // 4. 결과 해석
      final result = _postProcessResult(output.cast<List<double>>());
      final confidencePercent = (result['confidence'] * 100).toStringAsFixed(2);
      
      // 5. 결과 텍스트 업데이트
      setState(() {
        _isDiagnosing = false;
        _diagnosisResult = 
            "**진단 결과:** ${result['label']}\n\n"
            "**신뢰도:** ${confidencePercent}%\n\n"
            "식물의 상태와 병충해에 대한 자세한 정보는 검색을 통해 확인해 주세요.";
      });

    } catch (e) {
      print('❌ 모델 실행 또는 전처리 오류: $e');
      setState(() {
        _isDiagnosing = false;
        _diagnosisResult = '진단 중 오류가 발생했습니다: $e';
      });
    }
  }

  
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. 상단 AppBar
      appBar: AppBar(
        title: const Text('병충해 진단 서비스', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // 메뉴 아이콘
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // TODO: 사이드 메뉴 또는 설정 페이지 연결
            },
          ),
        ],
      ),
      // 2. 본문 (스크롤 가능)
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 2-A. 안내 메시지 (파란색 박스)
            _buildGuidanceBox(),
            const SizedBox(height: 20),

            // 2-B. 이미지 Placeholder 영역
            _buildImagePlaceholder(),
            const SizedBox(height: 20),

            // 2-C. 버튼 영역
            _buildActionButtons(),
            const SizedBox(height: 30),

            // 2-D. 진단 결과 섹션
            _buildResultSection(),
          ],
        ),
      ),
    );
  }

// --- 위젯 구성 함수 분리 (가독성 향상) ---

  Widget _buildGuidanceBox() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Text(
        "“진단을 원하시거나 식물 상태가 궁금하신 사진을 찍어 업로드해주세요.”",
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color:_image == null ? Colors.grey.shade200 : Colors.transparent, // 배경색 변경
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: _image == null 
        ? Center(
          child: Icon(
            Icons.image,
            size: 60,
            color: Colors.grey.shade500,
          ),
        ) 
        : ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.file(
            _image!,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        )
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: <Widget>[
        // '사진 업로드' 버튼
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text("사진 업로드"),
            onPressed: () => _pickImage(ImageSource.gallery), // 🚨 [수정 완료] 이미지 선택 로직 연결
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // '진단하기' 버튼
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.science_outlined),
            label: const Text("진단하기"),
            onPressed: (_image != null && !_isDiagnosing) ? _runDiagnosis : null, // 🚨 [수정 완료] 로직 연결 및 활성화 조건
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection() {
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 결과 헤더
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Icon(Icons.verified_user, color: Colors.blue, size: 24),
            const SizedBox(width: 8),
            const Text(
              "진단 결과",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Text(
              "| PLANT DISEASE",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
        const Divider(height: 10, thickness: 1),
        const SizedBox(height: 10),

        // 🚨 [수정] 🚨 결과 내용: 로딩 상태에 따라 위젯 전체를 반환하도록 수정
        _isDiagnosing 
          ? const Center(child: CircularProgressIndicator()) 
          : Text(
              _diagnosisResult, // ⬅️ 상태 변수 사용
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
      ],
    );
  }
}