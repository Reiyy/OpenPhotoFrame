import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/interfaces/storage_provider.dart';

class LocalStorageProvider implements StorageProvider {
  @override
  Future<Directory> getPhotoDirectory() async {
    Directory? baseDir;
    String subDirName = 'photos'; // Default for Android/Sandbox

    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // On Desktop, use a distinct folder name in Documents
      baseDir = await getApplicationDocumentsDirectory();
      subDirName = 'OpenPhotoFrame';
    } else if (Platform.isAndroid) {
      baseDir = await getExternalStorageDirectory();
    }
    
    baseDir ??= await getApplicationDocumentsDirectory();
    
    final dir = Directory('${baseDir.path}/$subDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
