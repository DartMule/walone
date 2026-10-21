import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/track_editing_test.dart' as editing;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Нативный курсор ставится в середину названия и удаляет нужный фрагмент',
    editing.verifyTrackEditing,
  );
}
