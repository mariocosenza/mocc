import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocc/models/recipe_model.dart';
import 'package:mocc/models/social_model.dart';
import 'package:mocc/service/graphql_config.dart';
import 'package:mocc/service/recipe_service.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mocc/service/social_service.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  List<Recipe> _recipes = [];
  Recipe? _selectedRecipe;
  bool _loading = true;
  bool _submitting = false;
  XFile? _imageFile;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      final client = ref.read(graphQLClientProvider);
      final recipeSvc = RecipeService(client);

      // Fetch both user recipes and AI recipes or just all
      // For now, let's fetch "My Recipes" (saved + created)
      final recipes = await recipeSvc.getMyRecipes();

      if (mounted) {
        setState(() {
          _recipes = recipes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('error_loading_recipe', args: [e.toString()])),
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = pickedFile;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('error_picking_image', args: [e.toString()])),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedRecipe == null) return;

    setState(() {
      _submitting = true;
    });

    try {
      final client = ref.read(graphQLClientProvider);
      final socialSvc = SocialService(client);

      String? imageUrl;
      if (_imageFile != null && _imageBytes != null) {
        // 1. Get SAS
        // Use XFile.name for better cross-platform filename support
        final filename = _imageFile!.name;
        final sasUrl = await socialSvc.generateUploadSasToken(filename);

        // 2. Upload
        final response = await http.put(
          Uri.parse(sasUrl),
          headers: {
            'x-ms-blob-type': 'BlockBlob',
            'Content-Type': 'image/jpeg', 
          },
          body: _imageBytes,
        );

        if (response.statusCode != 201 && response.statusCode != 200) {
          throw Exception('Failed to upload image: ${response.statusCode}');
        }

        // 3. Extract clean URL
        imageUrl = sasUrl;

        // Remove query params
        final uri = Uri.parse(sasUrl);
        imageUrl = uri.replace(query: '').toString();
      }

      final input = CreatePostInput(
        recipeId: _selectedRecipe!.id,
        caption: _captionController.text,
        imageUrl: imageUrl,
      );

      await socialSvc.createPost(input);

      if (mounted) {
        context.pop(); // Go back to feed
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('you_earned_10_points'))));
      }
    } catch (e) {
      if (mounted) {
        developer.log(
          'CreatePost Error: $e',
          name: 'CreatePostScreen',
          error: e,
        ); // Log full error
        setState(() {
          _submitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_occurred', args: [e.toString()]))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('create_post'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Recipe Selector
                      Text(
                        tr('select_recipe'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_recipes.isEmpty)
                        Text(tr('no_recipes_found'))
                      else
                        DropdownButtonFormField<Recipe>(
                          isExpanded: true,
                          initialValue: _selectedRecipe,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.receipt_long),
                          ),
                          hint: Text(tr('select_recipe')),
                          items: _recipes
                              .where((r) => !r.id.startsWith('pending-'))
                              .map((r) {
                                return DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r.title,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              })
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedRecipe = val;
                            });
                          },
                        ),

                      const SizedBox(height: 24),

                      // Cancel Preview (if recipe selected)
                      if (_selectedRecipe != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer.withAlpha(50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedRecipe!.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              if (_selectedRecipe!.description.isNotEmpty)
                                Text(
                                  _selectedRecipe!.description,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.tertiary,
                                  ),
                                  Text(
                                    ' ${_selectedRecipe!.calories ?? '-'} ${tr('kcal')}',
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.timer,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                  Text(
                                    ' ${_selectedRecipe!.prepTimeMinutes ?? '-'} ${tr('min_suffix')}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Image Picker
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: _imageBytes != null
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        _imageBytes!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.error,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                  ),
                                                  Text(
                                                    tr(
                                                      'error_loading_image',
                                                      args: [error.toString()],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              );
                                            },
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: IconButton.filled(
                                        onPressed: () {
                                          setState(() {
                                            _imageFile = null;
                                            _imageBytes = null;
                                          });
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 48,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      tr('add_photo'),
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Caption
                      TextField(
                        controller: _captionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: tr('what_are_you_cooking'),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: _submitting || _selectedRecipe == null
                            ? null
                            : _submit,
                        icon: _submitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: Text(tr('share_recipe')),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                      const SizedBox(
                        height: 110,
                      ), // Bottom padding to clear navbar
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
