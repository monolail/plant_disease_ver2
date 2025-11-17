import 'package:flutter_test/flutter_test.dart';
// main.dart를 수정할 수 없으며, 해당 파일의 private 멤버에 직접 접근할 수 없으므로
// _postProcessResult 함수의 로직과 KOREAN_LABELS를 테스트 파일 내부에 복제합니다.
// 이는 실제 main.dart의 함수를 테스트하는 것이 아니라, 그 로직의 복제본을 테스트하는 것임을 명심해야 합니다.

// main.dart의 _HomeScreenState에 정의된 KOREAN_LABELS 맵을 복제합니다.
const Map<String, String> KOREAN_LABELS = {
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

// main.dart의 _postProcessResult 로직을 복제한 헬퍼 함수
Map<String, dynamic> testPostProcessResult(List<List<double>> output, List<String> labels) {
  if (labels.isEmpty) {
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

  if (maxIndex != -1 && maxIndex < labels.length) { // _labels 대신 인자로 받은 labels 사용

    originalLabel = labels[maxIndex];

    final koreanLabel = KOREAN_LABELS[originalLabel] ?? originalLabel;

    return {

      'label': koreanLabel,
      'confidence': maxConfidence,
      'originalLabel': originalLabel,
    };
  }
  else {
    return {'label': '진단 실패: 알 수 없는 결과', 'confidence': 0.0};
  }
}


void main() {
  group('testPostProcessResult', () {
    // 테스트 1: 모델 출력에서 가장 확률이 높은 결과값을 정상적으로 반환하는지 검증
    test('should return the label with the highest confidence', () {
      // Arrange: 테스트에 필요한 변수 설정
      final labels = ['Apple___healthy', 'Tomato___Bacterial_spot', 'Potato___Late_blight'];
      final List<List<double>> modelOutput = [
        [0.1, 0.8, 0.1]
      ];
      const expectedLabel = 'Tomato___Bacterial_spot';
      const expectedTranslatedLabel = '토마토 - 세균성 반점병';
      const expectedConfidence = 0.8;

      // Act: 테스트할 함수 실행
      final result = testPostProcessResult(modelOutput, labels);

      // Assert: 실행 결과 검증
      expect(result['originalLabel'], expectedLabel);
      expect(result['label'], expectedTranslatedLabel);
      // 부동소수점 비교는 근사치를 사용해야 더 안정적입니다.
      expect(result['confidence'], closeTo(expectedConfidence, 0.001));
    });

    // 테스트 2: 라벨 리스트가 비어있을 경우의 동작 검증
    test('should return "not found" when labels list is empty', () {
      // Arrange
      final labels = <String>[];
      final modelOutput = [
        [0.5, 0.5, 0.0]
      ];

      // Act
      final result = testPostProcessResult(modelOutput, labels);

      // Assert
      expect(result['label'], '레이블을 찾을 수 없습니다.');
      expect(result['confidence'], 0.0);
    });

    // 테스트 3: 모델 출력이 비정상적일 경우의 예외 처리 검증
    test('should handle empty or invalid model output gracefully', () {
      // Arrange
      final labels = ['Apple___healthy', 'Tomato___Bacterial_spot'];
      final modelOutput = [[]]; // 비정상적인 모델 출력 (확률 리스트가 비어있음)

      // Act
      final result = testPostProcessResult(
      modelOutput.map((row) => row.map((e) => e as double).toList()).toList(),
      labels
    );
      // Assert
      expect(result['label'], contains('진단 실패: 알 수 없는 결과'));
      expect(result['confidence'], 0.0);
    });

    // 테스트 4: 모든 확률값이 0일 경우의 동작 검증
    test('should handle all-zero confidences', () {
      // Arrange
      final labels = ['Apple___healthy', 'Tomato___Bacterial_spot'];
      final modelOutput = [
        [0.0, 0.0, 0.0]
      ];

      // Act
      final result = testPostProcessResult(modelOutput, labels);

      // Assert
      expect(result['label'], contains('진단 실패: 알 수 없는 결과'));
      expect(result['confidence'], 0.0);
    });
  });
}
