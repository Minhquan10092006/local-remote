import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

class Win32ScreenCapturer {
  static DynamicLibrary? _user32;
  static DynamicLibrary? _gdi32;
  static bool _initialized = false;

  // Function pointers
  static late int Function(int) _getDC;
  static late int Function(int, int) _releaseDC;
  static late int Function(int) _getSystemMetrics;
  static late int Function(int, int) _setCursorPos;
  static late void Function(int, int, int, int, int) _mouseEvent;
  static late void Function(int, int, int, int) _keybdEvent;

  static late int Function(int) _createCompatibleDC;
  static late int Function(int) _deleteDC;
  static late int Function(int, int, int) _createCompatibleBitmap;
  static late int Function(int, int) _selectObject;
  static late int Function(int) _deleteObject;
  static late int Function(int, int, int, int, int, int, int, int, int, int, int) _stretchBlt;
  static late int Function(int, int) _setStretchBltMode;
  static late int Function(int, int, int, int, Pointer<Void>, Pointer<Void>, int) _getDIBits;

  // Win32 Constants
  static const int SM_CXSCREEN = 0;
  static const int SM_CYSCREEN = 1;
  static const int SRCCOPY = 0x00CC0020;
  static const int HALFTONE = 4;
  static const int BI_RGB = 0;
  static const int DIB_RGB_COLORS = 0;

  static const int MOUSEEVENTF_MOVE = 0x0001;
  static const int MOUSEEVENTF_LEFTDOWN = 0x0002;
  static const int MOUSEEVENTF_LEFTUP = 0x0004;
  static const int MOUSEEVENTF_RIGHTDOWN = 0x0008;
  static const int MOUSEEVENTF_RIGHTUP = 0x0010;
  static const int MOUSEEVENTF_MIDDLEDOWN = 0x0020;
  static const int MOUSEEVENTF_MIDDLEUP = 0x0040;
  static const int MOUSEEVENTF_WHEEL = 0x0800;

  static const int KEYEVENTF_KEYUP = 0x0002;

  static void _ensureInit() {
    if (_initialized || !Platform.isWindows) return;
    try {
      _user32 = DynamicLibrary.open('user32.dll');
      _gdi32 = DynamicLibrary.open('gdi32.dll');

      _getDC = _user32!.lookup<NativeFunction<IntPtr Function(IntPtr)>>('GetDC').asFunction();
      _releaseDC = _user32!.lookup<NativeFunction<Int32 Function(IntPtr, IntPtr)>>('ReleaseDC').asFunction();
      _getSystemMetrics = _user32!.lookup<NativeFunction<Int32 Function(Int32)>>('GetSystemMetrics').asFunction();
      _setCursorPos = _user32!.lookup<NativeFunction<Int32 Function(Int32, Int32)>>('SetCursorPos').asFunction();
      _mouseEvent = _user32!.lookup<NativeFunction<Void Function(Uint32, Uint32, Uint32, Uint32, IntPtr)>>('mouse_event').asFunction();
      _keybdEvent = _user32!.lookup<NativeFunction<Void Function(Uint8, Uint8, Uint32, IntPtr)>>('keybd_event').asFunction();

      _createCompatibleDC = _gdi32!.lookup<NativeFunction<IntPtr Function(IntPtr)>>('CreateCompatibleDC').asFunction();
      _deleteDC = _gdi32!.lookup<NativeFunction<Int32 Function(IntPtr)>>('DeleteDC').asFunction();
      _createCompatibleBitmap = _gdi32!.lookup<NativeFunction<IntPtr Function(IntPtr, Int32, Int32)>>('CreateCompatibleBitmap').asFunction();
      _selectObject = _gdi32!.lookup<NativeFunction<IntPtr Function(IntPtr, IntPtr)>>('SelectObject').asFunction();
      _deleteObject = _gdi32!.lookup<NativeFunction<Int32 Function(IntPtr)>>('DeleteObject').asFunction();
      _stretchBlt = _gdi32!.lookup<NativeFunction<Int32 Function(IntPtr, Int32, Int32, Int32, Int32, IntPtr, Int32, Int32, Int32, Int32, Uint32)>>('StretchBlt').asFunction();
      _setStretchBltMode = _gdi32!.lookup<NativeFunction<Int32 Function(IntPtr, Int32)>>('SetStretchBltMode').asFunction();
      _getDIBits = _gdi32!.lookup<NativeFunction<Int32 Function(IntPtr, IntPtr, Uint32, Uint32, Pointer<Void>, Pointer<Void>, Uint32)>>('GetDIBits').asFunction();

      _initialized = true;
    } catch (_) {}
  }

  /// Captures the primary display and downscales to a streaming-friendly 16:9 BMP image.
  static Uint8List? captureFrame() {
    if (!Platform.isWindows) return null;
    _ensureInit();
    if (!_initialized) return null;

    try {
      final screenW = _getSystemMetrics(SM_CXSCREEN);
      final screenH = _getSystemMetrics(SM_CYSCREEN);
      if (screenW <= 0 || screenH <= 0) return null;

      // Scale to max width 960 to maintain 30+ FPS over local network
      final scale = (960.0 / screenW).clamp(0.1, 1.0);
      final targetW = ((screenW * scale) ~/ 4) * 4; // Multiple of 4
      final targetH = (screenH * scale).round();

      final hdcScreen = _getDC(0);
      final hdcMem = _createCompatibleDC(hdcScreen);
      final hbm = _createCompatibleBitmap(hdcScreen, targetW, targetH);
      final oldBm = _selectObject(hdcMem, hbm);

      _setStretchBltMode(hdcMem, HALFTONE);
      _stretchBlt(
        hdcMem, 0, 0, targetW, targetH,
        hdcScreen, 0, 0, screenW, screenH,
        SRCCOPY,
      );

      final rowSize = ((targetW * 32 + 31) ~/ 32) * 4;
      final dataSize = rowSize * targetH;
      final fileSize = 54 + dataSize;

      final bmiPtr = calloc<Uint8>(40);
      final bmiBd = ByteData.view(bmiPtr.asTypedList(40).buffer);
      bmiBd.setUint32(0, 40, Endian.little); // biSize
      bmiBd.setInt32(4, targetW, Endian.little);
      bmiBd.setInt32(8, targetH, Endian.little); // Bottom-up
      bmiBd.setUint16(12, 1, Endian.little); // biPlanes
      bmiBd.setUint16(14, 32, Endian.little); // biBitCount (32-bit BGRA)
      bmiBd.setUint32(16, BI_RGB, Endian.little);
      bmiBd.setUint32(20, dataSize, Endian.little);

      final pixelsPtr = calloc<Uint8>(dataSize);

      _getDIBits(
        hdcMem,
        hbm,
        0,
        targetH,
        pixelsPtr.cast<Void>(),
        bmiPtr.cast<Void>(),
        DIB_RGB_COLORS,
      );

      final bmpBytes = Uint8List(fileSize);
      final bd = ByteData.view(bmpBytes.buffer);

      // BITMAPFILEHEADER (14 bytes)
      bmpBytes[0] = 0x42; // 'B'
      bmpBytes[1] = 0x4D; // 'M'
      bd.setUint32(2, fileSize, Endian.little);
      bd.setUint32(6, 0, Endian.little);
      bd.setUint32(10, 54, Endian.little);

      // BITMAPINFOHEADER (40 bytes)
      bmpBytes.setRange(14, 54, bmiPtr.asTypedList(40));

      // Raw Pixels
      bmpBytes.setRange(54, fileSize, pixelsPtr.asTypedList(dataSize));

      calloc.free(pixelsPtr);
      calloc.free(bmiPtr);

      _selectObject(hdcMem, oldBm);
      _deleteObject(hbm);
      _deleteDC(hdcMem);
      _releaseDC(0, hdcScreen);

      return bmpBytes;
    } catch (_) {
      return null;
    }
  }

  /// Injects simulated mouse or keyboard events received from client phone.
  static void injectInput(Map<String, dynamic> msg) {
    if (!Platform.isWindows) return;
    _ensureInit();
    if (!_initialized) return;

    try {
      final type = msg['type'] as String?;
      if (type == null) return;

      final screenW = _getSystemMetrics(SM_CXSCREEN);
      final screenH = _getSystemMetrics(SM_CYSCREEN);

      switch (type) {
        case 'MouseMove':
          final dx = (msg['dx'] as num?)?.toDouble() ?? 0.0;
          final dy = (msg['dy'] as num?)?.toDouble() ?? 0.0;
          _mouseEvent(MOUSEEVENTF_MOVE, (dx * 1.5).round(), (dy * 1.5).round(), 0, 0);
          break;

        case 'MouseAbsolute':
          final normX = (msg['x'] as num?)?.toDouble() ?? 0.0;
          final normY = (msg['y'] as num?)?.toDouble() ?? 0.0;
          final px = (normX * screenW).clamp(0, screenW - 1).round();
          final py = (normY * screenH).clamp(0, screenH - 1).round();
          _setCursorPos(px, py);
          break;

        case 'MouseButton':
          final button = (msg['button'] as String?)?.toLowerCase() ?? 'left';
          final pressed = msg['pressed'] as bool? ?? true;

          int dwFlags = 0;
          if (button == 'left') {
            dwFlags = pressed ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP;
          } else if (button == 'right') {
            dwFlags = pressed ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP;
          } else if (button == 'middle') {
            dwFlags = pressed ? MOUSEEVENTF_MIDDLEDOWN : MOUSEEVENTF_MIDDLEUP;
          }

          if (dwFlags != 0) {
            _mouseEvent(dwFlags, 0, 0, 0, 0);
          }
          break;

        case 'MouseScroll':
          final dy = (msg['dy'] as num?)?.toDouble() ?? 0.0;
          _mouseEvent(MOUSEEVENTF_WHEEL, 0, 0, (-dy * 120).round(), 0);
          break;

        case 'KeyEvent':
          final key = (msg['key'] as String?)?.toLowerCase() ?? '';
          final pressed = msg['pressed'] as bool? ?? true;
          final vk = _resolveVirtualKey(key);
          if (vk != 0) {
            final flags = pressed ? 0 : KEYEVENTF_KEYUP;
            _keybdEvent(vk, 0, flags, 0);
          }
          break;
      }
    } catch (_) {}
  }

  static int _resolveVirtualKey(String key) {
    switch (key) {
      case 'enter':
      case 'return':
        return 0x0D;
      case 'backspace':
        return 0x08;
      case 'tab':
        return 0x09;
      case 'escape':
      case 'esc':
        return 0x1B;
      case 'space':
        return 0x20;
      case 'delete':
        return 0x2E;
      case 'up':
        return 0x26;
      case 'down':
        return 0x28;
      case 'left':
        return 0x25;
      case 'right':
        return 0x27;
      case 'home':
        return 0x24;
      case 'end':
        return 0x23;
      case 'pageup':
        return 0x21;
      case 'pagedown':
        return 0x22;
      case 'ctrl':
      case 'control':
        return 0x11;
      case 'alt':
        return 0x12;
      case 'shift':
        return 0x10;
      case 'win':
      case 'meta':
        return 0x5B;
      default:
        if (key.length == 1) {
          final code = key.toUpperCase().codeUnitAt(0);
          if ((code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A)) {
            return code;
          }
        }
        return 0;
    }
  }
}
