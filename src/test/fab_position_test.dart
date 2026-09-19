import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/fab_position_provider.dart';

// The add buttons are stored as a fraction of the free area, not pixels: a
// phone in landscape, a tablet and a desktop window all read the same value
// back without the button landing off screen.
void main() {
  test('a position survives a round trip', () {
    const moved = Offset(0.25, 0.8);
    expect(FabPositionNotifier.decode(FabPositionNotifier.encode(moved)), moved);
  });

  test('anything unreadable means "never moved"', () {
    expect(FabPositionNotifier.decode(null), isNull);
    expect(FabPositionNotifier.decode(''), isNull);
    expect(FabPositionNotifier.decode('0.5'), isNull);
    expect(FabPositionNotifier.decode('left,bottom'), isNull);
  });

  test('a stored value from a bigger screen is pulled back on screen', () {
    expect(FabPositionNotifier.decode('1.6,-0.4'), const Offset(1, 0));
  });

  test('the two buttons start in opposite corners', () {
    expect(kFabHomeRight, const Offset(1, 1));
    expect(kFabHomeLeft, const Offset(0, 1));
  });
}
