#!/bin/bash

wget -c -O config.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/config.json?download=true
wget -c -O flax_model.msgpack https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/flax_model.msgpack?download=true
wget -c -O merges.txt https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/merges.txt?download=true
wget -c -O model.safetensors https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/model.safetensors?download=true
wget -c -O preprocessor_config.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/preprocessor_config.json?download=true
wget -c -O pytorch_model.bin https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/pytorch_model.bin?download=true
wget -c -O special_tokens_map.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/special_tokens_map.json?download=true
wget -c -O tf_model.h5 https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/tf_model.h5?download=true
wget -c -O tokenizer.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/tokenizer.json?download=true
wget -c -O tokenizer_config.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/tokenizer_config.json?download=true
wget -c -O vocab.json https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/vocab.json?download=true