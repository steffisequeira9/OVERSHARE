import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'purpose.dart';

class SelectedImageNotifier extends Notifier<XFile?> {
  @override
  XFile? build() => null;

  void setImage(XFile? file) {
    state = file;
  }

  void clear() {
    state = null;
  }
}

final selectedImageProvider =
    NotifierProvider<SelectedImageNotifier, XFile?>(SelectedImageNotifier.new);

class SelectedPurposeNotifier extends Notifier<SharingPurpose?> {
  @override
  SharingPurpose? build() => null;

  void setPurpose(SharingPurpose? purpose) {
    state = purpose;
  }

  void clear() {
    state = null;
  }
}

final selectedPurposeProvider =
    NotifierProvider<SelectedPurposeNotifier, SharingPurpose?>(
  SelectedPurposeNotifier.new,
);

class SelectedAudienceNotifier extends Notifier<Audience> {
  @override
  Audience build() => Audience.privateAudience;

  void setAudience(Audience audience) {
    state = audience;
  }

  void reset() {
    state = Audience.privateAudience;
  }
}

final selectedAudienceProvider =
    NotifierProvider<SelectedAudienceNotifier, Audience>(
  SelectedAudienceNotifier.new,
);
