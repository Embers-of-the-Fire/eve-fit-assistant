import 'dart:io';

import 'package:eve_fit_assistant/storage/static/storage.dart';
import 'package:flutter/material.dart';

Future<Directory> getStaticIconDir() async {
  final Directory storageDir = await getStaticStorageDir();
  final Directory staticIconDir = Directory('${storageDir.path}/icons');
  return staticIconDir;
}

class StaticIcon {
  late Directory _iconDir;

  StaticIcon._();

  static Future<StaticIcon> init() async {
    final StaticIcon staticIcon = StaticIcon._();
    staticIcon._iconDir = await getStaticIconDir();
    return staticIcon;
  }

  Future<File?> getIconFile(int iconID) async {
    final file = File('${_iconDir.path}/icon/$iconID.png');
    if (!await file.exists()) {
      return null;
    }
    return file;
  }

  File? getIconFileSync(int iconID) {
    final file = File('${_iconDir.path}/icon/$iconID.png');
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }

  Future<Image?> getIcon(
    int iconID, {
    double? height,
    double? width,
    double scale = 1.0,
  }) async {
    final File? iconFile = await getIconFile(iconID);
    if (iconFile == null) {
      return null;
    }
    return Image(
      image: FileImage(iconFile, scale: scale),
      height: height,
      width: width,
    );
  }

  Image? getIconSync(
    int iconID, {
    double? height,
    double? width,
    double scale = 1.0,
  }) {
    final File? iconFile = getIconFileSync(iconID);
    if (iconFile == null) {
      return null;
    }
    return Image(
      image: FileImage(iconFile, scale: scale),
      height: height,
      width: width,
    );
  }

  FileImage? getIconFileImageSync(int iconID, {double scale = 1.0}) {
    final file = getIconFileSync(iconID);
    if (file == null) return null;
    if (!file.existsSync()) {
      return null;
    }
    return FileImage(file, scale: scale);
  }

  Future<File?> getTypeIconFile(int typeID) async {
    final file = File('${_iconDir.path}/type/$typeID.png');
    if (!await file.exists()) {
      return null;
    }
    return file;
  }

  File? getTypeIconFileSync(int typeID) {
    final file = File('${_iconDir.path}/type/$typeID.png');
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }

  Future<Image?> getTypeIcon(
    int typeID, {
    double? height,
    double? width,
    double scale = 1.0,
  }) async {
    final File? iconFile = await getTypeIconFile(typeID);
    if (iconFile == null) {
      return null;
    }
    return Image(
      image: FileImage(iconFile, scale: scale),
      height: height,
      width: width,
    );
  }

  Image? getTypeIconSync(
    int typeID, {
    double? height,
    double? width,
    double scale = 1.0,
  }) {
    final File? iconFile = getTypeIconFileSync(typeID);
    if (iconFile == null) {
      return null;
    }
    return Image(
      image: FileImage(iconFile, scale: scale),
      height: height,
      width: width,
    );
  }

  FileImage? getTypeIconFileImageSync(int typeID, {double scale = 1.0}) {
    final file = File('${_iconDir.path}/type/$typeID.png');
    if (!file.existsSync()) {
      return null;
    }
    return FileImage(file, scale: scale);
  }
}
