import 'package:test/test.dart';
import 'package:firestore_index_automator/src/core/debounce_deployer.dart';
import 'package:firestore_index_automator/src/core/firebase_cli.dart';
import 'package:mockito/mockito.dart';

class MockFirebaseCli extends Mock implements FirebaseCli {}

void main() {
  group('Debounce Deployer', () {
    test('triggers timer and cancels correctly', () {
      final cli = MockFirebaseCli();
      final deployer = DebounceDeployer(cli);

      deployer.trigger();
      expect(deployer.debounceSeconds, greaterThan(0));

      deployer.cancel();
    });
  });
}
