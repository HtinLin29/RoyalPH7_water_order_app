library;

import '../services/supabase_error_handler.dart';

String mapAuthError(Object error) => SupabaseErrorHandler.getMessage(error);
