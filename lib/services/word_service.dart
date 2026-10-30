import 'buddy_store.dart';
class WordService {
  // Dictionary lookup only; never applied to OCR or reader content.
  static String clean(String word)=>word.replaceAll(RegExp(r'^[^\p{L}\p{M}\p{N}]+|[^\p{L}\p{M}\p{N}]+$',unicode:true),'');
  static Future<SavedWord> lookup(String word,String language)async{
    for(final entry in BuddyStore.words){
      if(entry.language==language&&entry.word.toLowerCase()==clean(word).toLowerCase())return entry;
    }
    throw const FormatException('No saved meaning for this word. You can add your own meaning.');
  }
}
