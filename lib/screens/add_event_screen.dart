import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:brisconnect/auth/app_user_role.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/services/event_document_id_service.dart';
import 'package:brisconnect/services/event_repository.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';
import 'package:brisconnect/widgets/role_guard.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event date')),
      );
      return;
    }

    final currentUser = LocalAuth.currentLocal;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit an event.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final title = _titleController.text.trim();
    final date = _formatDate(_selectedDate!);
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();
    final eventId = EventDocumentIdService.buildLocalSubmissionId(
      title: title,
      date: date,
      email: currentUser.email,
    );

    try {
      final eventsRef = FirebaseFirestore.instance.collection('events').doc(eventId);
      await eventsRef.set({
        'id': eventId,
        'title': title,
        'date': date,
        'time': 'Time TBA',
        'dateTime': '$date • Time TBA',
        'location': location,
        'description': description,
        'reviewStatus': 'pending',
        'createdByLocalEmail': currentUser.email.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'local_submission',
      });

      // Keep local in-memory view in sync for existing local dashboard tabs.
      EventRepository.addPendingEvent(
        id: eventId,
        title: title,
        date: date,
        location: location,
        description: description,
        createdByLocalEmail: currentUser.email,
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'permission-denied'
                  ? 'Submission blocked by Firestore rules. Please ensure your Local account is approved.'
                  : 'Could not submit event (${e.code}).',
            ),
          ),
        );
      }
      setState(() => _isSaving = false);
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit event. Please try again.')),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Event Submitted'),
        content: const Text(
          'Your event has been saved and marked as Pending Approval. It will not be visible to visitors until approved.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Add Event (Local)'),
      ),
      body: Center(
        child: Card(
          color: AppPalette.surface,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: iconColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = LocalAuth.currentLocal;

    Widget child;
    if (currentUser == null) {
      child = _buildStatusCard(
        icon: Icons.error,
        iconColor: AppPalette.ochre,
        title: 'Not Logged In',
        message: 'Please log in to your Local account to add events.',
      );
    } else if (currentUser.approvalStatus == AccountApprovalStatus.pending) {
      child = _buildStatusCard(
        icon: Icons.schedule,
        iconColor: AppPalette.gold,
        title: 'Account Pending Approval',
        message:
            'Your account is awaiting admin approval. You will be able to submit events once your account is approved. Please check back later.',
      );
    } else if (currentUser.approvalStatus == AccountApprovalStatus.rejected) {
      child = _buildStatusCard(
        icon: Icons.block,
        iconColor: AppPalette.ochre,
        title: 'Account Rejected',
        message:
            'Your account has been rejected and you cannot submit events. Please contact support for more information.',
      );
    } else {
      child = Scaffold(
        backgroundColor: AppPalette.background,
        appBar: AppBar(
          title: const LogoAppBarTitle('Add Event (Local)'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppPalette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppPalette.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Event Title'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Location is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : 'Date: ${_formatDate(_selectedDate!)}',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.ochre,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit Event'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RoleGuard(
      allowedRoles: const {AppUserRole.local},
      deniedMessage: 'Access denied. Local account access is required.',
      child: child,
    );
  }
}
