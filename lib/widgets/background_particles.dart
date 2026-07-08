import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

enum PersonaSeason { none, spring, summer, winter }

enum PersonaParticleMode { auto, spring, summer, winter, none }

PersonaSeason resolvePersonaSeason(PersonaParticleMode mode, {DateTime? now}) {
  switch (mode) {
    case PersonaParticleMode.spring:
      return PersonaSeason.spring;
    case PersonaParticleMode.summer:
      return PersonaSeason.summer;
    case PersonaParticleMode.winter:
      return PersonaSeason.winter;
    case PersonaParticleMode.none:
      return PersonaSeason.none;
    case PersonaParticleMode.auto:
      final month = (now ?? DateTime.now()).month;
      if (month == 12 || month <= 2) return PersonaSeason.winter;
      if (month >= 3 && month <= 5) return PersonaSeason.spring;
      if (month >= 6 && month <= 8) return PersonaSeason.summer;
      return PersonaSeason.none;
  }
}

class BackgroundParticles extends StatefulWidget {
  final PersonaSeason season;

  const BackgroundParticles({super.key, this.season = PersonaSeason.spring});

  @override
  State<BackgroundParticles> createState() => _BackgroundParticlesState();
}

class _BackgroundParticlesState extends State<BackgroundParticles>
    with SingleTickerProviderStateMixin {
  static const _startParticleCount = 6;
  static const _maxParticleCount = 16;
  static const _minSpawnInterval = Duration(milliseconds: 700);
  static const _spawnVarianceMs = 800;
  static const _despawnBuffer = 100.0;

  final _rng = math.Random(13);
  final _active = <_Particle>[];
  final _pool = List<_Particle>.generate(_maxParticleCount, (_) => _Particle());
  final _springShapes = _sakuraPaths
      .map((pathData) => _ParticleShape(parseSvgPathData(pathData)))
      .toList(growable: false);
  final _winterShapes = _snowflakePaths
      .map((pathData) => _ParticleShape(parseSvgPathData(pathData)))
      .toList(growable: false);

  late final AnimationController _ticker;
  Size _worldSize = Size.zero;
  Duration _lastElapsed = Duration.zero;
  Duration _nextSpawn = Duration.zero;
  bool _initialized = false;
  PersonaSeason? _currentSeason;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tick);
    if (widget.season != PersonaSeason.none) _ticker.repeat();
  }

  @override
  void didUpdateWidget(BackgroundParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.season != widget.season) {
      _reset();
      if (widget.season == PersonaSeason.none) {
        _ticker.stop();
      } else if (!_ticker.isAnimating) {
        _ticker.repeat();
      }
    }
  }

  @override
  void dispose() {
    _ticker
      ..removeListener(_tick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.season == PersonaSeason.none) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final nextSize = MediaQuery.sizeOf(context);
          if (_worldSize != nextSize) {
            _worldSize = nextSize;
            _reset();
          }

          if (widget.season == PersonaSeason.summer) {
            return CustomPaint(
              painter: _SummerRaysPainter(
                elapsedSeconds:
                    (_ticker.lastElapsedDuration ?? Duration.zero)
                        .inMilliseconds /
                    1000,
              ),
              size: Size.infinite,
            );
          }

          return CustomPaint(
            painter: _ParticlesPainter(
              particles: _active,
              shapes: _shapesForSeason(widget.season),
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  void _tick() {
    if (!mounted || _worldSize.isEmpty || widget.season == PersonaSeason.none) {
      return;
    }

    final elapsed = _ticker.lastElapsedDuration ?? Duration.zero;
    if (elapsed - _lastElapsed < const Duration(milliseconds: 32)) return;
    final deltaSeconds = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (_currentSeason != widget.season) {
      _reset();
      _currentSeason = widget.season;
    }

    if (widget.season == PersonaSeason.summer) {
      setState(() {});
      return;
    }

    if (!_initialized) {
      for (var i = 0; i < _startParticleCount; i++) {
        _spawnParticle(spawnInBounds: true);
      }
      _initialized = true;
    }

    if (elapsed > _nextSpawn && _pool.isNotEmpty) {
      _nextSpawn =
          elapsed +
          _minSpawnInterval +
          Duration(milliseconds: _rng.nextInt(_spawnVarianceMs));
      _spawnParticle();
    }

    for (var i = _active.length - 1; i >= 0; i--) {
      final particle = _active[i];
      if (particle.x < -_despawnBuffer ||
          particle.y > _worldSize.height + _despawnBuffer) {
        _active.removeAt(i);
        _pool.add(particle);
        continue;
      }

      particle
        ..rotation += particle.rotationSpeed * deltaSeconds
        ..x += particle.xSpeed * deltaSeconds
        ..y +=
            (particle.period * math.sin(particle.amplitude * particle.x)) +
            (particle.ySpeed * deltaSeconds);
    }

    setState(() {});
  }

  void _reset() {
    _pool.addAll(_active);
    _active.clear();
    _initialized = false;
    _nextSpawn = Duration.zero;
    _lastElapsed = _ticker.lastElapsedDuration ?? Duration.zero;
  }

  void _spawnParticle({bool spawnInBounds = false}) {
    if (_pool.isEmpty) return;
    final particle = _pool.removeLast();
    final shapes = _shapesForSeason(widget.season);
    final shapeIndex = _rng.nextInt(shapes.length);
    final bright = _rng.nextBool();

    particle
      ..shapeIndex = shapeIndex
      ..color = _colorForSeason(widget.season, bright)
      ..x = spawnInBounds
          ? _randomBetween(0, _worldSize.width)
          : _randomBetween(0, _worldSize.width + 200)
      ..y = spawnInBounds ? _randomBetween(0, _worldSize.height) : -120
      ..scale = _scaleForSeason(widget.season)
      ..rotation = _randomBetween(0, 360)
      ..xSpeed = _randomBetween(-80, 6)
      ..ySpeed = _randomBetween(60, 90)
      ..rotationSpeed = _randomBetween(22, 28) * (_rng.nextBool() ? 1 : -1)
      ..period = _randomBetween(0.3, 0.7)
      ..amplitude = _randomBetween(0.003, 0.05);

    _active.add(particle);
  }

  List<_ParticleShape> _shapesForSeason(PersonaSeason season) {
    return switch (season) {
      PersonaSeason.spring => _springShapes,
      PersonaSeason.winter => _winterShapes,
      PersonaSeason.summer => const [],
      PersonaSeason.none => const [],
    };
  }

  Color _colorForSeason(PersonaSeason season, bool bright) {
    return switch (season) {
      PersonaSeason.spring =>
        bright ? const Color(0xFFF2657B) : const Color(0xFFE7354A),
      PersonaSeason.summer =>
        bright ? const Color(0xFFF2657B) : const Color(0xFFE7354A),
      PersonaSeason.winter =>
        bright ? const Color(0xFF730D00) : const Color(0xFF9F0B00),
      PersonaSeason.none => Colors.transparent,
    };
  }

  double _scaleForSeason(PersonaSeason season) {
    return switch (season) {
      PersonaSeason.spring => _randomBetween(0.42, 0.72),
      PersonaSeason.summer => 0,
      PersonaSeason.winter => _randomBetween(0.28, 0.52),
      PersonaSeason.none => 0,
    };
  }

  double _randomBetween(double min, double max) =>
      min + _rng.nextDouble() * (max - min);
}

class _SummerRaysPainter extends CustomPainter {
  final double elapsedSeconds;

  const _SummerRaysPainter({required this.elapsedSeconds});

  @override
  void paint(Canvas canvas, Size size) {
    final t = elapsedSeconds;
    final origin = Offset(size.width * 0.82, -190);

    _drawRay(
      canvas,
      size,
      origin: origin,
      phase: t * 0.42,
      baseTarget: Offset(-size.width * 0.36, size.height * 1.20),
      sweepX: 112,
      sweepY: 78,
      startWidth: 34,
      endWidth: 118,
      color: const Color(0xFFF2657B),
      opacity: 0.24,
    );
    _drawRay(
      canvas,
      size,
      origin: Offset(size.width * 0.94, -178),
      phase: t * 0.36 + math.pi * 0.92,
      baseTarget: Offset(-size.width * 0.16, size.height * 1.16),
      sweepX: 124,
      sweepY: 76,
      startWidth: 28,
      endWidth: 92,
      color: const Color(0xFFE7354A),
      opacity: 0.19,
    );
  }

  void _drawRay(
    Canvas canvas,
    Size size, {
    required Offset origin,
    required double phase,
    required Offset baseTarget,
    required double sweepX,
    required double sweepY,
    required double startWidth,
    required double endWidth,
    required Color color,
    required double opacity,
  }) {
    final target = baseTarget.translate(
      math.sin(phase) * sweepX,
      math.cos(phase * 0.82) * sweepY,
    );
    final direction = target - origin;
    final length = direction.distance;
    if (length == 0) return;

    final normal = Offset(-direction.dy / length, direction.dx / length);

    for (final band in const [1.0, 0.78]) {
      final startHalfWidth = startWidth * band;
      final endHalfWidth = endWidth * band;
      final bandOpacity = band == 1.0 ? opacity * 0.46 : opacity;
      final path = Path()
        ..moveTo(
          origin.dx + normal.dx * startHalfWidth,
          origin.dy + normal.dy * startHalfWidth,
        )
        ..lineTo(
          target.dx + normal.dx * endHalfWidth,
          target.dy + normal.dy * endHalfWidth,
        )
        ..lineTo(
          target.dx - normal.dx * endHalfWidth,
          target.dy - normal.dy * endHalfWidth,
        )
        ..lineTo(
          origin.dx - normal.dx * startHalfWidth,
          origin.dy - normal.dy * startHalfWidth,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: bandOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(_SummerRaysPainter oldDelegate) =>
      oldDelegate.elapsedSeconds != elapsedSeconds;
}

class _Particle {
  int shapeIndex = 0;
  Color color = Colors.transparent;
  double x = 0;
  double y = 0;
  double scale = 1;
  double rotation = 0;
  double xSpeed = 0;
  double ySpeed = 0;
  double rotationSpeed = 0;
  double period = 0;
  double amplitude = 0;
}

class _ParticleShape {
  final Path path;
  final Rect bounds;

  _ParticleShape(this.path) : bounds = path.getBounds();
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final List<_ParticleShape> shapes;

  const _ParticlesPainter({required this.particles, required this.shapes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      final shape = shapes[particle.shapeIndex];
      final center = shape.bounds.center;
      paint.color = particle.color;

      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.rotate(particle.rotation * math.pi / 180);
      canvas.scale(particle.scale);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawPath(shape.path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) => true;
}

const _sakuraPaths = [
  'M60.17,9.57L68.37,0C73.59,4.93 80.2,13.69 80.2,24.1C80.2,33.38 73.47,48.63 60.97,56.65C49.15,48 43.46,34.5 43.46,25.79C43.46,17.08 45.88,7.52 54.43,0.65C55.41,2.54 60.17,9.57 60.17,9.57ZM112.47,43.75L124.08,48.76C121.26,55.36 115.68,63.44 105.9,67.04C97.2,70.25 80.47,69.36 68.64,60.4C72.66,46.31 83.45,36.15 91.63,33.14C99.81,30.13 110.6,30.22 119.99,35.87C118.56,37.45 112.47,43.75 112.47,43.75ZM96.22,105.19L95.78,117.78C88.62,117.18 77.96,113.41 71.46,105.26C65.68,98.02 62.69,82.23 67.46,68.17C82.1,67.55 93.74,75.27 99.17,82.08C104.61,88.89 108.67,97.88 106.27,108.58C104.33,107.72 96.22,105.19 96.22,105.19ZM31.53,107.94L20.44,113.1C19.67,106.08 19.51,95.93 25.26,87.25C30.39,79.52 43.26,69.51 58.1,69.74C63.18,83.49 61.64,98.91 56.82,106.17C52,113.43 43.33,119.27 32.42,120.27C32.64,118.15 31.53,107.94 31.53,107.94ZM11.99,47.53L3.49,38.62C9.74,35.09 19.78,32.67 29.73,35.74C38.59,38.47 51.46,48.09 55.44,62.4C43.69,71.15 28.84,73.55 20.52,70.98C12.19,68.42 4.04,62.33 0,52.14C2.09,51.76 11.99,47.53 11.99,47.53Z',
  'M53.04,0L61.25,9.47C61.25,9.47 65.15,5 67.88,0.73C73.67,7.31 82.57,19.95 78.01,35.11C83.89,30.36 107.14,30.79 113.83,40.42C112.13,42.03 106.49,47.21 106.49,47.21L116.82,54.75C114.23,60.54 100.86,74.47 86.82,72.25C92.71,78.45 95.48,96.81 91.29,105.91C87.42,105.03 81.81,101.18 81.81,101.18C81.81,101.18 78.34,111.45 78.21,114.03C66.57,111.29 55.46,99.9 53.33,94.39C50.07,99.45 37.78,108.59 23.42,107.72C24.22,104.82 25.09,100.21 25.02,97.59C23.67,97.27 14.9,97.74 12.29,98.22C10.59,92.15 15.99,70.48 25.5,66.33C10.59,63.73 2.42,51.11 0,44.31C3.55,42.37 9.39,38.83 11.06,37.79C8.11,36.67 6.78,30.7 5.58,29.83C9.05,27.6 25.57,21.03 39.43,30C37.19,20.31 43.63,9.03 53.04,0Z',
  'M53.03,8.441C51.03,5.89 39.85,0 31.86,0C18.14,0 13.58,7.785 0,15.482C5.73,18.082 14.36,28.846 32.84,28.846C41.62,28.846 50.28,21.565 53.51,19.206C50.74,17.528 46,13.403 46,13.403C47.53,11.753 50.78,9.484 53.03,8.441Z',
  'M57.56,7.398C55.06,3.477 47.77,-0.269 37.05,0.015C11.23,0.698 10.17,21.993 0,27.329C4.92,28.344 21.78,33.506 34.5,33.072C44.04,32.747 53.31,27.889 59.41,19.397C57.11,17.87 51.87,11.328 51.87,11.328C51.87,11.328 56.16,8.412 57.56,7.398Z',
];

const _snowflakePaths = [
  'M50 0L57 31L84 13L69 42L100 50L69 58L84 87L57 69L50 100L43 69L16 87L31 58L0 50L31 42L16 13L43 31Z',
  'M46 0L54 0L54 28L77 12L83 18L63 39L92 33L96 41L69 50L96 59L92 67L63 61L83 82L77 88L54 72L54 100L46 100L46 72L23 88L17 82L37 61L8 67L4 59L31 50L4 41L8 33L37 39L17 18L23 12L46 28Z',
  'M39 0L47 0L47 23L57 23L57 0L65 0L65 23L83 10L89 17L71 35L94 35L94 44L70 44L76 54L100 54L100 63L82 63L94 82L87 88L69 70L69 94L60 94L60 70L50 70L50 94L41 94L41 70L23 88L16 82L28 63L10 63L10 54L34 54L40 44L16 44L16 35L39 35L21 17L27 10L45 23L39 23Z',
  'M14 0C23 0 27 6 27 11C27 16 24 26 12 26C7 26 0 23 0 16C0 7 7 0 14 0Z',
];
