import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prisma/widgets/app_text_scaling.dart';

void main() {
  test('increases all font sizes proportionally over system scaling', () {
    final scaler = AppTextScaler(
      const TextScaler.linear(1.2),
      appTextScaleFactor,
    );

    expect(scaler.scale(10), closeTo(10 * 1.2 * appTextScaleFactor, 0.001));
    expect(scaler.scale(20), closeTo(20 * 1.2 * appTextScaleFactor, 0.001));
    expect(scaler.scale(20) / scaler.scale(10), 2);
  });
}
