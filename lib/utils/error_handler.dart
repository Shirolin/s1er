import 'dart:async';
import 'package:dio/dio.dart';
import '../services/talker.dart';

/// 将技术异常转换为用户友好消息，同时通过 Talker 记录完整错误细节。
///
/// 设计原则：
/// - 用户看到的：可操作的提示（如"网络连接失败，请检查网络"）
/// - 开发者看到的：完整异常栈（通过 Talker 日志）
String friendlyError(Object error, [String? context, StackTrace? stackTrace]) {
  final label = context != null ? '[$context] ' : '';
  talker.handle(error, stackTrace, '$label 原始错误');

  if (error is DioException) {
    return _mapDioError(error);
  }

  if (error is FormatException) {
    return '数据解析失败，请重试';
  }

  if (error is TimeoutException) {
    return '请求超时，请检查网络后重试';
  }

  return '操作失败，请重试';
}

String _mapDioError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return '连接超时，请检查网络后重试';
    case DioExceptionType.connectionError:
      return '无法连接到服务器，请检查网络';
    case DioExceptionType.badResponse:
      return _mapBadResponse(e.response?.statusCode);
    case DioExceptionType.cancel:
      return '请求已取消';
    case DioExceptionType.unknown:
      if (e.message?.contains('XMLHttpRequest') == true) {
        return '网络请求失败，请检查网络连接';
      }
      return '网络异常，请重试';
    default:
      return '网络异常，请重试';
  }
}

String _mapBadResponse(int? statusCode) {
  if (statusCode == null) return '服务器响应异常';
  switch (statusCode) {
    case 400:
      return '请求格式错误';
    case 401:
    case 403:
      return '登录已过期，请重新登录';
    case 404:
      return '请求的资源不存在';
    case 500:
    case 502:
    case 503:
      return '服务器暂时不可用，请稍后再试';
    default:
      return '服务器响应异常 ($statusCode)';
  }
}
