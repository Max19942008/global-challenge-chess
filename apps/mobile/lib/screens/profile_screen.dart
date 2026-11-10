import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../online/leaderboard_tab.dart' show categoryLabel;
import '../online/online_client.dart';
import '../online/time_control_picker.dart' show SectionLabel;
import '../ui/avatar.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Lets tests skip the system photo picker.
typedef PhotoPicker = Future<Uint8List?> Function();

/// Gallery photo, resized on the device to ~256 px so it stays far below the server's 150 KB limit.
Future<Uint8List?> pickPhotoFromGallery() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 256,
    maxHeight: 256,
    imageQuality: 82,
  );
  return file?.readAsBytes();
}

/// Name, photo, ratings and win/loss/draw counts of the signed-in player.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.pickPhoto = pickPhotoFromGallery});
  final PhotoPicker pickPhoto;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  bool _saving = false;
  bool _filled = false;

  /// Picked but not saved yet.
  Uint8List? _newPhoto;
  bool _removePhoto = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = OnlineScope.of(context).user;
    if (!_filled && user != null) {
      _name.text = user.name;
      _filled = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final bytes = await widget.pickPhoto();
    if (bytes == null || !mounted) return;
    setState(() {
      _newPhoto = bytes;
      _removePhoto = false;
    });
  }

  Future<void> _save() async {
    final client = OnlineScope.of(context);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    setState(() => _saving = true);
    final error = await client.updateProfile(
      name: name == client.user?.name ? null : name,
      avatarBase64: _newPhoto == null ? null : base64Encode(_newPhoto!),
      removeAvatar: _removePhoto,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error == null) {
        _newPhoto = null;
        _removePhoto = false;
      }
    });
    final text = switch (error) {
      null => l.saved,
      'bad_name' => l.profileBadName,
      'bad_avatar' => l.profileBadPhoto,
      _ => l.profileOffline,
    };
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final client = OnlineScope.of(context);
    final user = client.user;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 4),
                      Text(l.profile, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (user == null || client.state != OnlineState.online)
                    GlassCard(child: Text(l.profileOffline))
                  else ...[
                    _editCard(l, client, user),
                    const SizedBox(height: 14),
                    _statsCard(l, user),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo(OnlineClient client, OnlineUser user) {
    const size = 112.0;
    final name = _name.text.isEmpty ? user.name : _name.text;
    if (_newPhoto != null) {
      return ClipOval(
        child: Image.memory(_newPhoto!, width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Avatar(name: name, url: _removePhoto ? null : client.avatarUrl(user.avatar), size: size);
  }

  Widget _editCard(AppLocalizations l, OnlineClient client, OnlineUser user) {
    final hasPhoto = _newPhoto != null || (user.avatar != null && !_removePhoto);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _photo(client, user)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                key: const ValueKey('pick-photo'),
                onPressed: _saving ? null : _pick,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(hasPhoto ? l.changePhoto : l.addPhoto),
              ),
              if (hasPhoto)
                TextButton.icon(
                  key: const ValueKey('remove-photo'),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _newPhoto = null;
                          _removePhoto = user.avatar != null;
                        }),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(l.removePhoto),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('profile-name'),
            controller: _name,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.profileName,
              helperText: l.profileNameHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('save-profile'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Palette.bgTop),
                  )
                : Text(l.save),
          ),
        ],
      ),
    );
  }

  Widget _statsCard(AppLocalizations l, OnlineUser user) {
    Widget stat(String label, String value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
          ),
          Text(label, style: const TextStyle(color: Palette.muted, fontSize: 13)),
        ],
      ),
    );
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(l.onlineGamesTitle),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(l.wins, '${user.stats.wins}', const Color(0xFF4ADE80)),
              stat(l.losses, '${user.stats.losses}', Palette.danger),
              stat(l.draws, '${user.stats.draws}', Palette.text),
            ],
          ),
          const SizedBox(height: 18),
          SectionLabel(l.tabLeaderboard),
          const SizedBox(height: 8),
          for (final cat in const ['blitz', 'rapid'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(categoryLabel(l, cat), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.star_rounded, color: Palette.gold, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    user.ratings[cat]?.label ?? '1500?',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Palette.gold),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(l.ratingExplained, style: const TextStyle(color: Palette.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
