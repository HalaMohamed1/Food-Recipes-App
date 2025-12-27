import 'package:flutter/material.dart';
import 'package:food_recipes_app/models/checklist.dart';
import 'package:food_recipes_app/services/checklist_service.dart';
import 'package:food_recipes_app/services/auth_service.dart';

class CheckListScreen extends StatefulWidget {
  const CheckListScreen({super.key});

  @override
  State<CheckListScreen> createState() => _CheckListScreenState();
}

class _CheckListScreenState extends State<CheckListScreen> {
  final ChecklistService _checklistService = ChecklistService();
  final AuthService _authService = AuthService();
  
  late List<Checklist> checklists;
  int selectedChecklistIndex = 0;
  PageController pageController = PageController();
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChecklists();
  }

  Future<void> _loadChecklists() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final fetchedChecklists =
            await _checklistService.getChecklists(user.uid);
        setState(() {
          checklists = fetchedChecklists;
          isLoading = false;
        });
      } else {
        // User not logged in, use sample data
        setState(() {
          checklists = List.from(Checklist.sampleChecklists);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load checklists: $e';
        checklists = List.from(Checklist.sampleChecklists);
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleItem(String checklistId, String itemId) async {
    // Optimistic update
    setState(() {
      final checklistIndex =
          checklists.indexWhere((c) => c.id == checklistId);
      if (checklistIndex != -1) {
        final itemIndex = checklists[checklistIndex]
            .items
            .indexWhere((item) => item.id == itemId);
        if (itemIndex != -1) {
          final item = checklists[checklistIndex].items[itemIndex];
          checklists[checklistIndex].items[itemIndex] =
              item.copyWith(isChecked: !item.isChecked);
        }
      }
    });

    // Persist to Firestore
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final checklistIndex =
            checklists.indexWhere((c) => c.id == checklistId);
        if (checklistIndex != -1) {
          final itemIndex = checklists[checklistIndex]
              .items
              .indexWhere((item) => item.id == itemId);
          if (itemIndex != -1) {
            final newCheckedState =
                checklists[checklistIndex].items[itemIndex].isChecked;
            await _checklistService.toggleChecklistItem(
              user.uid,
              checklistId,
              itemId,
              newCheckedState,
            );
          }
        }
      }
    } catch (e) {
      // Revert on error
      setState(() {
        final checklistIndex =
            checklists.indexWhere((c) => c.id == checklistId);
        if (checklistIndex != -1) {
          final itemIndex = checklists[checklistIndex]
              .items
              .indexWhere((item) => item.id == itemId);
          if (itemIndex != -1) {
            final item = checklists[checklistIndex].items[itemIndex];
            checklists[checklistIndex].items[itemIndex] =
                item.copyWith(isChecked: !item.isChecked);
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update item: $e')),
        );
      }
    }
  }

  Future<void> _deleteChecklist(int index) async {
    final checklistToDelete = checklists[index];
    
    setState(() {
      checklists.removeAt(index);
      if (selectedChecklistIndex >= checklists.length) {
        selectedChecklistIndex = checklists.length - 1;
      }
      if (selectedChecklistIndex < 0) selectedChecklistIndex = 0;
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _checklistService.deleteChecklist(user.uid, checklistToDelete.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checklist deleted')),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        checklists.insert(index, checklistToDelete);
        selectedChecklistIndex = index;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete checklist: $e')),
        );
      }
    }
  }

  void _addNewChecklist() {
    showDialog(
      context: context,
      builder: (context) => _AddChecklistDialog(
        onAdd: (title) async {
          final newChecklist = Checklist(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            recipeId: '',
            createdAt: DateTime.now(),
            items: [],
          );

          setState(() {
            checklists.add(newChecklist);
            selectedChecklistIndex = checklists.length - 1;
            pageController.animateToPage(
              selectedChecklistIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });

          // Persist to Firestore
          try {
            final user = _authService.currentUser;
            if (user != null) {
              await _checklistService.createChecklist(user.uid, newChecklist);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save checklist: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _addItemToChecklist(int checklistIndex) {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        onAdd: (name, quantity, unit, category) async {
          final newItem = ChecklistItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            quantity: quantity,
            unit: unit,
            category: category,
            isChecked: false,
          );

          setState(() {
            checklists[checklistIndex].items.add(newItem);
          });

          // Persist to Firestore
          try {
            final user = _authService.currentUser;
            if (user != null) {
              await _checklistService.updateChecklist(
                user.uid,
                checklists[checklistIndex],
              );
            }
          } catch (e) {
            // Revert on error
            setState(() {
              checklists[checklistIndex].items.removeLast();
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to add item: $e')),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    if (isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
      );
    }

    if (checklists.isEmpty) {
      return _buildEmptyState(theme, textColor);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: theme.appBarTheme.backgroundColor ?? theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Image.asset('assets/images/cook-book.png', height: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "FLAVOR FIESTA",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Add button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _addNewChecklist,
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // PageView
          Expanded(
            child: PageView.builder(
              controller: pageController,
              onPageChanged: (index) =>
                  setState(() => selectedChecklistIndex = index),
              itemCount: checklists.length,
              itemBuilder: (context, index) =>
                  _buildChecklistPage(theme, checklists[index], index),
            ),
          ),

          // Bottom Selector
          if (checklists.length > 1)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: checklists.length,
                itemBuilder: (context, index) {
                  final isSelected = index == selectedChecklistIndex;
                  return GestureDetector(
                    onTap: () {
                      pageController.animateToPage(index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.orangeAccent
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.orangeAccent
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          checklists[index].title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isSelected ? Colors.white : textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChecklistPage(
      ThemeData theme, Checklist checklist, int index) {
    final textColor = theme.textTheme.bodyLarge?.color;
    final completedCount = checklist.items.where((i) => i.isChecked).length;
    final totalCount = checklist.items.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // Progress header
              Container(
                margin: const EdgeInsets.only(top: 16, bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            checklist.title,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () => _deleteChecklist(index),
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red[600]),
                            iconSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 1.0
                              ? Colors.green
                              : Colors.orangeAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$completedCount of $totalCount items completed',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Items
              Expanded(
                child: checklist.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.checklist,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items in this checklist',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the + button to add items',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 20),
                        children: checklist.items.map((item) {
                          return _buildChecklistTile(theme, item, checklist.id);
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
        // Floating Action Button to add items
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () => _addItemToChecklist(index),
            backgroundColor: Colors.orangeAccent,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistTile(
      ThemeData theme, ChecklistItem item, String checklistId) {
    final textColor = theme.textTheme.bodyLarge?.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isChecked
              ? Colors.green
              : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: () => _toggleItem(checklistId, item.id),
        leading: Icon(
          item.isChecked ? Icons.check_box : Icons.check_box_outline_blank,
          color: item.isChecked ? Colors.green : textColor,
        ),
        title: Text(
          item.name,
          style: TextStyle(
            color: item.isChecked ? Colors.grey : textColor,
            decoration: item.isChecked
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Text(
          '${item.quantity} ${item.unit}',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, Color? textColor) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: theme.appBarTheme.backgroundColor ?? theme.cardColor,
              child: Row(
                children: [
                  Image.asset('assets/images/cook-book.png', height: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "FLAVOR FIESTA",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: _addNewChecklist,
                      icon: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'No Checklists Yet',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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

class _AddChecklistDialog extends StatefulWidget {
  final Future<void> Function(String) onAdd;
  const _AddChecklistDialog({required this.onAdd});

  @override
  State<_AddChecklistDialog> createState() => _AddChecklistDialogState();
}

class _AddChecklistDialogState extends State<_AddChecklistDialog> {
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text('Create New Checklist', style: TextStyle(color: textColor)),
      content: TextField(
        controller: _titleController,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: 'Enter checklist name',
          filled: true,
          fillColor: theme.scaffoldBackgroundColor,
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textColor)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              widget.onAdd(_titleController.text);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

// Add Item Dialog
class _AddItemDialog extends StatefulWidget {
  final Future<void> Function(String name, String quantity, String unit, String category) onAdd;
  const _AddItemDialog({required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  late TextEditingController _nameController;
  late TextEditingController _quantityWithUnitController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _quantityWithUnitController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityWithUnitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Text('Add Item', style: TextStyle(color: textColor)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Item Name',
              hintText: 'e.g., Romaine lettuce',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              hintStyle: TextStyle(color: Colors.grey[500]),
              labelStyle: TextStyle(color: textColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantityWithUnitController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Quantity (optional)',
              hintText: 'e.g., 2 heads or 1/2 cup',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              hintStyle: TextStyle(color: Colors.grey[500]),
              labelStyle: TextStyle(color: textColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textColor)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              final quantityText = _quantityWithUnitController.text.trim();
              // Split quantity and unit if provided
              String quantity = '';
              String unit = '';
              
              if (quantityText.isNotEmpty) {
                final parts = quantityText.split(' ');
                if (parts.length >= 2) {
                  quantity = parts[0];
                  unit = parts.sublist(1).join(' ');
                } else {
                  quantity = quantityText;
                  unit = '';
                }
              }
              
              widget.onAdd(
                _nameController.text.trim(),
                quantity,
                unit,
                'Ingredients',
              );
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
