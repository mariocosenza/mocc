import 'package:flutter/material.dart';

class EqualHeightRow extends StatefulWidget {
  final Widget left;
  final Widget right;
  final double gap;

  const EqualHeightRow({
    super.key,
    required this.left,
    required this.right,
    this.gap = 12,
  });

  @override
  State<EqualHeightRow> createState() => _EqualHeightRowState();
}

class _EqualHeightRowState extends State<EqualHeightRow> {
  final GlobalKey _leftKey = GlobalKey();
  final GlobalKey _rightKey = GlobalKey();

  double? _maxHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant EqualHeightRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final leftCtx = _leftKey.currentContext;
    final rightCtx = _rightKey.currentContext;
    if (leftCtx == null || rightCtx == null) return;

    final leftBox = leftCtx.findRenderObject() as RenderBox?;
    final rightBox = rightCtx.findRenderObject() as RenderBox?;
    if (leftBox == null || rightBox == null) return;

    final newMax = leftBox.size.height > rightBox.size.height
        ? leftBox.size.height
        : rightBox.size.height;

    if (_maxHeight == null || (newMax - _maxHeight!).abs() > 0.5) {
      setState(() => _maxHeight = newMax);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftMeasured = KeyedSubtree(key: _leftKey, child: widget.left);
    final rightMeasured = KeyedSubtree(key: _rightKey, child: widget.right);
    final left = _maxHeight == null
        ? leftMeasured
        : SizedBox(height: _maxHeight, child: leftMeasured);

    final right = _maxHeight == null
        ? rightMeasured
        : SizedBox(height: _maxHeight, child: rightMeasured);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: widget.gap),
        Expanded(child: right),
      ],
    );
  }
}
