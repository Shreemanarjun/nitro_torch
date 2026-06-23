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

// Material dark surface — visible contrast against pure black OLED pixels.
const _kSurface = Color(0xFF1C1C1E);
const _kSurface2 = Color(0xFF2C2C2E);
const _kSurface3 = Color(0xFF3A3A3C);

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
        scaffoldBackgroundColor: const Color(0xFF000000),
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
  int _maxLevel = _kFallbackMax;
  bool _levelSupported = true;
  String? _error;

  static const int _kFallbackMax = 10;

  StreamSubscription<plugin.TorchState>? _stateSub;
  StreamSubscription<plugin.TorchLevel>? _levelSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    _refreshMaxLevel();

    _stateSub = _torch.onTorchStateChanged().listen((state) {
      setState(() {
        _isOn = state == plugin.TorchState.on;
        _error = null;
      });
      if (state == plugin.TorchState.on) _refreshMaxLevel();
    });

    _levelSub = _torch.onLevelChanged().listen((lvl) {
      setState(() {
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: const Text('NitroTorch'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // ── Torch glow circle ─────────────────────────────────────────
              Expanded(
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isOn
                          ? Colors.amber.withValues(alpha: 0.18)
                          : _kSurface2,
                      border: Border.all(
                        color: _isOn
                            ? Colors.amber
                            : _kSurface3,
                        width: _isOn ? 2.5 : 1.5,
                      ),
                      boxShadow: _isOn
                          ? [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.55),
                                blurRadius: 70,
                                spreadRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _isOn ? Icons.flashlight_on : Icons.flashlight_off,
                      size: 88,
                      color: _isOn ? Colors.amber : Colors.white54,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Status badge ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _isOn ? Colors.amber : _kSurface2,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isOn ? Colors.amber.shade300 : _kSurface3,
                  ),
                ),
                child: Text(
                  _isOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 2.5,
                    color: _isOn ? Colors.black : Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Level selector ────────────────────────────────────────────
              _LevelSelector(
                level: _level,
                maxLevel: _maxLevel,
                supported: _levelSupported,
                onChanged: (v) {
                  setState(() => _level = v);
                  _run(() => _torch.setLevel(v));
                },
              ),

              const SizedBox(height: 16),

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
                      color: Colors.white70,
                      onPressed: () => _run(_torch.turnOff),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: _ControlButton(
                  label: 'Toggle',
                  icon: Icons.toggle_on,
                  color: Colors.deepOrangeAccent,
                  onPressed: () => _run(_torch.toggle),
                ),
              ),

              // ── Error banner ──────────────────────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),
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

  static const int _maxSegments = 10;

  @override
  Widget build(BuildContext context) {
    final segments = maxLevel.clamp(2, _maxSegments);
    final filledRaw = (level / maxLevel * segments).round().clamp(0, segments);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: supported ? Colors.amber.withValues(alpha: 0.5) : _kSurface3,
          width: 1.5,
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
                color: supported ? Colors.amber : Colors.white54,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'BRIGHTNESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: supported ? Colors.amber : Colors.white54,
                ),
              ),
              const Spacer(),
              if (!supported)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _kSurface2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'API 33+',
                    style: TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                )
              else
                Text(
                  '$level / $maxLevel',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
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
                                  : _kSurface3,
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

          const SizedBox(height: 4),

          // ── Slider ───────────────────────────────────────────────────────
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: supported ? Colors.amber : Colors.white54,
              inactiveTrackColor: _kSurface3,
              thumbColor: supported ? Colors.amber : Colors.white54,
              overlayColor: Colors.amber.withValues(alpha: 0.18),
            ),
            child: Slider(
              value: level.toDouble().clamp(1, maxLevel.toDouble()),
              min: 1,
              max: maxLevel.toDouble(),
              divisions: maxLevel > 1 ? maxLevel - 1 : null,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),

          if (!supported)
            Center(
              child: Text(
                'Brightness control requires Android 13+',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ),
        ],
      ),
    );
  }

  Color _segmentColor(int index, int total, bool active) {
    if (!active) return Colors.white24;
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? Colors.amber.withValues(alpha: 0.18) : _kSurface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? Colors.amber : _kSurface3,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.amber : Colors.white30,
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
        backgroundColor: _kSurface,
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.8), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onPressed: onPressed,
    );
  }
}
