import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/menu_item.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/validation_utils.dart';

/// Menu Item Form Mode - add or edit
enum MenuItemFormMode { add, edit }

/// Menu Item Form Screen - modal dialog for adding/editing menu items
class MenuItemFormScreen extends ConsumerStatefulWidget {
  final MenuItemFormMode mode;
  final MenuItem? menuItem;

  const MenuItemFormScreen({
    super.key,
    required this.mode,
    this.menuItem,
  });

  @override
  ConsumerState<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends ConsumerState<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _allergensController;
  late final TextEditingController _stockQuantityController;

  bool _isVegetarian = false;
  bool _isVegan = false;
  bool _isGlutenFree = false;
  bool _isAvailable = true;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  String? _imageUrl;
  Uint8List? _imageBytes;

  // Common allergens list
  final List<String> _commonAllergens = [
    'Peanuts',
    'Tree Nuts',
    'Dairy',
    'Eggs',
    'Soy',
    'Wheat/Gluten',
    'Fish',
    'Shellfish',
  ];

  final List<String> _categories = [
    'Snack',
    'Lunch',
    'Drinks',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.menuItem;

    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _priceController = TextEditingController(
      text: item?.price != null ? item!.price.toStringAsFixed(2) : '',
    );
    _categoryController = TextEditingController(text: item?.category ?? '');
    _allergensController = TextEditingController(
      text: item?.allergens.join(', ') ?? '',
    );
    _stockQuantityController = TextEditingController(
      text: item?.stockQuantity?.toString() ?? '',
    );

    _isVegetarian = item?.isVegetarian ?? false;
    _isVegan = item?.isVegan ?? false;
    _isGlutenFree = item?.isGlutenFree ?? false;
    _isAvailable = item?.isAvailable ?? true;
    _imageUrl = item?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _allergensController.dispose();
    _stockQuantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    // Responsive dialog width
    final dialogWidth = isMobile 
        ? screenWidth * 0.95 
        : (isTablet ? 600.0 : 700.0);
    
    return Dialog(
      insetPadding: isMobile 
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: isMobile ? 20 : 24,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Text(
                      widget.mode == MenuItemFormMode.add
                          ? (isMobile ? 'Add Item' : 'Add Menu Item')
                          : (isMobile ? 'Edit Item' : 'Edit Menu Item'),
                      style: (isMobile 
                          ? Theme.of(context).textTheme.titleMedium 
                          : Theme.of(context).textTheme.titleLarge)?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Upload Section
                      _buildImageSection(isMobile),
                      SizedBox(height: isMobile ? 16 : 24),

                      // Name
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          hintText: 'Enter item name',
                          prefixIcon: Icon(Icons.restaurant),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => ValidationUtils.required(value, 'Name'),
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          hintText: 'Enter item description',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 3,
                        validator: (value) => ValidationUtils.required(value, 'Description'),
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Price and Category Row
                      Builder(
                        builder: (context) {
                          final screenWidth = MediaQuery.of(context).size.width;
                          final isMobile = screenWidth < 600;
                          if (isMobile) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _priceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Price *',
                                    hintText: '0.00',
                                    prefixIcon: Icon(Icons.currency_exchange),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Price is required';
                                    }
                                    final price = double.tryParse(value);
                                    if (price == null || price <= 0) {
                                      return 'Enter a valid price';
                                    }
                                    return null;
                                  },
                                  enabled: !_isLoading,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _categoryController.text.isNotEmpty
                                      ? _categoryController.text
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Category *',
                                    hintText: 'Select category',
                                    prefixIcon: Icon(Icons.category),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _categories.map((category) {
                                    return DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    );
                                  }).toList(),
                                  onChanged: _isLoading
                                      ? null
                                      : (value) {
                                          setState(() => _categoryController.text = value ?? '');
                                        },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Category is required';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            );
                          } else {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _priceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Price *',
                                      hintText: '0.00',
                                      prefixIcon: Icon(Icons.currency_exchange),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Price is required';
                                      }
                                      final price = double.tryParse(value);
                                      if (price == null || price <= 0) {
                                        return 'Enter a valid price';
                                      }
                                      return null;
                                    },
                                    enabled: !_isLoading,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _categoryController.text.isNotEmpty
                                        ? _categoryController.text
                                        : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Category *',
                                      hintText: 'Select category',
                                      prefixIcon: Icon(Icons.category),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _categories.map((category) {
                                      return DropdownMenuItem(
                                        value: category,
                                        child: Text(category),
                                      );
                                    }).toList(),
                                    onChanged: _isLoading
                                        ? null
                                        : (value) {
                                            setState(() => _categoryController.text = value ?? '');
                                          },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Category is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Allergens
                      TextFormField(
                        controller: _allergensController,
                        decoration: InputDecoration(
                          labelText: 'Allergens',
                          hintText: 'Enter allergens separated by commas',
                          prefixIcon: const Icon(Icons.warning_amber),
                          border: const OutlineInputBorder(),
                          helperText: 'Common: ${_commonAllergens.join(", ")}',
                          helperMaxLines: 2,
                        ),
                        textCapitalization: TextCapitalization.words,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Stock Quantity (Optional)
                      TextFormField(
                        controller: _stockQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Stock Quantity',
                          hintText: 'Leave empty for unlimited',
                          prefixIcon: Icon(Icons.inventory_2),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 24),

                      // Dietary Preferences
                      Text(
                        'Dietary Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        title: const Text('Vegetarian'),
                        subtitle: const Text('Contains no meat or fish'),
                        value: _isVegetarian,
                        onChanged: _isLoading
                            ? null
                            : (value) => setState(() => _isVegetarian = value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        title: const Text('Vegan'),
                        subtitle: const Text('Contains no animal products'),
                        value: _isVegan,
                        onChanged: _isLoading
                            ? null
                            : (value) => setState(() => _isVegan = value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        title: const Text('Gluten Free'),
                        subtitle: const Text('Contains no gluten'),
                        value: _isGlutenFree,
                        onChanged: _isLoading
                            ? null
                            : (value) => setState(() => _isGlutenFree = value ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 16),

                      // Availability
                      SwitchListTile(
                        title: const Text('Available'),
                        subtitle: Text(
                          _isAvailable
                              ? 'Item is available for ordering'
                              : 'Item is not available',
                        ),
                        value: _isAvailable,
                        onChanged: _isLoading
                            ? null
                            : (value) => setState(() => _isAvailable = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _handleSubmit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      widget.mode == MenuItemFormMode.add ? 'Add Item' : 'Save Changes',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Image',
          style: isMobile 
              ? Theme.of(context).textTheme.titleSmall 
              : Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: isMobile ? 6 : 8),
        Container(
          height: isMobile ? 150 : 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
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
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _imageBytes = null;
                                });
                              },
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : _imageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.error_outline, size: 48),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _imageUrl = null;
                                    });
                                  },
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No image selected',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isLoading || _isUploadingImage ? null : _pickImage,
          icon: _isUploadingImage
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload),
          label: Text(_isUploadingImage ? 'Uploading...' : 'Choose Image'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _imageBytes = file.bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final menuService = ref.read(menuServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      // Upload new image if selected
      String? finalImageUrl = _imageUrl;
      if (_imageBytes != null) {
        setState(() => _isUploadingImage = true);

        final menuItemId = widget.menuItem?.id ?? _uuid.v4();

        // Upload image and get URL (with old image deletion if editing)
        finalImageUrl = await storageService.uploadMenuItemImage(
          _imageBytes!,
          menuItemId,
          oldImageUrl: widget.mode == MenuItemFormMode.edit ? _imageUrl : null,
        );

        setState(() => _isUploadingImage = false);
      }

      // Parse allergens
      final allergensList = _allergensController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Parse stock quantity
      final stockQuantity = _stockQuantityController.text.isNotEmpty
          ? int.tryParse(_stockQuantityController.text)
          : null;

      // Create/Update menu item
      final menuItem = MenuItem(
        id: widget.menuItem?.id ?? _uuid.v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        category: _categoryController.text.trim(),
        imageUrl: finalImageUrl,
        allergens: allergensList,
        isVegetarian: _isVegetarian,
        isVegan: _isVegan,
        isGlutenFree: _isGlutenFree,
        isAvailable: _isAvailable,
        stockQuantity: stockQuantity,
        createdAt: widget.menuItem?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.mode == MenuItemFormMode.add) {
        await menuService.addMenuItem(menuItem);
      } else {
        await menuService.updateMenuItem(menuItem);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == MenuItemFormMode.add
                  ? 'Menu item added successfully'
                  : 'Menu item updated successfully',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingImage = false;
        });
      }
    }
  }
}
