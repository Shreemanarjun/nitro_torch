import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nitro/nitro.dart';
import 'package:nitro_torch/nitro_torch.dart' as plugin;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NitroConfig.instance
    ..debugMode = true
    ..enable(level: NitroLogLevel.verbose);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NitroTorch Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        brightness: Brightness.dark,
      ),
      home: const TorchPage(),
    );
  }
}

class TorchPage extends StatefulWidget {
  const TorchPage({super.key});

  @override
  State<TorchPage> createState() => _TorchPageState();
}

class _TorchPageState extends State<TorchPage> {
  final _torch = plugin.NitroTorch.instance;

  bool _isOn = false;
  int _level = 1;
  // Start at a usable default so the selector is always visible.
  // Re-read from hardware after the first stream event or after turn-on.
  int _maxLevel = _kFallbackMax;
  bool _levelSupported = true; // assume supported until proven otherwise
  String? _error;

  static const int _kFallbackMax = 10;

  StreamSubscription<plugin.TorchState>? _stateSub;
  StreamSubscription<plugin.TorchLevel>? _levelSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    _refreshMaxLevel();

    _stateSub = _torch.onTorchStateChanged().listen((state) {
      setState(() {
        _isOn = state == plugin.TorchState.on;
        _error = null;
      });
      // Re-read max level once torch is on — camera ID is guaranteed set.
      if (state == plugin.TorchState.on) _refreshMaxLevel();
    });

    _levelSub = _torch.onLevelChanged().listen((lvl) {
      setState(() {
        // Update both current level and max from the hardware event.
        if (lvl.maxLevel > 1) _maxLevel = lvl.maxLevel.toInt();
        _level = lvl.level.clamp(1, _maxLevel).toInt();
      });
    });
  }

  void _refreshMaxLevel() {
    try {
      final max = _torch.maxLevel() ?? 1;
      setState(() {
        if (max > 1) {
          _maxLevel = max;
          _levelSupported = true;
        } else {
          _levelSupported = false;
          // Keep fallback max so the selector remains visible for testing.
        }
      });
    } catch (_) {
      setState(() => _levelSupported = false);
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _levelSub?.cancel();
    super.dispose();
  }

  void _run(void Function() action) {
    try {
      action();
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('NitroTorch'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // ── Torch icon ────────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOn
                          ? Colors.amber.withValues(alpha: 0.15)
                          : Colors.grey.shade900,
                      boxShadow: _isOn
                          ? [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.6),
                                blurRadius: 60,
                                spreadRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _isOn ? Icons.flashlight_on : Icons.flashlight_off,
                      size: 80,
                      color: _isOn ? Colors.amber : Colors.grey,
                    ),
                  ),
                ),
              ),

              // ── Status badge ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOn ? Colors.amber.shade800 : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isOn ? 'ON' : 'OFF',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Level selector — always visible ───────────────────────────
              _LevelSelector(
                level: _level,
                maxLevel: _maxLevel,
                supported: _levelSupported,
                onChanged: (v) {
                  setState(() => _level = v);
                  _run(() => _torch.setLevel(v));
                },
              ),

              const SizedBox(height: 20),

              // ── Control buttons ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ControlButton(
                      label: 'Turn On',
                      icon: Icons.lightbulb,
                      color: Colors.amber,
                      onPressed: () => _run(_torch.turnOn),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ControlButton(
                      label: 'Turn Off',
                      icon: Icons.lightbulb_outline,
                      color: Colors.blueGrey,
                      onPressed: () => _run(_torch.turnOff),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: _ControlButton(
                  label: 'Toggle',
                  icon: Icons.toggle_on,
                  color: Colors.deepOrange,
                  onPressed: () => _run(_torch.toggle),
                ),
              ),

              // ── Error banner ──────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Level Selector ────────────────────────────────────────────────────────────

class _LevelSelector extends StatelessWidget {
  final int level;
  final int maxLevel;
  final bool supported;
  final ValueChanged<int> onChanged;

  const _LevelSelector({
    required this.level,
    required this.maxLevel,
    required this.supported,
    required this.onChanged,
  });

  // Cap visual segments so the bar doesn't overflow on high-level devices.
  static const int _maxSegments = 10;

  @override
  Widget build(BuildContext context) {
    final segments = maxLevel.clamp(2, _maxSegments);
    final filledRaw = (level / maxLevel * segments).round().clamp(0, segments);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: supported
              ? Colors.amber.withValues(alpha: 0.30)
              : Colors.grey.shade700,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.brightness_6,
                color: supported ? Colors.amber : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'BRIGHTNESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: supported ? Colors.amber : Colors.grey,
                ),
              ),
              const Spacer(),
              if (!supported)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'API 33+',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                )
              else
                Text(
                  'Level  $level / $maxLevel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Segment bars + step buttons ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _StepButton(
                icon: Icons.remove,
                enabled: level > 1,
                onTap: () => onChanged((level - 1).clamp(1, maxLevel)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (ctx, box) {
                    const gap = 4.0;
                    final totalGap = gap * (segments - 1);
                    final barW = (box.maxWidth - totalGap) / segments;
                    return Row(
                      children: List.generate(segments, (i) {
                        final filled = i < filledRaw;
                        final isLast = i == segments - 1;
                        return Padding(
                          padding: EdgeInsets.only(right: isLast ? 0 : gap),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: barW,
                            height: 34,
                            decoration: BoxDecoration(
                              color: filled
                                  ? _segmentColor(i, segments, supported)
                                  : Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              _StepButton(
                icon: Icons.add,
                enabled: level < maxLevel,
                onTap: () => onChanged((level + 1).clamp(1, maxLevel)),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Drag slider (fine control) ───────────────────────────────────
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: supported ? Colors.amber : Colors.grey,
              inactiveTrackColor: Colors.grey.shade800,
              thumbColor: supported ? Colors.amber : Colors.grey,
              overlayColor: Colors.amber.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: level.toDouble().clamp(1, maxLevel.toDouble()),
              min: 1,
              max: maxLevel.toDouble(),
              divisions: maxLevel > 1 ? maxLevel - 1 : null,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),

          // ── Not-supported hint ───────────────────────────────────────────
          if (!supported)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Center(
                child: Text(
                  'Torch brightness control requires Android 13 (API 33)+',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _segmentColor(int index, int total, bool active) {
    if (!active) return Colors.grey.shade700;
    final t = total <= 1 ? 1.0 : index / (total - 1);
    return Color.lerp(Colors.amber.shade700, Colors.amber.shade300, t)!;
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.amber.withValues(alpha: 0.15)
              : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? Colors.amber.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.amber : Colors.grey.shade700,
        ),
      ),
    );
  }
}

// ── Control Button ────────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onPressed: onPressed,
    );
  }
}
