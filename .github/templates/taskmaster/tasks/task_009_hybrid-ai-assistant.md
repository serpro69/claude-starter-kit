# Task ID: 9

**Title:** Mac Pro Ollama Setup with ROCm

**Status:** pending

**Dependencies:** None

**Priority:** high

**Description:** Install Ollama on Pop!_OS configured for the AMD Radeon Pro W6900X and pull all required models.

**Details:**

Install Ollama via official Linux installer. Create /etc/systemd/system/ollama.service.d/override.conf with Environment directives: HSA_OVERRIDE_GFX_VERSION=10.3.0 (navi21/W6900X gfx1030) and ROCR_VISIBLE_DEVICES=0. Enable and start ollama.service. Pull models: llama3:70b, llama3:8b, nomic-embed-text, mxbai-embed-large. Verify GPU use during llama3:70b inference via rocm-smi showing >0% GPU utilisation and ~35GB VRAM allocated. Document expected VRAM per model in README.

**Test Strategy:**

ollama run llama3:70b hello responds in under 30s. rocm-smi shows GPU memory during inference. nomic-embed-text returns embedding vector. All 4 models in ollama list. After system reboot, ollama.service active without manual start.
