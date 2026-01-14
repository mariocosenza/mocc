import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController numberController = TextEditingController();
  final TextEditingController messageController = TextEditingController();


  String currency = '1';

  @override
  void dispose() {
    numberController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void _onSave() {
    // Collect form data
    final payload = <String, dynamic>{
      'number': numberController.text.trim(),
      'currency': currency,
      'message': messageController.text.trim(),
    };

    // TODO: send payload to your backend/service
    debugPrint('TODO: send form -> $payload');

    // Optional: quick feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('saving').tr()),
    );
  }

  TextInputFormatter minValueFormatter(int min) {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      if (newValue.text.isEmpty) return newValue;
      final int? value = int.tryParse(newValue.text);
      if (value != null && value < min) return oldValue;
      return newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (GoRouter.of(context).canPop()) context.pop();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: numberController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                            minValueFormatter(1),
                          ],
                          decoration: InputDecoration(
                            labelText: context.tr("peaple_in_family"),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            const Text('currency').tr(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownMenu<String>(
                                initialSelection: currency,
                                onSelected: (String? value) {
                                  if (value == null) return;
                                  setState(() => currency = value);
                                },
                                dropdownMenuEntries: const [
                                  DropdownMenuEntry(value: '1', label: '€'),
                                  DropdownMenuEntry(value: '2', label: '\$'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: messageController,
                          keyboardType: TextInputType.multiline,
                          maxLines: 5,
                          decoration:  InputDecoration(
                            hintText: context.tr("llm_user_allergy_intolerance"),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: _onSave,
                              icon: const Icon(Icons.save),
                              label: const Text('save').tr(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
