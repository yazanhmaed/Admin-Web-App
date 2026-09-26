import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// خطأ استخراج اسم الحزمة (applicationId) من ملف APK.
class ApkManifestParseException implements Exception {
  ApkManifestParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// يستخرج اسم الحزمة (applicationId) من ملف `.apk` عبر قراءة
/// `AndroidManifest.xml` المضغوط داخله (صيغة Android Binary XML الثنائية —
/// وليست XML نصية عادية) وتحليل السمة `package` بعقدة `<manifest>` الجذرية.
///
/// لا يوجد باقة (package) على pub.dev مُحدَّثة وتدعم الويب لهذا الغرض بشكل
/// جاهز (الوحيدة المتوفرة، apk_parser، متوقفة منذ سنوات ولا تدعم
/// null-safety) — لذا هذا تحليل ثنائي مخصص ومحدود النطاق، مبني فوق حزمة
/// `archive` (مُتقنة الصيانة، Dart خالص، تعمل بالويب) لفكّ ضغط الـ APK فقط.
/// صيغة AXML ثابتة وموثّقة رسمياً بمشروع AOSP منذ سنوات طويلة.
String extractPackageNameFromApk(Uint8List apkBytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(apkBytes);
  } catch (_) {
    throw ApkManifestParseException(
        'الملف تالف أو ليس بصيغة APK/ZIP صحيحة.');
  }

  final manifestFile = archive.findFile('AndroidManifest.xml');
  if (manifestFile == null) {
    throw ApkManifestParseException(
        'لم يتم العثور على AndroidManifest.xml داخل الملف — تأكد أنه ملف APK صالح.');
  }

  final Uint8List manifestBytes;
  try {
    manifestBytes = Uint8List.fromList(manifestFile.content as List<int>);
  } catch (_) {
    throw ApkManifestParseException(
        'تعذّر استخراج AndroidManifest.xml من ملف APK.');
  }

  String? packageName;
  try {
    packageName = _AxmlPackageExtractor(manifestBytes).extractPackageName();
  } catch (_) {
    packageName = null;
  }

  if (packageName == null || packageName.trim().isEmpty) {
    throw ApkManifestParseException(
        'تعذّر إيجاد اسم الحزمة (package) داخل AndroidManifest.xml — صيغة الملف غير مدعومة أو غير متوقعة.');
  }
  return packageName.trim();
}

/// محلِّل ثنائي محدود النطاق لصيغة Android Binary XML (AXML)، يكتفي
/// باستخراج السمة `package` بعقدة `<manifest>` الجذرية فقط (لا يبني شجرة
/// XML كاملة). راجع توثيق البنية الرسمية:
/// `frameworks/base/include/androidfw/ResourceTypes.h` بمشروع AOSP.
class _AxmlPackageExtractor {
  _AxmlPackageExtractor(this.bytes) : data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData data;

  static const _chunkStringPool = 0x0001;
  static const _chunkXmlStartElement = 0x0102;
  static const _typeString = 0x03;
  static const _noValue = 0xFFFFFFFF;

  int _u16(int offset) => data.getUint16(offset, Endian.little);
  int _u32(int offset) => data.getUint32(offset, Endian.little);
  int _u8(int offset) => data.getUint8(offset);

  String? extractPackageName() {
    if (bytes.length < 8) {
      throw ApkManifestParseException('حجم ملف AndroidManifest.xml غير صالح.');
    }

    // ترويسة المستند الخارجية (RES_XML_TYPE): type(u16) + headerSize(u16) +
    // size(u32) = 8 بايت، ثم سلسلة من الأجزاء (chunks) الفرعية مباشرة.
    var offset = 8;
    List<String>? stringPool;

    while (offset + 8 <= bytes.length) {
      final chunkStart = offset;
      final type = _u16(chunkStart);
      final headerSize = _u16(chunkStart + 2);
      final size = _u32(chunkStart + 4);
      if (size < 8 || headerSize < 8 || chunkStart + size > bytes.length) {
        break;
      }

      if (type == _chunkStringPool) {
        stringPool = _parseStringPool(chunkStart, headerSize);
      } else if (type == _chunkXmlStartElement) {
        final found = _tryExtractFromStartElement(
            chunkStart, headerSize, stringPool);
        if (found != null) return found;
      }

      offset = chunkStart + size;
    }
    return null;
  }

  List<String> _parseStringPool(int chunkStart, int headerSize) {
    final stringCount = _u32(chunkStart + 8);
    final flags = _u32(chunkStart + 16);
    final stringsStart = _u32(chunkStart + 20);
    final isUtf8 = (flags & 0x100) != 0;

    final offsetsBase = chunkStart + headerSize;
    final strings = <String>[];
    for (var i = 0; i < stringCount; i++) {
      final relOffset = _u32(offsetsBase + i * 4);
      final strOffset = chunkStart + stringsStart + relOffset;
      if (strOffset < 0 || strOffset >= bytes.length) {
        strings.add('');
        continue;
      }
      strings.add(isUtf8 ? _readUtf8String(strOffset) : _readUtf16String(strOffset));
    }
    return strings;
  }

  String _readUtf16String(int offset) {
    var o = offset;
    var len = _u16(o);
    o += 2;
    if ((len & 0x8000) != 0) {
      final high = len & 0x7FFF;
      final low = _u16(o);
      o += 2;
      len = (high << 16) | low;
    }
    if (o + len * 2 > bytes.length) return '';
    final charCodes = List<int>.generate(len, (i) => _u16(o + i * 2));
    return String.fromCharCodes(charCodes);
  }

  String _readUtf8String(int offset) {
    var o = offset;
    // طول عدد وحدات UTF-16 المكافئ (غير مستخدَم هنا) — بايت واحد أو اثنان.
    final u16LenFirst = _u8(o);
    o += 1;
    if ((u16LenFirst & 0x80) != 0) o += 1;

    var u8Len = _u8(o);
    o += 1;
    if ((u8Len & 0x80) != 0) {
      final high = u8Len & 0x7F;
      final low = _u8(o);
      o += 1;
      u8Len = (high << 8) | low;
    }
    if (o + u8Len > bytes.length) return '';
    return utf8.decode(bytes.sublist(o, o + u8Len), allowMalformed: true);
  }

  String? _tryExtractFromStartElement(
      int chunkStart, int headerSize, List<String>? stringPool) {
    if (stringPool == null) return null;

    // ResXMLTree_attrExt تبدأ فور نهاية الترويسة العامة (headerSize).
    final attrExtBase = chunkStart + headerSize;
    final nameIndex = _u32(attrExtBase + 4);
    final elementName = _stringAt(stringPool, nameIndex);
    if (elementName != 'manifest') return null;

    final attributeStart = _u16(attrExtBase + 8);
    final attributeSize = _u16(attrExtBase + 10);
    final attributeCount = _u16(attrExtBase + 12);
    if (attributeSize < 20) return null;
    final attributesBase = attrExtBase + attributeStart;

    for (var i = 0; i < attributeCount; i++) {
      final attrOffset = attributesBase + i * attributeSize;
      if (attrOffset + 20 > bytes.length) break;

      final attrNameIndex = _u32(attrOffset + 4);
      final attrName = _stringAt(stringPool, attrNameIndex);
      if (attrName != 'package') continue;

      final rawValueIndex = _u32(attrOffset + 8);
      final rawValue = _stringAt(stringPool, rawValueIndex);
      if (rawValue != null && rawValue.isNotEmpty) return rawValue;

      final dataType = _u8(attrOffset + 15);
      if (dataType == _typeString) {
        final typedValueIndex = _u32(attrOffset + 16);
        final typedValue = _stringAt(stringPool, typedValueIndex);
        if (typedValue != null && typedValue.isNotEmpty) return typedValue;
      }
    }
    return null;
  }

  String? _stringAt(List<String> pool, int index) {
    if (index == _noValue || index < 0 || index >= pool.length) return null;
    return pool[index];
  }
}
