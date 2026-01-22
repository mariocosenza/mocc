import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/photo/graph_photo_service.dart';

class MicrosoftProfileAvatar extends StatefulWidget {
  final bool isAuthenticated;
  final Future<String?> Function() getGraphToken;

  const MicrosoftProfileAvatar({
    super.key,
    required this.isAuthenticated,
    required this.getGraphToken,
  });

  @override
  State<MicrosoftProfileAvatar> createState() => _MicrosoftProfileAvatarState();
}

class _MicrosoftProfileAvatarState extends State<MicrosoftProfileAvatar> {
  Uint8List? _photoBytes;
  String? _initials;
  bool _loading = false;

  final _graph = GraphService();

  @override
  void didUpdateWidget(covariant MicrosoftProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isAuthenticated && widget.isAuthenticated) {
      _loadPhoto();
    }
    if (oldWidget.isAuthenticated && !widget.isAuthenticated) {
      setState(() {
        _photoBytes = null;
        _initials = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isAuthenticated) {
      _loadPhoto();
    }
  }

  Future<void> _loadPhoto() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final token = await widget.getGraphToken();
      if (token == null) {
        developer.log(
          'MicrosoftProfileAvatar: Token is null',
          name: 'MicrosoftProfileAvatar',
        );
        return;
      }

      final bytes = await _graph.getMyPhotoBytes(token);

      String? initials;
      if (bytes == null) {
        final user = await _graph.getMe(token);
        if (user != null) {
          final givenName = user['givenName']?.toString() ?? '';
          final surname = user['surname']?.toString() ?? '';
          final displayName = user['displayName']?.toString() ?? '';

          if (givenName.isNotEmpty) initials = givenName[0];
          if (surname.isNotEmpty) {
            initials = (initials ?? '') + surname[0];
          }

          if ((initials == null || initials.isEmpty) &&
              displayName.isNotEmpty) {
            initials = displayName[0];
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _photoBytes = bytes;
        _initials = initials?.toUpperCase();
      });
    } catch (e) {
      developer.log(
        'MicrosoftProfileAvatar: Error loading photo: $e',
        name: 'MicrosoftProfileAvatar',
        error: e,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoBytes != null && _photoBytes!.isNotEmpty;
    final isWeb = MediaQuery.sizeOf(context).width > 600;
    final radius = isWeb ? 20.0 : 14.0;
    final diameter = radius * 2;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkResponse(
          onTap: () => context.push('/app/settings'),
          radius: radius,
          containedInkWell: true,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: CircleAvatar(
              radius: radius,
              backgroundImage: hasPhoto ? MemoryImage(_photoBytes!) : null,
              child: hasPhoto
                  ? null
                  : (_initials != null
                        ? Text(_initials!, style: TextStyle(fontSize: radius))
                        : const Icon(Icons.person_outline)),
            ),
          ),
        ),
      ),
    );
  }
}
