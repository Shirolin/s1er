import '../models/image_load_policy.dart';

/// Whether [ImageViewer] should auto-fetch an inline post image.
bool shouldAutoLoadInlineImages({
  required bool showImages,
  required ImageLoadPolicy policy,
  required bool wifiConnected,
  required bool userRequested,
}) {
  if (!showImages) return false;
  if (userRequested) return true;
  switch (policy) {
    case ImageLoadPolicy.manual:
      return false;
    case ImageLoadPolicy.wifiOnly:
      return wifiConnected;
    case ImageLoadPolicy.always:
      return true;
  }
}
