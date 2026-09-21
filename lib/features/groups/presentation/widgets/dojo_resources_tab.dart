import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_sensei/core/theme/app_colors.dart';
import 'package:study_sensei/core/theme/app_typography.dart';
import 'package:study_sensei/features/auth/providers/user_provider.dart';
import 'package:study_sensei/features/common/widgets/sensei_card.dart';
import 'package:study_sensei/features/common/widgets/sensei_primary_button.dart';
import 'package:study_sensei/features/groups/data/models/dojo_resource.dart';
import 'package:study_sensei/features/groups/data/models/dojo_resource_file.dart';
import 'package:study_sensei/features/groups/data/models/group_model.dart';
import 'package:study_sensei/features/groups/data/services/dojo_resource_service.dart';
import 'package:study_sensei/features/groups/data/services/dojo_resource_validation.dart';

class DojoResourcesTab extends StatefulWidget {
  final Group group;
  final String currentUserId;
  final String? currentUserName;
  final DojoResourceService? service;

  const DojoResourcesTab({
    super.key,
    required this.group,
    required this.currentUserId,
    this.currentUserName,
    this.service,
  });

  @override
  State<DojoResourcesTab> createState() => _DojoResourcesTabState();
}

class _DojoResourcesTabState extends State<DojoResourcesTab> {
  bool _isPicking = false;
  DojoResourceService? _defaultService;

  DojoResourceService get _service =>
      widget.service ?? (_defaultService ??= DojoResourceService());

  Future<void> _pickResource() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final file = await _service.pickResource();
      if (file == null || !mounted) return;
      _service.validate(file);
      // The native picker has finished. The confirmation sheet owns its own
      // upload state, so keeping this flag true would leave the tab looking
      // busy for the entire confirmation flow.
      setState(() => _isPicking = false);
      await _showUploadSheet(file);
    } on DojoResourceException catch (error) {
      _showSnack(error.userMessage);
    } catch (error) {
      debugPrint('Dojo resource picker failed: $error');
      _showSnack(
          "Couldn't read this file. Choose it again or try another file.");
    } finally {
      if (mounted && _isPicking) setState(() => _isPicking = false);
    }
  }

  Future<void> _showUploadSheet(DojoResourceFile file) async {
    final uploaderName = widget.currentUserName ?? _readUploaderName();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _UploadResourceSheet(
        group: widget.group,
        file: file,
        uploaderName: uploaderName,
        service: _service,
      ),
    );
  }

  String _readUploaderName() {
    try {
      final userProvider = context.read<UserProvider>();
      return userProvider.userPreferences?.name ??
          userProvider.user?.displayName ??
          'Dojo member';
    } catch (_) {
      return 'Dojo member';
    }
  }

  Future<void> _openResource(DojoResource resource) async {
    try {
      await _service.openResource(resource);
    } on DojoResourceException catch (error) {
      _showSnack(error.userMessage);
    } catch (_) {
      _showSnack("Couldn't open this resource.");
    }
  }

  Future<void> _confirmDelete(DojoResource resource) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text('${resource.name} will be removed from this Dojo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    try {
      await _service.deleteResource(
        group: widget.group,
        resource: resource,
      );
      _showSnack('Resource deleted.');
    } on DojoResourceException catch (error) {
      _showSnack(error.userMessage);
    } catch (_) {
      _showSnack("Couldn't delete this resource. Try again.");
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DojoResource>>(
      stream: _service.watchResources(widget.group.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ResourcesMessage(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load resources.",
            subtitle: 'Check your connection and try again.',
            action: OutlinedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final resources = snapshot.data ?? const <DojoResource>[];
        if (resources.isEmpty) {
          return _ResourcesMessage(
            icon: Icons.folder_open_rounded,
            title: 'Nothing shared yet.',
            subtitle:
                'Upload notes, worksheets, or presentations for your Dojo.',
            action: SenseiPrimaryButton(
              text: 'Upload Resource',
              icon: Icons.upload_file_rounded,
              width: 220,
              isLoading: _isPicking,
              onPressed: _isPicking ? null : _pickResource,
            ),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
              itemCount: resources.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: _ResourcesIntro(),
                  );
                }
                final resource = resources[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ResourceCard(
                    resource: resource,
                    canDelete: _service.canDelete(
                      group: widget.group,
                      resource: resource,
                      userId: widget.currentUserId,
                    ),
                    onOpen: () => _openResource(resource),
                    onDelete: () => _confirmDelete(resource),
                  ),
                );
              },
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton(
                heroTag: 'dojo-resources-upload-${widget.group.id}',
                tooltip: 'Add resource',
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                onPressed: _isPicking ? null : _pickResource,
                child: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResourcesIntro extends StatelessWidget {
  const _ResourcesIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resources', style: AppTypography.sectionTitle),
        SizedBox(height: 4),
        Text(
          'Notes, worksheets, presentations, and shared study material.',
          style: AppTypography.bodyMedium,
        ),
      ],
    );
  }
}

class ResourceCard extends StatelessWidget {
  final DojoResource resource;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const ResourceCard({
    super.key,
    required this.resource,
    required this.canDelete,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = resource.extension.toUpperCase();
    return Semantics(
      button: true,
      label:
          '${resource.name}, $typeLabel, ${DojoResourceValidation.formatFileSize(resource.sizeBytes)}',
      child: SenseiCard(
        onTap: onOpen,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          children: [
            _FileTypeIcon(extension: resource.extension),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$typeLabel · ${DojoResourceValidation.formatFileSize(resource.sizeBytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uploaded by ${resource.uploadedByName} · ${_relativeTime(resource.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Resource actions',
              onSelected: (value) {
                if (value == 'open') onOpen();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'open',
                  child: Text('Open'),
                ),
                if (canDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${value.day}/${value.month}/${value.year}';
  }
}

class _FileTypeIcon extends StatelessWidget {
  final String extension;

  const _FileTypeIcon({required this.extension});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (extension.toLowerCase()) {
      'pdf' => (Icons.picture_as_pdf_rounded, AppColors.error),
      'doc' || 'docx' => (Icons.description_rounded, AppColors.info),
      'ppt' || 'pptx' => (Icons.slideshow_rounded, AppColors.warning),
      'jpg' || 'jpeg' || 'png' || 'webp' => (
          Icons.image_rounded,
          AppColors.success
        ),
      _ => (Icons.insert_drive_file_rounded, AppColors.primaryLight),
    };

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _ResourcesMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  const _ResourcesMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.primaryLight),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center, style: AppTypography.sectionTitle),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center, style: AppTypography.bodyMedium),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }
}

class _UploadResourceSheet extends StatefulWidget {
  final Group group;
  final DojoResourceFile file;
  final String uploaderName;
  final DojoResourceService service;

  const _UploadResourceSheet({
    required this.group,
    required this.file,
    required this.uploaderName,
    required this.service,
  });

  @override
  State<_UploadResourceSheet> createState() => _UploadResourceSheetState();
}

class _UploadResourceSheetState extends State<_UploadResourceSheet> {
  bool _isUploading = false;
  double _progress = 0;

  Future<void> _upload() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      await widget.service.uploadResource(
        group: widget.group,
        file: widget.file,
        uploaderName: widget.uploaderName,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress.value.clamp(0, 1));
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resource uploaded.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DojoResourceException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.userMessage),
            behavior: SnackBarBehavior.floating),
      );
      setState(() => _isUploading = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload failed. Check your connection and try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Upload Resource', style: AppTypography.sectionTitle),
            const SizedBox(height: 14),
            ResourceFileSummary(file: widget.file),
            if (_isUploading) ...[
              const SizedBox(height: 18),
              Semantics(
                label: 'Upload progress',
                value: '${(_progress * 100).round()} percent',
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceHighlight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Uploading ${widget.file.name} ${(_progress * 100).round()}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
            ],
            const SizedBox(height: 20),
            SenseiPrimaryButton(
              text: 'Upload',
              icon: Icons.cloud_upload_rounded,
              isLoading: _isUploading,
              onPressed: _isUploading ? null : _upload,
            ),
            if (!_isUploading) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ResourceFileSummary extends StatelessWidget {
  final DojoResourceFile file;

  const ResourceFileSummary({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return SenseiCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _FileTypeIcon(extension: file.extension),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  '${file.extension.toUpperCase()} · ${DojoResourceValidation.formatFileSize(file.sizeBytes)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
