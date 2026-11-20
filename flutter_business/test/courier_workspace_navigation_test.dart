import 'package:alin_business/widgets/courier_workspace_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('courier destinations are distinct and have stable indices', () {
    expect(CourierWorkspaceNavigation.sections, [
      'home', 'active', 'completed', 'receipts', 'finance',
    ]);
    expect(CourierWorkspaceNavigation.sections.toSet().length, 5);
    for (var i = 0; i < CourierWorkspaceNavigation.sections.length; i++) {
      final section = CourierWorkspaceNavigation.sections[i];
      expect(CourierWorkspaceNavigation.selectedIndex(section), i);
      expect(CourierWorkspaceNavigation.label(section), isNotEmpty);
    }
  });

  test('unknown courier tab defaults to the home destination', () {
    expect(CourierWorkspaceNavigation.selectedIndex('invalid'), 0);
    expect(CourierWorkspaceNavigation.label('home'), 'الرئيسية');
    expect(CourierWorkspaceNavigation.label('finance'), 'الحساب المالي');
  });
}
