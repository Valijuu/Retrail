/// Picks + crops a profile photo, saving it to app files and returning the
/// saved path (or null if cancelled). Interface seam so the UI is testable with
/// a fake; the real implementation is device-verified.
abstract interface class ProfilePhotoPicker {
  Future<String?> pickAndCrop();
}
