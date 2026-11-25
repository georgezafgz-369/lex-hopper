"""Shrinks exported OPUS-MT ONNX models (fp32, before quantize.py): the
encoder keeps only the vocabulary rows its source tokenizer can produce,
the decoder (input table, output layer, output bias) only the target
tokenizer's. Writes the models plus source_vocab.json / target_vocab.json
(piece -> new id; </s>, <unk>, <pad> are 0, 1, 2 on both sides) and a
config.json with the new start/end ids.
Usage: prune_onnx.py <onnx dir> <out dir>"""
import json, os, shutil, sys
import numpy as np, onnx, sentencepiece as sp
from onnx import numpy_helper
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
vocab = json.load(open(f'{src}/vocab.json', encoding='utf-8'))
V = len(vocab)
specials = ['</s>', '<unk>', '<pad>']
def keep(spm, tags=False):
    s = sp.SentencePieceProcessor(model_file=f'{src}/{spm}')
    first = [vocab[p] for p in specials]
    rest = {vocab[s.id_to_piece(i)] for i in range(s.get_piece_size()) if s.id_to_piece(i) in vocab}
    # Multilingual models pick the output language with a tag such as
    # >>deu<< in front of the text: the encoder keeps those too.
    if tags:
        rest |= {i for p, i in vocab.items() if p.startswith('>>') and p.endswith('<<')}
    return first + sorted(rest - set(first))
src_ids, tgt_ids = keep('source.spm', tags=True), keep('target.spm')
inv = {i: p for p, i in vocab.items()}

def graphs(g):
    yield g
    for n in g.node:
        for a in n.attribute:
            if a.HasField('g'): yield from graphs(a.g)
            for sg in a.graphs: yield from graphs(sg)

def shrink(path, ids):
    m = onnx.load(path)
    done = []
    for g in graphs(m.graph):
        for t in g.initializer:
            dims = list(t.dims)
            if V not in dims: continue
            a = numpy_helper.to_array(t)
            b = np.take(a, ids, axis=dims.index(V))
            t.CopyFrom(numpy_helper.from_array(b, t.name))
            done.append((dims, list(b.shape)))
        for vi in list(g.output) + list(g.value_info):
            for d in vi.type.tensor_type.shape.dim:
                if d.HasField('dim_value') and d.dim_value == V: d.dim_value = len(ids)
    onnx.save(m, f'{out}/{os.path.basename(path)}')
    return done

print('encoder', shrink(f'{src}/encoder_model.onnx', src_ids))
print('decoder', shrink(f'{src}/decoder_model_merged.onnx', tgt_ids))
json.dump({inv[i]: n for n, i in enumerate(src_ids)}, open(f'{out}/source_vocab.json', 'w', encoding='utf-8'), ensure_ascii=False)
json.dump({inv[i]: n for n, i in enumerate(tgt_ids)}, open(f'{out}/target_vocab.json', 'w', encoding='utf-8'), ensure_ascii=False)
c = json.load(open(f'{src}/config.json'))
c.update(decoder_start_token_id=tgt_ids.index(c['decoder_start_token_id']), eos_token_id=0, pad_token_id=2, vocab_size=len(src_ids), decoder_vocab_size=len(tgt_ids))
json.dump(c, open(f'{out}/config.json', 'w'), indent=1)
for f in ['source.spm', 'target.spm']: shutil.copy(f'{src}/{f}', out)
print(out, 'vocab', V, '-> source', len(src_ids), 'target', len(tgt_ids), 'start', c['decoder_start_token_id'])
