import 'dart:js_interop';

@JS('AlinBusinessPush.enable')
external JSPromise<JSBoolean> _enable(JSString jwt, JSString key, JSString baseUrl);

@JS('AlinBusinessPush.sync')
external JSPromise<JSBoolean> _sync(JSString jwt, JSString key, JSString baseUrl);

@JS('AlinBusinessPush.disable')
external JSPromise<JSBoolean> _disable(JSString jwt, JSString key, JSString baseUrl);

Future<bool> enableWebPush(String jwt,String key,String baseUrl) async =>
  (await _enable(jwt.toJS,key.toJS,baseUrl.toJS).toDart).toDart;
Future<bool> syncWebPush(String jwt,String key,String baseUrl) async =>
  (await _sync(jwt.toJS,key.toJS,baseUrl.toJS).toDart).toDart;
Future<bool> disableWebPush(String jwt,String key,String baseUrl) async =>
  (await _disable(jwt.toJS,key.toJS,baseUrl.toJS).toDart).toDart;
