import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/diagnosis_service.dart';

// Mock DiagnosisService for testing
class MockDiagnosisService extends DiagnosisService {
  @override
  File? get image => _mockImage;
  File? _mockImage;

  @override
  bool get isDiagnosing => _mockIsDiagnosing;
  bool _mockIsDiagnosing = false;

  @override
  String get diagnosisResult => _mockDiagnosisResult;
  String _mockDiagnosisResult =
      '진단을 원하시는 사진을 업로드하고 \'진단하기\' 버튼을 눌러주세요.';

  @override
  String get currentDiagnosisLabel => _mockCurrentDiagnosisLabel;
  String _mockCurrentDiagnosisLabel = '';

  @override
  bool get isModelLoaded => _mockIsModelLoaded;
  bool _mockIsModelLoaded = true;

  @override
  Future<void> pickImage(ImageSource source) async {
    _mockImage = File('test/dummy_image.png');
    _mockIsDiagnosing = false;
    _mockDiagnosisResult = '사진이 준비되었습니다. 진단하기 버튼을 눌러주세요.';
    notifyListeners();
  }

  @override
  Future<void> runDiagnosis() async {
    _mockIsDiagnosing = true;
    _mockDiagnosisResult = '진단 중입니다... 잠시만 기다려주세요.';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    _mockIsDiagnosing = false;
    _mockCurrentDiagnosisLabel = '토마토 - 세균성 반점병';
    _mockDiagnosisResult =
        "진단 결과: 토마토 - 세균성 반점병\n\n"
        "신뢰도: 80.00%\n\n"
        "식물의 상태와 병충해에 대한 자세한 정보는 아래 '자세히 검색하기' 버튼을 이용해 주세요.";
    notifyListeners();
  }

  @override
  Future<void> launchGoogleSearch(String query) async {
    print('Mock Google Search for: $query');
  }

  @override
  Future<void> launchRdaPortal(String query) async {
    print('Mock RDA Portal Search for: $query');
  }

  MockDiagnosisService() : super();

  @override
  void dispose() {
    super.dispose();
  }
}

void main() {
  /// -----------------------------------------------------------
  /// 🔥 Flutter binding 초기화 + rootBundle mock
  /// -----------------------------------------------------------
  TestWidgetsFlutterBinding.ensureInitialized();

  // rootBundle.load() 등을 테스트에서 무조건 성공시키기 위한 mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      final fakeData = utf8.encode('{}'); // 더미 JSON
      return ByteData.view(Uint8List.fromList(fakeData).buffer);
    },
  );

  group('HomeScreen Widget Tests', () {
    testWidgets('Initial UI state is correct', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<DiagnosisService>(
          create: (_) => MockDiagnosisService(),
          child: const DiseaseDiagnosisApp(),
        ),
      );

      expect(find.text('병충해 진단 서비스'), findsOneWidget);

      expect(
        find.text('“진단을 원하시거나 식물 상태가 궁금하신 사진을 찍어 업로드해주세요.”'),
        findsOneWidget,
      );

      expect(
        find.text('진단을 원하시는 사진을 업로드하고 \'진단하기\' 버튼을 눌러주세요.'),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.image), findsOneWidget);

      expect(find.text('카메라 촬영'), findsOneWidget);
      expect(find.text('갤러리 업로드'), findsOneWidget);
      expect(find.text('진단하기'), findsOneWidget);

      final buttonFinder = find.ancestor(
        of: find.text('진단하기'),
        matching: find.byType(ElevatedButton),
      );
      expect(buttonFinder, findsOneWidget);

      final diagnoseButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(diagnoseButton.onPressed, isNull);
    });

    testWidgets('Image picking and diagnosis flow', (WidgetTester tester) async {
      final mockService = MockDiagnosisService();

      await tester.pumpWidget(
        ChangeNotifierProvider<DiagnosisService>(
          create: (_) => mockService,
          child: const DiseaseDiagnosisApp(),
        ),
      );

      expect(
        find.text('진단을 원하시는 사진을 업로드하고 \'진단하기\' 버튼을 눌러주세요.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.image), findsOneWidget);

      await tester.tap(find.text('갤러리 업로드'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image), findsNothing);
      expect(find.byType(Image), findsOneWidget);

      expect(
        find.text('사진이 준비되었습니다. 진단하기 버튼을 눌러주세요.'),
        findsOneWidget,
      );

      final buttonFinder = find.ancestor(
        of: find.text('진단하기'),
        matching: find.byType(ElevatedButton),
      );
      expect(buttonFinder, findsOneWidget);

      final enabledDiagnoseButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(enabledDiagnoseButton.onPressed, isNotNull);

      await tester.tap(find.text('진단하기'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('진단 중입니다... 잠시만 기다려주세요.'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(find.textContaining('진단 결과: 토마토 - 세균성 반점병'), findsOneWidget);
      expect(find.textContaining('신뢰도: 80.00%'), findsOneWidget);

      // 검색 버튼 존재 여부는 너의 UI 구조에 따름 -> 필요하면 수정 가능
    });
  });
}
