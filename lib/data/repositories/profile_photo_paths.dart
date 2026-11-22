import 'package:path/path.dart' as p;

/// Maps profile-photo file paths between what the app uses (absolute) and
/// what the preferences store (relative to the app documents directory).
///
/// On iOS the container path changes with an app update, so an absolute path
/// saved earlier points nowhere and the avatar went black (#134). Stored
/// relative, a photo is found again in the current container; an absolute path
/// saved by an older version is re-rooted on read, so nothing needs migrating.
class ProfilePhotoPaths {
  const ProfilePhotoPaths(this._root);

  /// The app documents directory of the current container; null leaves every
  /// path as it is.
  final String? _root;

  static const _dir = 'profile_photos';

  /// The absolute path to open for a stored [value].
  String resolve(String value) {
    final root = _root;
    if (root == null) return value;
    if (!p.isAbsolute(value)) return p.join(root, value);
    final marker = '/$_dir/';
    final at = value.lastIndexOf(marker);
    if (at < 0) return value;
    return p.join(root, value.substring(at + 1));
  }

  /// The form to store for [path]: relative when it lies under the root.
  String store(String path) {
    final root = _root;
    if (root != null && p.isWithin(root, path)) {
      return p.relative(path, from: root);
    }
    return path;
  }
}
