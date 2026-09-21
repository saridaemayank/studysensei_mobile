import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/sensei_help_request.dart';
import 'camera_screen.dart';
import '../../common/layouts/main_layout.dart';
import 'select_area_screen.dart';
import 'doubt_processing_screen.dart';
import '../services/sensei_image_preparation.dart';
import '../models/sensei_doubt_error.dart';

/// Shared image preparation, selection and processing boundary.
class SenseiImageFlow {
  SenseiImageFlow._();

  static Future<SenseiHelpRequest?> takePhoto(
    BuildContext context, {
    String subject = 'General',
    String concept = 'Doubt',
  }) async {
    final image = await Navigator.of(context).push<XFile>(MaterialPageRoute(
      builder: (_) => CameraScreen(subject: subject, concept: concept),
    ));
    if (image == null || !context.mounted) return null;
    return selectArea(context, image);
  }

  static Future<SenseiHelpRequest?> chooseFromGallery(
      BuildContext context) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image == null ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent == false) {
      return null;
    }
    return selectArea(context, image);
  }

  static Future<SenseiHelpRequest?> selectArea(
      BuildContext context, XFile image) async {
    XFile prepared;
    try {
      prepared = await SenseiImagePreparation().prepare(image);
    } on SenseiDoubtError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return null;
    }
    if (!context.mounted) return null;
    final navigator = Navigator.of(context);
    final origin = ModalRoute.of(context);
    return navigator.push<SenseiHelpRequest>(MaterialPageRoute(
      builder: (_) => SelectAreaScreen(
          image: prepared,
          onGetHelp: (request) async {
            await Navigator.of(context).push<void>(MaterialPageRoute(
              builder: (_) => DoubtProcessingScreen(
                  request: request,
                  onTryAnother: () {
                    if (context.mounted) MainLayout.showDoubt(context);
                    navigator
                        .popUntil((route) => route == origin || route.isFirst);
                  }),
            ));
          }),
    ));
  }
}
