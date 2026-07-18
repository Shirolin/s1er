import 'dart:js_interop';

@JS('window')
external WindowJS get window;

extension type WindowJS(JSObject _) implements JSObject {
  external LocationJS get location;
}

extension type LocationJS(JSObject _) implements JSObject {
  external void reload();
}

void reloadApp() {
  window.location.reload();
}
