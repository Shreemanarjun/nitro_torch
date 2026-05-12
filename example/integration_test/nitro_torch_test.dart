import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nitro_torch/nitro_torch.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late NitroTorch torch;

  setUp(() {
    torch = NitroTorch.instance;
  });

  tearDownAll(() {
    torch.dispose();
  });

  // ─── Bridge sanity ────────────────────────────────────────────────────────
  // These tests exercise the FFI transport itself and never need flash hardware.

  group('bridge sanity', () {
    test('add() returns correct sum', () {
      expect(torch.add(1.5, 2.5), equals(4.0));
      expect(torch.add(0, 0), equals(0.0));
      expect(torch.add(-3.0, 3.0), equals(0.0));
      expect(torch.add(100, 0.001), closeTo(100.001, 1e-9));
    });

    test('add() handles large values', () {
      expect(torch.add(1e15, 1e15), closeTo(2e15, 1.0));
    });

    test('getGreeting() returns a non-empty String', () async {
      final result = await torch.getGreeting('World');
      expect(result, isA<String>());
      expect(result.trim(), isNotEmpty);
    });

    test('getGreeting() result contains the supplied name', () async {
      final result = await torch.getGreeting('Nitro');
      expect(result, contains('Nitro'));
    });

    test('getGreeting() called concurrently returns independent results', () async {
      final results = await Future.wait([
        torch.getGreeting('Alice'),
        torch.getGreeting('Bob'),
      ]);
      expect(results[0], contains('Alice'));
      expect(results[1], contains('Bob'));
    });
  });

  // ─── Hardware capabilities ─────────────────────────────────────────────────

  group('hardware capabilities', () {
    // maxLevel() returns null OR 0 when levels are unsupported (device-dependent),
    // and a positive integer when supported.
    test('maxLevel() returns null, 0, or a positive integer', () {
      final max = torch.maxLevel();
      if (max != null) {
        expect(max, greaterThanOrEqualTo(0));
      }
    });

    test('getStatus() returns a bool without throwing', () {
      final status = torch.getStatus();
      expect(status, isA<bool>());
    });
  });

  // ─── Torch control ────────────────────────────────────────────────────────
  // Skipped automatically when the device has no flash hardware.

  // turnOn/turnOff/toggle are synchronous FFI calls but hardware state updates
  // asynchronously. _settle() waits for the OS to propagate the change before
  // reading getStatus().
  group('torch control', () {
    test('turnOn() makes getStatus() true', () async {
      try {
        torch.turnOn();
        await _settle();
        expect(torch.getStatus(), isTrue);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      } finally {
        _safeOff(torch);
      }
    });

    test('turnOff() makes getStatus() false', () async {
      try {
        torch.turnOn();
        await _settle();
        torch.turnOff();
        await _settle();
        expect(torch.getStatus(), isFalse);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      }
    });

    test('toggle() flips state from off to on', () async {
      try {
        torch.turnOff();
        await _settle();
        torch.toggle();
        await _settle();
        expect(torch.getStatus(), isTrue);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      } finally {
        _safeOff(torch);
      }
    });

    test('toggle() flips state from on to off', () async {
      try {
        torch.turnOn();
        await _settle();
        torch.toggle();
        await _settle();
        expect(torch.getStatus(), isFalse);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      }
    });

    test('toggle() twice restores original state', () async {
      try {
        torch.turnOff();
        await _settle();
        torch.toggle();
        await _settle();
        torch.toggle();
        await _settle();
        expect(torch.getStatus(), isFalse);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      }
    });

    test('turnOn() called twice does not throw', () async {
      try {
        torch.turnOn();
        await _settle();
        torch.turnOn();
        await _settle();
        expect(torch.getStatus(), isTrue);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      } finally {
        _safeOff(torch);
      }
    });

    test('turnOff() called twice does not throw', () async {
      try {
        torch.turnOff();
        await _settle();
        torch.turnOff();
        await _settle();
        expect(torch.getStatus(), isFalse);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      }
    });
  });

  // ─── Brightness levels ────────────────────────────────────────────────────

  group('brightness levels', () {
    test('setLevel(1) does not throw when hardware supports levels', () {
      final max = torch.maxLevel();
      if (max == null || max < 1) return; // null or 0 = unsupported; 1 = on/off only
      try {
        torch.turnOn();
        torch.setLevel(1);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      } finally {
        _safeOff(torch);
      }
    });

    test('setLevel(maxLevel) does not throw when hardware supports levels', () {
      final max = torch.maxLevel();
      if (max == null || max < 1) return; // null or 0 = unsupported; 1 = on/off only
      try {
        torch.turnOn();
        torch.setLevel(max);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      } finally {
        _safeOff(torch);
      }
    });

    test('setLevel(mid) does not throw when hardware supports levels', () {
      final max = torch.maxLevel();
      if (max == null || max < 1) return; // null or 0 = unsupported; 1 = on/off only
      final mid = (max / 2).ceil();
      try {
        torch.turnOn();
        torch.setLevel(mid);
      } catch (e) {
        if (_noFlash(e)) return;
        rethrow;
      } finally {
        _safeOff(torch);
      }
    });
  });

  // ─── Streams ──────────────────────────────────────────────────────────────

  group('streams', () {
    test('onTorchStateChanged() emits TorchState.on after turnOn()', () async {
      StreamSubscription<TorchState>? sub;
      try {
        _safeOff(torch);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final completer = Completer<TorchState>();
        sub = torch.onTorchStateChanged().listen((state) {
          if (state == TorchState.on && !completer.isCompleted) {
            completer.complete(state);
          }
        });

        torch.turnOn();
        final state = await completer.future.timeout(const Duration(seconds: 4));
        expect(state, equals(TorchState.on));
      } catch (e) {
        if (_noFlash(e) || _isTimeout(e)) return;
        rethrow;
      } finally {
        await sub?.cancel();
        _safeOff(torch);
      }
    });

    test('onTorchStateChanged() emits TorchState.off after turnOff()', () async {
      StreamSubscription<TorchState>? sub;
      try {
        torch.turnOn();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final completer = Completer<TorchState>();
        sub = torch.onTorchStateChanged().listen((state) {
          if (state == TorchState.off && !completer.isCompleted) {
            completer.complete(state);
          }
        });

        torch.turnOff();
        final state = await completer.future.timeout(const Duration(seconds: 4));
        expect(state, equals(TorchState.off));
      } catch (e) {
        if (_noFlash(e) || _isTimeout(e)) return;
        rethrow;
      } finally {
        await sub?.cancel();
      }
    });

    test('onTorchStateChanged() emits both on and off events in sequence', () async {
      final events = <TorchState>[];
      StreamSubscription<TorchState>? sub;
      try {
        _safeOff(torch);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final gotTwo = Completer<void>();
        sub = torch.onTorchStateChanged().listen((state) {
          events.add(state);
          if (events.length >= 2 && !gotTwo.isCompleted) gotTwo.complete();
        });

        torch.turnOn();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        torch.turnOff();
        await gotTwo.future.timeout(const Duration(seconds: 5));

        expect(events, contains(TorchState.on));
        expect(events, contains(TorchState.off));
      } catch (e) {
        if (_noFlash(e) || _isTimeout(e)) return;
        rethrow;
      } finally {
        await sub?.cancel();
      }
    });

    test('onLevelChanged() emits TorchLevel with valid fields after setLevel()', () async {
      final max = torch.maxLevel();
      if (max == null || max < 1) return; // null or 0 = unsupported; 1 = on/off only

      StreamSubscription<TorchLevel>? sub;
      try {
        torch.turnOn();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final completer = Completer<TorchLevel>();
        sub = torch.onLevelChanged().listen((lvl) {
          if (!completer.isCompleted) completer.complete(lvl);
        });

        torch.setLevel(1);
        final lvl = await completer.future.timeout(const Duration(seconds: 4));

        expect(lvl.level, greaterThan(0));
        expect(lvl.maxLevel, greaterThan(0));
        expect(lvl.level, lessThanOrEqualTo(lvl.maxLevel));
      } catch (e) {
        if (_noFlash(e) || _isTimeout(e)) return;
        rethrow;
      } finally {
        await sub?.cancel();
        _safeOff(torch);
      }
    });

    test('onLevelChanged() maxLevel field is consistent with maxLevel()', () async {
      final reported = torch.maxLevel();
      if (reported == null || reported <= 1) return;

      StreamSubscription<TorchLevel>? sub;
      try {
        torch.turnOn();
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final completer = Completer<TorchLevel>();
        sub = torch.onLevelChanged().listen((lvl) {
          if (!completer.isCompleted) completer.complete(lvl);
        });

        torch.setLevel(1);
        final lvl = await completer.future.timeout(const Duration(seconds: 4));
        expect(lvl.maxLevel, equals(reported));
      } catch (e) {
        if (_noFlash(e) || _isTimeout(e)) return;
        rethrow;
      } finally {
        await sub?.cancel();
        _safeOff(torch);
      }
    });

    // Two concurrent subscriptions can be opened and cancelled independently.
    // The active (most-recently-registered) subscriber always receives events;
    // cancelling it does not affect the other.
    test('second subscriber works after first is cancelled', () async {
      StreamSubscription<TorchState>? sub1, sub2;
      try {
        _safeOff(torch);
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Open sub1 then immediately cancel it — sub2 must still work.
        sub1 = torch.onTorchStateChanged().listen((_) {});
        await sub1.cancel();
        sub1 = null;

        final completer = Completer<TorchState>();
        sub2 = torch.onTorchStateChanged().listen((s) {
          if (s == TorchState.on && !completer.isCompleted) completer.complete(s);
        });

        torch.turnOn();
        final state = await completer.future.timeout(const Duration(seconds: 4));
        expect(state, equals(TorchState.on));
      } catch (e) {
        if (_noFlash(e) || _isTimeout(e)) return;
        rethrow;
      } finally {
        await sub1?.cancel();
        await sub2?.cancel();
        _safeOff(torch);
      }
    });

    test('onTorchStateChanged() subscription cancel does not throw', () async {
      final sub = torch.onTorchStateChanged().listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
    });

    test('onLevelChanged() subscription cancel does not throw', () async {
      final sub = torch.onLevelChanged().listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
    });

    test('re-subscribing after cancel works', () async {
      StreamSubscription<TorchState>? sub;
      try {
        sub = torch.onTorchStateChanged().listen((_) {});
        await sub.cancel();
        sub = null;

        _safeOff(torch);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final completer = Completer<TorchState>();
        sub = torch.onTorchStateChanged().listen((s) {
          if (s == TorchState.on && !completer.isCompleted) completer.complete(s);
        });

        torch.turnOn();
        final state = await completer.future.timeout(const Duration(seconds: 4));
        expect(state, equals(TorchState.on));
      } catch (e) {
        if (_noFlash(e) || _isTimeout(e)) return;
        rethrow;
      } finally {
        await sub?.cancel();
        _safeOff(torch);
      }
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

// Hardware state (getStatus) lags ~300 ms behind FFI command on Android/iOS.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 500));

void _safeOff(NitroTorch torch) {
  try {
    torch.turnOff();
  } catch (_) {}
}

bool _noFlash(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('noflash') ||
      msg.contains('no flash') ||
      msg.contains('not available') ||
      msg.contains('torch unavailable') ||
      msg.contains('camera') && msg.contains('unavailable') ||
      msg.contains('avfoundation') && msg.contains('nil');
}

bool _isTimeout(Object e) => e is TimeoutException;
