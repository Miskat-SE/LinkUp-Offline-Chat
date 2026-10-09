import 'package:integration_test/integration_test_driver.dart';

/// Runs the device test under `flutter drive --profile` and saves frame
/// timings to build/file_transfer_frames.json (TESTING.md §1).
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data != null) {
      await writeResponseData(data, testOutputFilename: 'file_transfer_frames');
    }
  },
);
