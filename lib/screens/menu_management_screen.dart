import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:brisconnect/models/business.dart';
import 'package:brisconnect/models/menu_item.dart';
import 'package:brisconnect/services/business_profile_service.dart';
import 'package:brisconnect/services/firebase_media_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Screen for managing menu items with images, prices, descriptions, and tags.
class MenuManagementScreen extends StatefulWidget {
  final Business business;

  const MenuManagementScreen({
    super.key,
    required this.business,
  });

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  late List<MenuItem> _menuItems;
  final _businessProfileService = BusinessProfileService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _menuItems = List.from(widget.business.menuItemsModel ?? []);
    _loading = false;
  }

  Future<void> _saveMenuItems() async {
    setState(() => _loading = true);
    try {
      final updated = widget.business.copyWith(menuItemsModel: _menuItems);
      await _businessProfileService.updateBusinessProfile(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Menu saved successfully'),
            backgroundColor: AppPalette.ochre,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving menu: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _editItem(int index) {
    showDialog(
      context: context,
      builder: (_) => MenuItemEditDialog(
        item: _menuItems[index],
        onSave: (updatedItem) {
          setState(() => _menuItems[index] = updatedItem);
          _saveMenuItems();
        },
      ),
    );
  }

  void _deleteItem(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text(
          'Are you sure you want to delete "${_menuItems[index].name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _menuItems.removeAt(index));
              _saveMenuItems();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (_) => MenuItemEditDialog(
        onSave: (newItem) {
          setState(() => _menuItems.add(newItem));
          _saveMenuItems();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF4FF),
      appBar: AppBar(
        title: const Text('Menu Management'),
        backgroundColor: AppPalette.ochre,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppPalette.ochre),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.grey.shade400, width: 1.4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.business.businessName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_menuItems.length} item${_menuItems.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppPalette.mutedText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Add Item Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Menu Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.ochre,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Menu Items Grid
                  if (_menuItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.restaurant_menu_rounded,
                              size: 48,
                              color: AppPalette.ochre.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No menu items yet',
                              style: TextStyle(
                                color: AppPalette.mutedText,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add your first item to get started',
                              style: TextStyle(
                                color: AppPalette.mutedText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const spacing = 12.0;
                        final columns = constraints.maxWidth >= 1100
                            ? 4
                            : constraints.maxWidth >= 700
                                ? 3
                                : 2;
                        final cardWidth =
                            (constraints.maxWidth - spacing * (columns - 1)) /
                                columns;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: List.generate(_menuItems.length, (index) {
                            final item = _menuItems[index];
                            return SizedBox(
                              width: cardWidth,
                              child: MenuItemCard(
                                item: item,
                                onEdit: () => _editItem(index),
                                onDelete: () => _deleteItem(index),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

/// Card displaying a single menu item
class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image: 4:3 ratio, capped so it never dominates on wide desktop
          // cards, so all menu cards line up to the same dimensions.
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFEBF4FF),
                  child: hasImage
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: AppPalette.mutedText,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          color: AppPalette.mutedText,
                          size: 32,
                        ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name (fixed 2-line slot so every card lines up)
                SizedBox(
                  height: 32,
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Price (fixed slot, blank when not set)
                SizedBox(
                  height: 16,
                  child: item.price != null
                      ? Text(
                          item.formattedPrice,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.ochre,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 4),
                // Description (fixed 2-line slot, blank when not set)
                SizedBox(
                  height: 29,
                  child: (item.description ?? '').isNotEmpty
                      ? Text(
                          item.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppPalette.mutedText,
                            height: 1.3,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                // Tags (fixed slot, blank when not set)
                SizedBox(
                  height: 22,
                  child: item.tags.isNotEmpty
                      ? Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: item.tags.take(2).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppPalette.ochre.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppPalette.ochre,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      : null,
                ),
              ],
            ),
          ),
          // Action Buttons (clear bottom bar, not floating)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 15,
                            color: AppPalette.ochre,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.ochre,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            size: 15,
                            color: Colors.red,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Delete',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
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
}

/// Dialog for adding/editing menu items
class MenuItemEditDialog extends StatefulWidget {
  final MenuItem? item;
  final Function(MenuItem) onSave;

  const MenuItemEditDialog({
    super.key,
    this.item,
    required this.onSave,
  });

  @override
  State<MenuItemEditDialog> createState() => _MenuItemEditDialogState();
}

class _MenuItemEditDialogState extends State<MenuItemEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _tagsCtrl;
  XFile? _selectedImage;
  String? _imageUrl;
  bool _uploading = false;
  final _picker = ImagePicker();
  final _mediaService = FirebaseMediaService();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _descCtrl = TextEditingController(text: widget.item?.description ?? '');
    _priceCtrl = TextEditingController(
      text: widget.item?.price != null
          ? widget.item!.price!.toStringAsFixed(2)
          : '',
    );
    _tagsCtrl = TextEditingController(
      text: widget.item?.tags.join(', ') ?? '',
    );
    _imageUrl = widget.item?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked != null) {
      setState(() => _selectedImage = picked);
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await _selectedImage!.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'menu_items/$timestamp.jpg';

      final url = await _mediaService.uploadBytes(
        path: path,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      setState(() {
        _imageUrl = url;
        _selectedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Image uploaded'),
            backgroundColor: AppPalette.ochre,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter item name'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Auto-upload a picked-but-not-yet-uploaded photo so it isn't silently
    // dropped if the user taps Save without pressing "Upload Image" first.
    if (_selectedImage != null && _imageUrl == null) {
      await _uploadImage();
      if (_selectedImage != null) return; // upload failed, abort save
    }

    final price = _priceCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_priceCtrl.text.trim());
    final tags = _tagsCtrl.text
        .trim()
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final item = MenuItem(
      name: name,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      price: price,
      imageUrl: _imageUrl,
      tags: tags,
    );

    widget.onSave(item);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Menu Item' : 'Add Menu Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFEBF4FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _selectedImage != null
                  ? kIsWeb
                      ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                      : Image.file(File(_selectedImage!.path),
                          fit: BoxFit.cover)
                  : _imageUrl != null
                      ? Image.network(_imageUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                          return const Icon(
                            Icons.image_not_supported,
                            color: AppPalette.mutedText,
                          );
                        })
                      : GestureDetector(
                          onTap: _pickImage,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_camera_outlined,
                                color: AppPalette.ochre,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to add photo',
                                style: TextStyle(
                                  color: AppPalette.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: 12),

            // Image Action Button
            if (_selectedImage != null || _imageUrl == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploading
                      ? null
                      : (_selectedImage != null ? _uploadImage : _pickImage),
                  icon: Icon(_uploading
                      ? Icons.hourglass_bottom
                      : Icons.photo_library),
                  label: Text(
                    _uploading
                        ? 'Uploading...'
                        : (_selectedImage != null
                            ? 'Upload Image'
                            : 'Select Photo'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.ochre,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            if (_imageUrl != null && _selectedImage == null)
              TextButton.icon(
                onPressed: () {
                  setState(() => _imageUrl = null);
                },
                icon: const Icon(Icons.clear),
                label: const Text('Remove Image'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),

            const SizedBox(height: 16),

            // Name
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Item Name *',
                hintText: 'e.g., Grilled Salmon',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Optional description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Price
            TextField(
              controller: _priceCtrl,
              decoration: InputDecoration(
                labelText: 'Price',
                hintText: 'e.g., 28.50',
                prefix: const Text('\$ '),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            // Tags
            TextField(
              controller: _tagsCtrl,
              decoration: InputDecoration(
                labelText: 'Tags',
                hintText: 'e.g., Popular, Chef Recommendation',
                helperText: 'Separate with commas',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _uploading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.ochre,
            foregroundColor: Colors.white,
          ),
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
