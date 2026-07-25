import 'package:flutter/material.dart';
import 'package:brisconnect/models/promotion_schedule.dart';
import 'package:brisconnect/services/best_time_to_post_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Lightweight detail screen for a promotion, reached via push-notification
/// deep links. Displays the promotion summary and lets the owner extend the
/// offer before it expires.
class PromotionDetailScreen extends StatefulWidget {
  final String promotionId;
  final BestTimeToPostService? service;

  const PromotionDetailScreen({
    super.key,
    required this.promotionId,
    this.service,
  });

  @override
  State<PromotionDetailScreen> createState() => _PromotionDetailScreenState();
}

class _PromotionDetailScreenState extends State<PromotionDetailScreen> {
  bool _loading = true;
  bool _extending = false;
  PromotionSchedule? _promotion;
  String? _error;

  BestTimeToPostService get _service =>
      widget.service ?? BestTimeToPostService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final promotion = await _service.getPromotion(widget.promotionId);
    if (mounted) {
      setState(() {
        _promotion = promotion;
        _loading = false;
        if (promotion == null) {
          _error = 'Promotion not found or no longer available.';
        }
      });
    }
  }

  Future<void> _extend() async {
    setState(() => _extending = true);
    final ok = await _service.extendPromotion(
      promotionId: widget.promotionId,
    );
    if (mounted) {
      setState(() => _extending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Semantics(
            liveRegion: true,
            child: Text(
              ok ? 'Offer extended by 7 days.' : 'Could not extend offer.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (ok) await _load();
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year at $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const Text('Offer Details'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppPalette.ochre),
      );
    }

    if (_error != null || _promotion == null) {
      return Center(
        child: Semantics(
          label: _error,
          child: Text(
            _error ?? 'Unable to load promotion.',
            style: const TextStyle(color: AppPalette.charcoal),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final promotion = _promotion!;
    final canExtend = promotion.status == PromotionStatus.active ||
        promotion.status == PromotionStatus.scheduled;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              promotion.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppPalette.charcoal,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          if (promotion.description.isNotEmpty)
            Text(
              promotion.description,
              style: const TextStyle(color: AppPalette.mutedText),
            ),
          const SizedBox(height: 24),
          _InfoRow(label: 'Status', value: promotion.status.name),
          _InfoRow(label: 'Starts', value: _formatDate(promotion.scheduledAt)),
          _InfoRow(label: 'Ends', value: _formatDate(promotion.endAt)),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canExtend && !_extending ? _extend : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.ochre,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _extending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Extend offer by 7 days'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Extending resets the expiry reminder so you are notified again before the new end date.',
            style: TextStyle(color: AppPalette.mutedText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppPalette.mutedText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppPalette.charcoal),
            ),
          ),
        ],
      ),
    );
  }
}
