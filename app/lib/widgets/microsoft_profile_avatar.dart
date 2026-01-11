import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  bool _loading = false;

  final _graph = GraphService();

  @override
  void didUpdateWidget(covariant MicrosoftProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isAuthenticated && widget.isAuthenticated) {
      _loadPhoto();
    }
    if (oldWidget.isAuthenticated && !widget.isAuthenticated) {
      setState(() => _photoBytes = null);
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
      if (token == null) return;

      final bytes = await _graph.getMyPhotoBytes(token);
      if (!mounted) return;

      setState(() => _photoBytes = bytes);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _photoBytes != null && _photoBytes!.isNotEmpty;
    final isWeb = MediaQuery.sizeOf(context).width > 600;

    return Padding(
      padding: isWeb ? const EdgeInsets.all(16.0) : const EdgeInsets.all(8.0),
      child: CircleAvatar(
        radius: isWeb ? 20 : 14,
        backgroundImage: hasPhoto ? MemoryImage(_photoBytes!) : null,
        child: hasPhoto ? null : const Icon(Icons.person_outline),
      ),
    );
  }
}
