"""Greedy decoding for trimmed OPUS-MT models (prune_onnx.py + quantize.py),
tokenizing like the app: SentencePiece pieces -> source_vocab.json ids.
Usage: greedy_pruned.py <tests.csv> <en-el model dir> <el-en model dir>"""
import csv, json, sys, time, warnings
warnings.filterwarnings('ignore')
import numpy as np, onnxruntime as ort, sentencepiece as sp
class Opus:
    def __init__(self, p):
        o = ort.SessionOptions(); o.intra_op_num_threads = 4
        self.spm = sp.SentencePieceProcessor(model_file=f'{p}/source.spm')
        self.src = json.load(open(f'{p}/source_vocab.json', encoding='utf-8'))
        tgt = json.load(open(f'{p}/target_vocab.json', encoding='utf-8'))
        self.pieces = {i: s for s, i in tgt.items()}
        c = json.load(open(f'{p}/config.json'))
        self.start, self.layers = c['decoder_start_token_id'], c['decoder_layers']
        self.heads = c['decoder_attention_heads']; self.hs = c['d_model'] // self.heads
        self.enc = ort.InferenceSession(f'{p}/encoder_model.onnx', o, providers=['CPUExecutionProvider'])
        self.dec = ort.InferenceSession(f'{p}/decoder_model_merged.onnx', o, providers=['CPUExecutionProvider'])
    def __call__(self, text):
        ids = [self.src.get(x, 1) for x in self.spm.encode(text, out_type=str)] + [0]
        ids = np.array([ids], dtype=np.int64); mask = np.ones_like(ids)
        hidden = self.enc.run(None, {'input_ids': ids, 'attention_mask': mask})[0]
        empty = np.zeros((1, self.heads, 0, self.hs), dtype=np.float32)
        past = {f'past_key_values.{i}.{s}.{k}': empty for i in range(self.layers) for s in ('decoder','encoder') for k in ('key','value')}
        names = [o.name for o in self.dec.get_outputs()]
        tok, out = self.start, []
        for step in range(128):
            res = dict(zip(names, self.dec.run(None, {'encoder_attention_mask': mask, 'input_ids': np.array([[tok]], dtype=np.int64),
                'encoder_hidden_states': hidden, 'use_cache_branch': np.array([step > 0]), **past})))
            logits = res['logits'][0, -1]; logits[2] = -np.inf  # never <pad>
            tok = int(np.argmax(logits))
            if tok == 0: break
            out.append(tok)
            for i in range(self.layers):
                for k in ('key','value'):
                    past[f'past_key_values.{i}.decoder.{k}'] = res[f'present.{i}.decoder.{k}']
                    if step == 0: past[f'past_key_values.{i}.encoder.{k}'] = res[f'present.{i}.encoder.{k}']
        return ''.join(self.pieces[t] for t in out if t > 2).replace('▁', ' ').strip()
m = {'en-el': Opus(sys.argv[2]), 'el-en': Opus(sys.argv[3])}
t0 = time.time()
for r in csv.DictReader(open(sys.argv[1], encoding='utf-8')):
    print('P\t' + r['id'] + '\t' + m[r['from'] + '-' + r['to']](r['text']), flush=True)
print('# %.1fs' % (time.time() - t0), file=sys.stderr)
