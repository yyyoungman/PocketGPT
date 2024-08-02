# PocketGPT

An ChatGPT-like iOS app that runs Multimodal LLM, Stable Diffusion and Whisper fully on mobile device. [App Store Link](https://apps.apple.com/us/app/pocketgpt-private-ai/id6479569299).

## Credits
This app integrates several open-source projects/models. Great thanks to these awesome projects!

Code:
- Inference engine: [llama.cpp](https://github.com/ggerganov/llama.cpp)([forked](https://github.com/yyyoungman/llamaforked)) for the language and audio models, and [CoreML](https://github.com/apple/ml-stable-diffusion) for the Diffusion model.
- App interface: builds on top of [LLMFarm](https://github.com/guinmoon/LLMFarm).

Models:
- MLLM: [MobileVLM](https://github.com/Meituan-AutoML/MobileVLM), quantized using llama.cpp to 4 bits.
- Diffusion: [SD Turbo](https://huggingface.co/stabilityai/sd-turbo), quantized/palettized using CoreML tools to 8 bits.
- Audio: [Whisper Base](https://github.com/openai/whisper).
