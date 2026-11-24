import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../models/space_models.dart';

class CountdownCard extends StatefulWidget {
  final NextMissionData data;

  const CountdownCard({
    super.key,
    required this.data,
  });

  @override
  State<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard> {
  Timer? _timer;
  late Duration _serverClockOffset;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _syncClockOffset();
    _recomputeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(_recomputeRemaining);
      }
    });
  }

  @override
  void didUpdateWidget(covariant CountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.serverTimeUtc != widget.data.serverTimeUtc ||
        oldWidget.data.mission?.launchDateUtc !=
            widget.data.mission?.launchDateUtc) {
      _syncClockOffset();
      _recomputeRemaining();
    }
  }

  void _syncClockOffset() {
    _serverClockOffset =
        widget.data.serverTimeUtc.difference(DateTime.now().toUtc());
  }

  void _recomputeRemaining() {
    final launchDate = widget.data.mission?.launchDateUtc;
    if (launchDate == null) {
      _remaining = Duration.zero;
      return;
    }
    final syncedNowUtc = DateTime.now().toUtc().add(_serverClockOffset);
    final diff = launchDate.difference(syncedNowUtc);
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final mission = widget.data.mission;
    if (mission == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.rocket_launch_rounded,
                  color: AppTheme.saffronAccent, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'No upcoming launches currently scheduled.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    final launchText = mission.launchDateUtc != null
        ? DateFormat("dd MMM yyyy • HH:mm 'UTC'")
            .format(mission.launchDateUtc!.toUtc())
        : 'NET TBD';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF15223C),
            Color(0xFF0E172A),
          ],
        ),
        border: Border.all(
          color: AppTheme.saffronAccent.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.saffronAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'NEXT LAUNCH • ${mission.program.toUpperCase()}',
                  style: const TextStyle(
                    color: AppTheme.saffronAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (mission.vehicleName != null)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(mission.vehicleName!),
                ),
              if (mission.orbitType != null)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(mission.orbitType!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            mission.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${mission.launchSite ?? 'SDSC SHAR'}  •  $launchText',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.spaceBackground.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'T-MINUS COUNTDOWN (SERVER-SYNCED UTC)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.orbitalCyan,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _CountdownUnit(value: _two(days), label: 'DAYS'),
                    _CountdownUnit(value: _two(hours), label: 'HRS'),
                    _CountdownUnit(value: _two(minutes), label: 'MIN'),
                    _CountdownUnit(value: _two(seconds), label: 'SEC'),
                  ],
                ),
              ],
            ),
          ),
          if (mission.summary != null && mission.summary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              mission.summary!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final String value;
  final String label;

  const _CountdownUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 62),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
              color: Color(0xFFF8FAFC),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}