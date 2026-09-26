FROM debian:bookworm-slim

ARG GODOT_VERSION=4.5.2

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libfontconfig1 \
        libgl1 \
        libpulse0 \
        libx11-6 \
        libxcursor1 \
        libxinerama1 \
        libxi6 \
        libxrandr2 \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /tmp/godot \
    && mv /tmp/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm -rf /tmp/godot /tmp/godot.zip

WORKDIR /app
COPY . .

ENV PORT=10000

CMD ["sh", "-c", "godot --headless --path /app --editor --import --quit && exec godot --headless --path /app -- --server --port=${PORT:-10000} --players=10 --difficulty=1"]
