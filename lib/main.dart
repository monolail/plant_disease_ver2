import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/diagnosis_service.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) {
        final service = DiagnosisService();
        service.initialize();
        return service;
      },
      child: const DiseaseDiagnosisApp(),
    ),
  );
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final diagnosisService = context.watch<DiagnosisService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('병충해 진단 서비스', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // TODO: Implement menu functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildGuidanceBox(),
            const SizedBox(height: 20),
            _buildImagePlaceholder(diagnosisService),
            const SizedBox(height: 20),
            _buildActionButtons(context, diagnosisService),
            const SizedBox(height: 30),
            _buildResultSection(diagnosisService),
          ],
        ),
      ),
    );
  }

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

  Widget _buildImagePlaceholder(DiagnosisService diagnosisService) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: diagnosisService.image == null ? Colors.grey.shade200 : Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: diagnosisService.image == null
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
                diagnosisService.image!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
    );
  }

  Widget _buildActionButtons(BuildContext context, DiagnosisService diagnosisService) {
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text("카메라 촬영"),
            onPressed: () => context.read<DiagnosisService>().pickImage(ImageSource.camera),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text("갤러리 업로드"),
            onPressed: () => context.read<DiagnosisService>().pickImage(ImageSource.gallery),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.science_outlined),
            label: const Text("진단하기"),
            onPressed: (diagnosisService.image != null && !diagnosisService.isDiagnosing && diagnosisService.isModelLoaded)
                ? () => context.read<DiagnosisService>().runDiagnosis()
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(DiagnosisService diagnosisService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        diagnosisService.isDiagnosing
            ? const Center(child: CircularProgressIndicator())
            : Text(
                diagnosisService.diagnosisResult,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
        if (!diagnosisService.isDiagnosing &&
            diagnosisService.currentDiagnosisLabel.isNotEmpty &&
            diagnosisService.currentDiagnosisLabel != '모델 및 레이블 로드 완료. 사진을 선택해 진단을 시작하세요.')
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.school, size: 20),
                  label: Text('농촌진흥청 포털에서 "${diagnosisService.currentDiagnosisLabel}" 검색'),
                  onPressed: () => diagnosisService.launchRdaPortal(diagnosisService.currentDiagnosisLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.search, size: 20),
                  label: Text('Google에서 "${diagnosisService.currentDiagnosisLabel}" 검색'),
                  onPressed: () => diagnosisService.launchGoogleSearch(diagnosisService.currentDiagnosisLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
