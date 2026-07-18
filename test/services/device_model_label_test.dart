import 'package:flutter_test/flutter_test.dart';
import 'package:s1er/services/device_model_label.dart';

void main() {
  group('DeviceModelLabel.iosMachineMarketingNames', () {
    test('maps known machines', () {
      expect(
        DeviceModelLabel.iosMachineMarketingNames['iPhone16,1'],
        'iPhone 15 Pro',
      );
    });
  });

  group('DeviceModelLabel.coarseFallback', () {
    test('returns a non-empty platform label', () {
      expect(DeviceModelLabel.coarseFallback(), isNotEmpty);
    });
  });
}
