import sys, os
from onnxruntime.quantization import quantize_dynamic, QuantType
for d in sys.argv[1:]:
    out = f'{d}-int8'; os.makedirs(out, exist_ok=True)
    for m in ['encoder_model', 'decoder_model_merged']:
        quantize_dynamic(f'{d}/{m}.onnx', f'{out}/{m}.onnx', weight_type=QuantType.QInt8, extra_options={'EnableSubgraph': True})
    for f in ['config.json','source.spm','target.spm','vocab.json','source_vocab.json','target_vocab.json']:
        os.path.exists(f'{d}/{f}') and os.system(f'cp {d}/{f} {out}/')
