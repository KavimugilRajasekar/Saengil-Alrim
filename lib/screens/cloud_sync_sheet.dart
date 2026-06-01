// cloud_sync_sheet.dart
// Bottom sheet shown when the user taps "Connect to Cloud".
// Offers Push and Get (pull) operations against Firebase RTDB.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/birthday_service.dart';
import '../services/cloud_service.dart';
import '../widgets/app_styles.dart';

// ── Entry point ───────────────────────────────────────────────────────────────
void showCloudSyncSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CloudSyncSheet(),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────
class _CloudSyncSheet extends StatefulWidget {
  const _CloudSyncSheet();

  @override
  State<_CloudSyncSheet> createState() => _CloudSyncSheetState();
}

class _CloudSyncSheetState extends State<_CloudSyncSheet> {
  final _cloud = CloudService();

  _SyncState _state = _SyncState.idle;
  String? _errorMessage;

  // Used during the Get flow
  List<FriendBirthday> _cloudBirthdays = [];
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.creamBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border(
          top: BorderSide(color: AppColors.accentBorder, width: 3),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _SyncState.idle:
        return _IdleView(onPush: _handlePush, onGet: _handleGet);
      case _SyncState.loading:
        return const _LoadingView();
      case _SyncState.error:
        return _ErrorView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _reset,
        );
      case _SyncState.pushSuccess:
        return _SuccessView(
          message: 'Birthdays pushed to cloud successfully.',
          onDone: () => Navigator.pop(context),
        );
      case _SyncState.getSelect:
        return _GetSelectView(
          cloudBirthdays: _cloudBirthdays,
          selectedIds: _selectedIds,
          onToggle: (id) => setState(() {
            if (_selectedIds.contains(id)) {
              _selectedIds.remove(id);
            } else {
              _selectedIds.add(id);
            }
          }),
          onConfirm: _handleGetConfirm,
          onCancel: _reset,
        );
      case _SyncState.getSuccess:
        return _SuccessView(
          message:
              '${_selectedIds.length} birthday(s) added to your device.',
          onDone: () => Navigator.pop(context),
        );
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handlePush() async {
    final provider = context.read<BirthdayProvider>();
    setState(() => _state = _SyncState.loading);
    try {
      await _cloud.pushToCloud(provider.birthdays);
      setState(() => _state = _SyncState.pushSuccess);
    } catch (e) {
      setState(() {
        _state = _SyncState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _handleGet() async {
    final provider = context.read<BirthdayProvider>();
    setState(() => _state = _SyncState.loading);
    try {
      final cloud = await _cloud.fetchFromCloud();

      // Only show entries that are NOT already on the device
      final localIds = provider.birthdays.map((b) => b.id).toSet();
      final newOnes = cloud.where((b) => !localIds.contains(b.id)).toList();

      if (newOnes.isEmpty) {
        setState(() {
          _state = _SyncState.error;
          _errorMessage =
              'No new birthdays found in the cloud.\nAll cloud entries are already on your device.';
        });
        return;
      }

      setState(() {
        _cloudBirthdays = newOnes;
        _selectedIds
          ..clear()
          ..addAll(newOnes.map((b) => b.id)); // pre-select all
        _state = _SyncState.getSelect;
      });
    } catch (e) {
      setState(() {
        _state = _SyncState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _handleGetConfirm() async {
    if (_selectedIds.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final provider = context.read<BirthdayProvider>();
    setState(() => _state = _SyncState.loading);
    try {
      final toAdd =
          _cloudBirthdays.where((b) => _selectedIds.contains(b.id));
      for (final b in toAdd) {
        await provider.addBirthday(b);
      }
      setState(() => _state = _SyncState.getSuccess);
    } catch (e) {
      setState(() {
        _state = _SyncState.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _reset() => setState(() {
        _state = _SyncState.idle;
        _errorMessage = null;
        _cloudBirthdays = [];
        _selectedIds.clear();
      });
}

// ── State enum ────────────────────────────────────────────────────────────────
enum _SyncState { idle, loading, error, pushSuccess, getSelect, getSuccess }

// ── Sub-views ─────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final VoidCallback onPush;
  final VoidCallback onGet;
  const _IdleView({required this.onPush, required this.onGet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.accentBorder.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Cloud Sync',
            style: AppStyles.titleHandwritten.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            'Back up your birthdays or restore from the cloud.',
            style: AppStyles.captionBubbly,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Push button
          _ActionButton(
            color: AppColors.primaryPink,
            icon: Icons.cloud_upload_rounded,
            label: 'Push',
            subtitle: 'Upload your birthdays to the cloud',
            onTap: onPush,
          ),
          const SizedBox(height: 14),

          // Get button
          _ActionButton(
            color: AppColors.secondaryApricot,
            icon: Icons.cloud_download_rounded,
            label: 'Get',
            subtitle: 'Download new birthdays from the cloud',
            onTap: onGet,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: AppStyles.funkyButtonDecoration(color: color),
        child: Row(
          children: [
            Icon(icon, size: 28, color: AppColors.textDark),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppStyles.bodyBubblyBold
                          .copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppStyles.captionBubbly),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to cloud…'),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: AppStyles.bodyBubbly.copyWith(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              decoration: AppStyles.funkyButtonDecoration(
                  color: AppColors.pastelMint),
              child: Text('Go Back',
                  style: AppStyles.bodyBubblyBold),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String message;
  final VoidCallback onDone;
  const _SuccessView({required this.message, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppStyles.bodyBubblyBold,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 12),
              decoration: AppStyles.funkyButtonDecoration(
                  color: AppColors.primaryPink),
              child: Text('Done', style: AppStyles.bodyBubblyBold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Get → Select view ─────────────────────────────────────────────────────────
class _GetSelectView extends StatelessWidget {
  final List<FriendBirthday> cloudBirthdays;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _GetSelectView({
    required this.cloudBirthdays,
    required this.selectedIds,
    required this.onToggle,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.accentBorder.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New in Cloud',
                      style: AppStyles.titleHandwritten
                          .copyWith(fontSize: 20),
                    ),
                    Text(
                      '${selectedIds.length} selected',
                      style: AppStyles.captionBubbly,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select the birthdays you want to add to your device.',
                  style: AppStyles.captionBubbly,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // List
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              itemCount: cloudBirthdays.length,
              itemBuilder: (_, i) {
                final b = cloudBirthdays[i];
                final selected = selectedIds.contains(b.id);
                return GestureDetector(
                  onTap: () => onToggle(b.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: AppStyles.funkyCardDecoration(
                      color: selected
                          ? AppColors.primaryPink
                          : AppColors.cardBg,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? AppColors.textDark
                              : AppColors.textLight,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.name,
                                  style: AppStyles.bodyBubblyBold
                                      .copyWith(fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(
                                _dateLabel(b),
                                style: AppStyles.captionBubbly,
                              ),
                              if (b.notes.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  b.notes,
                                  style: AppStyles.captionBubbly,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: AppStyles.funkyButtonDecoration(
                          color: AppColors.secondaryApricot),
                      alignment: Alignment.center,
                      child: Text('Cancel',
                          style: AppStyles.bodyBubblyBold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: AppStyles.funkyButtonDecoration(
                          color: AppColors.primaryPink),
                      alignment: Alignment.center,
                      child: Text('Add Selected',
                          style: AppStyles.bodyBubblyBold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(FriendBirthday b) {
    final month = kMonthNamesShort[b.month - 1];
    final year = b.birthYear != null ? ' · Born ${b.birthYear}' : '';
    return '$month ${b.day}$year';
  }
}
