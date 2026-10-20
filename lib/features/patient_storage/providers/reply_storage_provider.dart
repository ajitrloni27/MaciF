import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/consultation_reply_store.dart';

final consultationReplyStoreProvider = Provider<ConsultationReplyStore>((ref) {
  final store = ConsultationReplyStore();
  ref.onDispose(() {
    store.close();
  });
  return store;
});
