// ─────────────────────────────────────────────────────────────────────────────
// OPUS-MT TRANSLATOR — Helsinki-NLP's English ↔ Greek translation models
// (opus-mt-tc-big-en-el and -el-en, CC-BY-4.0), compressed to 8 bits and
// run on the phone with ONNX Runtime. Offline once the models are on the
// phone.
//
// One model per direction, each a folder with: encoder_model.onnx,
// decoder_model_merged.onnx, source.spm, source_vocab.json,
// target_vocab.json, config.json (made by scripts/opus_mt/prune_onnx.py,
// which keeps each side's own vocabulary only, then quantize.py;
// greedy_pruned.py is the same loop in Python).
//
// Text is cleaned and translated one sentence at a time
// (translation_text.dart): the models learned from plain single sentences.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:material_ui/material_ui.dart' show debugPrint;

import 'translation_text.dart';
import 'translator_service.dart';

class OpusMtTranslator implements Translator {
  /// The folder of the model translating [from] into [to] ("en", "el").
  final String Function(String from, String to) folder;

  OpusMtTranslator(this.folder);

  final Map<String, Future<_OpusModel>> _models = {};

  /// The model for [from] → [to]: its own folder, or the other direction's
  /// when that is one multilingual model for both ways (German), which then
  /// takes a language tag. Loaded once per folder.
  Future<_OpusModel> _model(String from, String to) async {
    var dir = folder(from, to);
    if (!await File('$dir/config.json').exists() &&
        await File('${folder(to, from)}/config.json').exists()) {
      dir = folder(to, from);
    }
    return _models[dir] ??= _OpusModel.load(dir);
  }

  static const _files = [
    'encoder_model.onnx',
    'decoder_model_merged.onnx',
    'source.spm',
    'source_vocab.json',
    'target_vocab.json',
    'config.json',
  ];

  /// Whether both directions' files are on the phone.
  @override
  Future<bool> isReady() async {
    for (final (f, t) in const [('en', 'el'), ('el', 'en')]) {
      for (final name in _files) {
        if (!await File('${folder(f, t)}/$name').exists()) return false;
      }
    }
    return true;
  }

  /// Loads both directions, so the first translation doesn't wait.
  @override
  Future<void> prepare() async {
    await _model('en', 'el');
    await _model('el', 'en');
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    if (text.trim().isEmpty || from == to) return text;
    // No direct model between two languages other than English (Spanish ↔
    // Greek): through English.
    if (from != 'en' && to != 'en') {
      final english = await translate(text, from: from, to: 'en');
      return translate(english, from: 'en', to: to);
    }
    final model = await _model(from, to);
    // Cleaned, then one sentence at a time: the way the model learned.
    return translateBySentence(
      text,
      from,
      (sentence) => model.translate(sentence, into: to),
    );
  }

  @override
  Future<void> dispose() async {
    for (final m in _models.values) {
      await (await m).close();
    }
    _models.clear();
  }
}

/// One direction: the tokenizer, the vocabulary and the two ONNX sessions.
class _OpusModel {
  final SentencePieceTokenizer spm;
  final Map<String, int> sourceVocab; // piece -> encoder id
  final List<String> targetPieces; // decoder id -> piece
  final OrtSession encoder, decoder;
  final int start, layers, heads, headSize;

  /// The same three ids on both sides (prune_onnx.py puts them first).
  static const eos = 0, unk = 1, pad = 2;

  _OpusModel(
    this.spm,
    this.sourceVocab,
    this.targetPieces,
    this.encoder,
    this.decoder, {
    required this.start,
    required this.layers,
    required this.heads,
    required this.headSize,
  });

  static Future<Map<String, int>> _vocab(String path) async =>
      (jsonDecode(await File(path).readAsString()) as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      );

  static Future<_OpusModel> load(String dir) async {
    final clock = Stopwatch()..start();
    final config =
        jsonDecode(await File('$dir/config.json').readAsString()) as Map;
    final target = await _vocab('$dir/target_vocab.json');
    final pieces = List.filled(target.length, '');
    target.forEach((piece, id) => pieces[id] = piece);
    final options = OrtSessionOptions(intraOpNumThreads: 4);
    final ort = OnnxRuntime();
    final heads = config['decoder_attention_heads'] as int;
    final model = _OpusModel(
      SentencePieceTokenizer.fromModelFileSync('$dir/source.spm'),
      await _vocab('$dir/source_vocab.json'),
      pieces,
      await ort.createSession('$dir/encoder_model.onnx', options: options),
      await ort.createSession(
        '$dir/decoder_model_merged.onnx',
        options: options,
      ),
      start: config['decoder_start_token_id'] as int,
      layers: config['decoder_layers'] as int,
      heads: heads,
      headSize: (config['d_model'] as int) ~/ heads,
    );
    debugPrint('OPUS-MT: loaded $dir in ${clock.elapsedMilliseconds} ms');
    return model;
  }

  /// Language tags of multilingual models (">>deu<<"), by app code.
  static const _iso3 = {
    'en': 'eng',
    'el': 'ell',
    'es': 'spa',
    'de': 'deu',
    'it': 'ita',
    'fr': 'fra',
    'ru': 'rus',
  };

  /// Text -> encoder ids: SentencePiece pieces looked up in the source
  /// vocabulary, then </s> (what MarianTokenizer does). A multilingual
  /// model (German) first gets the tag of the language to write: >>deu<<.
  List<int> encode(String text, {required String into}) => [
    ?sourceVocab['>>${_iso3[into]}<<'],
    for (final p in spm.encode(text, addSpecialTokens: false).tokens)
      sourceVocab[p] ?? unk,
    eos,
  ];

  /// Decoder ids -> text: the pieces joined, "▁" being a space.
  String decode(List<int> ids) => ids
      .where((id) => id > pad)
      .map((id) => targetPieces[id])
      .join()
      .replaceAll('▁', ' ')
      .trim();

  /// Greedy decoding: the most likely next word each step, reusing the
  /// decoder's cache (past keys and values) from the step before.
  Future<String> translate(
    String text, {
    required String into,
    int maxNew = 128,
  }) async {
    final ids = encode(text, into: into);
    final n = ids.length;
    final owned = <OrtValue>[]; // freed at the end
    Future<OrtValue> value(dynamic data, List<int> shape) async {
      final v = await OrtValue.fromList(data, shape);
      owned.add(v);
      return v;
    }

    try {
      final inputIds = await value(Int64List.fromList(ids), [1, n]);
      final mask = await value(Int64List.fromList(List.filled(n, 1)), [1, n]);
      final encoded = await encoder.run({
        'input_ids': inputIds,
        'attention_mask': mask,
      });
      owned.addAll(encoded.values);
      final hidden = encoded['last_hidden_state']!;

      final empty = await value(Float32List(0), [1, heads, 0, headSize]);
      final past = <String, OrtValue>{
        for (var i = 0; i < layers; i++)
          for (final s in const ['decoder', 'encoder'])
            for (final k in const ['key', 'value'])
              'past_key_values.$i.$s.$k': empty,
      };
      final out = <int>[];
      var token = start;
      for (var step = 0; step < maxNew; step++) {
        final results = await decoder.run({
          'encoder_attention_mask': mask,
          'input_ids': await value(Int64List.fromList([token]), [1, 1]),
          'encoder_hidden_states': hidden,
          'use_cache_branch': await value([step > 0], [1]),
          ...past,
        });
        owned.addAll(results.values);
        final logits = (await results['logits']!.asFlattenedList())
            .cast<double>();
        token = _argmax(logits, skip: pad);
        if (token == eos) break;
        out.add(token);
        for (var i = 0; i < layers; i++) {
          for (final k in const ['key', 'value']) {
            past['past_key_values.$i.decoder.$k'] =
                results['present.$i.decoder.$k']!;
            if (step == 0) {
              past['past_key_values.$i.encoder.$k'] =
                  results['present.$i.encoder.$k']!;
            }
          }
        }
      }
      return decode(out);
    } finally {
      for (final v in owned) {
        await v.dispose();
      }
    }
  }

  /// The most likely id, never [skip] (padding is not a word).
  static int _argmax(List<double> xs, {required int skip}) {
    var best = skip == 0 ? 1 : 0;
    for (var i = best + 1; i < xs.length; i++) {
      if (i != skip && xs[i] > xs[best]) best = i;
    }
    return best;
  }

  Future<void> close() async {
    await encoder.close();
    await decoder.close();
  }
}
