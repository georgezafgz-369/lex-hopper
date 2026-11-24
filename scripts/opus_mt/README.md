# Offline translator models (OPUS-MT)

The app's offline translator is Helsinki-NLP's OPUS-MT "tc-big", CC-BY-4.0
(the app credits Helsinki-NLP in Settings > Offline translator):
`Helsinki-NLP/opus-mt-tc-big-en-el` (English → Greek) and
`Helsinki-NLP/opus-mt-tc-big-el-en` (Greek → English), made smaller for phones:
each side keeps only its own language's vocabulary, and the weights are
8-bit. About 560 MB for both directions; about 95% right on the test set
(`data/benchmark/`), about 0.23 s per sentence on a Pixel 8.

(Until 2026-11-24 the app used the smaller base models, `opus-mt-en-el` and
`opus-mt-grk-en`, Apache-2.0: about 160 MB, 183/200 right. They were removed
from the Mac and from Hugging Face's history; the same steps make them
again, with `base` in place of `big`.)

The files are made once on a Mac into `.models/` (not in git), then
uploaded to Hugging Face (`<you>/lex-hopper-models`, folder `opus-mt/`),
where the app downloads them from (Settings > Offline translator):

```bash
cd .models
python3 -m venv venv
venv/bin/pip install "torch>=2.6" transformers sentencepiece sacremoses "optimum[onnxruntime]" onnx
# 1. the original models (pinned commits)
#    opus-mt-tc-big-en-el  bb9aa4d8929451dd2396f399f7aa184c788d565b
#    opus-mt-tc-big-el-en  a69108562775c6727edf3540346f9d8900b73634
#    download config.json, generation_config.json, the weights
#    (model.safetensors or pytorch_model.bin), source.spm, target.spm,
#    tokenizer_config.json, vocab.json into .models/<name>
# 2. to ONNX
venv/bin/optimum-cli export onnx -m opus-mt-tc-big-en-el --task text2text-generation-with-past onnx-en-el
venv/bin/optimum-cli export onnx -m opus-mt-tc-big-el-en --task text2text-generation-with-past onnx-el-en
# 3. keep each side's vocabulary only, then 8-bit
venv/bin/python ../scripts/opus_mt/prune_onnx.py onnx-en-el pruned-big-en-el
venv/bin/python ../scripts/opus_mt/prune_onnx.py onnx-el-en pruned-big-el-en
venv/bin/python ../scripts/opus_mt/quantize.py pruned-big-en-el pruned-big-el-en
# 4. check them on the test set (the same loop as lib/opus_mt_translator.dart)
venv/bin/python ../scripts/opus_mt/greedy_pruned.py ../data/benchmark/translator_test_2.csv pruned-big-en-el-int8 pruned-big-el-en-int8
cd ..
# 5. upload to Hugging Face and point the app at it (assets/opus-mt/manifest.json)
.models/venv/bin/python scripts/opus_mt/upload_to_hf.py
```
