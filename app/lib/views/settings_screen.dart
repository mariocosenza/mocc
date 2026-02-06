import 'dart:developer';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocc/models/models.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/user_service.dart';
import 'package:mocc/service/social_service.dart';
import 'package:mocc/auth/auth_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController numberController = TextEditingController();
  late final TextEditingController messageController = TextEditingController();

  // NEW: Nickname controller + baseline value (to detect changes)
  late final TextEditingController nicknameController = TextEditingController();
  String _initialNickname = '';

  late GraphQLClient userService;
  late UserService userSvc;

  UserPreferences? userPreferences;
  User? user;

  String currency = '1';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    userService = ref.read(graphQLClientProvider);
    userSvc = UserService(userService);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    numberController.dispose();
    messageController.dispose();
    nicknameController.dispose(); 
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final me = await userSvc.getMe();
      final prefs = await userSvc.getUserPreferences();

      if (!mounted) return;

      setState(() {
        userPreferences = prefs;
        user = me;

        _initialNickname = (me.nickname).trim();
        nicknameController.text = _initialNickname;

        numberController.text = (prefs.defaultPortions ?? 1).toString();
        currency = (prefs.currency.toJson() == 'EUR') ? '1' : '2';

        final restrictions = prefs.dietaryRestrictions ?? const <String>[];
        messageController.text = restrictions.isNotEmpty
            ? restrictions.first
            : '';

        _loading = false;
      });
    } catch (e, st) {
      log('Error Loading Preferences', error: e, stackTrace: st);

      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('error_loading_prefs'))));
    }
  }

  Future<void> _onSave() async {
    final prefsInput = UserPreferencesInput(
      dietaryRestrictions: messageController.text.trim().isEmpty
          ? []
          : [messageController.text.trim()],
      defaultPortions: int.tryParse(numberController.text.trim()) ?? 1,
      currency: currency == '1' ? Currency.eur : Currency.usd,
    );

    final newNickname = nicknameController.text.trim();
    final nicknameChanged = newNickname != _initialNickname;

    if (nicknameChanged) {
      if (newNickname.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('nickname_empty_error')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');
      if (!validCharacters.hasMatch(newNickname)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('nickname_invalid_error')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    try {
      await userSvc.updateUserPreferences(prefsInput);

      // Save nickname only if changed
      if (nicknameChanged) {
        await userSvc.updateNickname(newNickname);
        _initialNickname = newNickname;
        ref.read(socialRefreshProvider.notifier).refresh();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: const Text('saving').tr()));
    } catch (e, st) {
      log('Error Saving Preferences', error: e, stackTrace: st);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('error_saving_prefs', args: [e.toString()]))),
      );
    }
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    if (GoRouter.of(context).canPop()) context.pop();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.close),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // NEW: Nickname field
                              TextField(
                                controller: nicknameController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: tr("nickname"),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),

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
                                  border: const OutlineInputBorder(),
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
                                        DropdownMenuEntry(
                                          value: '1',
                                          label: '€',
                                        ),
                                        DropdownMenuEntry(
                                          value: '2',
                                          label: r'$',
                                        ),
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
                                decoration: InputDecoration(
                                  hintText: context.tr(
                                    "llm_user_allergy_intolerance",
                                  ),
                                  border: const OutlineInputBorder(),
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
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(authControllerProvider)
                                          .signOut();
                                    },
                                    icon: const Icon(Icons.logout),
                                    label: const Text('logout').tr(),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
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
