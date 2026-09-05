import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// على الويب، بعض أخطاء Firestore/Firebase تُغلَّف أثناء عبورها لطبقة
/// تفاعل JS بغلاف عام برسالة "Dart exception thrown from converted
/// Future..." يُخفي الخطأ الحقيقي. هذه الدالة تحاول استخراج الخطأ
/// الأصلي المخزَّن بخاصية `error` (كـ JSBoxedDartObject)، وإن تعذّر ذلك
/// تُعيد الخطأ كما هو.
Object unwrapWebError(Object error) {
  try {
    final jsValue = error as JSAny?;
    if (jsValue != null && jsValue.isA<JSObject>()) {
      final boxed = (jsValue as JSObject).getProperty<JSAny?>('error'.toJS);
      if (boxed != null && boxed.isA<JSBoxedDartObject>()) {
        return (boxed as JSBoxedDartObject).toDart;
      }
    }
  } catch (_) {
    // تجاهل: لو فشل الاستخراج نُعيد الخطأ الأصلي كما هو أدناه.
  }
  return error;
}
