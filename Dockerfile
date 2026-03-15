FROM artifacts.mastercard.int/mcr-unstable/codercom/code-server:latest

# Optional: set a specific Python version available in Debian repos (bookworm: 3.11)
# If you need a different version, adjust accordingly.
USER root

# Install Python, pip, and build tools (for packages with native extensions)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv python3-dev \
      build-essential curl git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Make python/pip commands consistent
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Set working directory to coder's home
WORKDIR /home/coder/project

# Copy requirements first to leverage Docker layer caching
# If you don't have requirements, you can skip these two lines.
COPY --chown=coder:coder requirements.txt /home/coder/project/requirements.txt

# Install Python deps (system-wide in the image)
# If you prefer a venv, see note below.
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt; fi

# -----------------------------
# Optional: Preinstall extensions
# Provide space-separated list via build ARG EXTENSIONS
# Example: --build-arg EXTENSIONS="ms-python.python ms-toolsai.jupyter"
# -----------------------------
ARG EXTENSIONS="ms-python.python ms-toolsai.jupyter"
USER coder

# Install VS Code extensions (if any provided)
# this is not working because of SSL shit
RUN if [ -n "$EXTENSIONS" ]; then \
      for ext in $EXTENSIONS; do \
        code-server --install-extension "$ext"; \
      done; \
    fi

# Optional: Default settings.json (merge-safe if file already exists)
# You can bake in commonly-used settings here.
# Uncomment and adjust if needed.
# RUN mkdir -p /home/coder/.local/share/code-server/User && \
#     tee /home/coder/.local/share/code-server/User/settings.json >/dev/null << 'EOF'
# {
#   "python.defaultInterpreterPath": "/usr/bin/python",
#   "python.analysis.autoImportCompletions": true,
#   "terminal.integrated.defaultProfile.linux": "bash",
#   "editor.formatOnSave": true
# }
# EOF

# Ensure proper permissions
USER root
RUN chown -R coder:coder /home/coder
USER coder

# Expose code-server default port
EXPOSE 8080

# Environment:
# - PASSWORD: set to protect the UI
# - HASHED_PASSWORD: alternative (bcrypt)
# - DEFAULT_WORKSPACE: initial folder
ENV DEFAULT_WORKSPACE=/home/coder/project

# Entrypoint is provided by base image; no need to override.
# The base image starts code-server automatically.