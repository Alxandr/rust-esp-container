FROM debian:buster-slim as builder

# -------------------------------------------------------------------
# Toolchain Version Config
# -------------------------------------------------------------------

# Espressif toolchain
ARG ESP_VERSION="1.22.0-80-g6c4433a-5.2.0"

# esp-idf framework
ARG IDF_VERSION="v4.1"

# rust-xtensa
ARG RUSTC_VERSION="e45940c1d4b03eb3e0761e2304c5238afd591d9f"

# -------------------------------------------------------------------
# Toolchain Path Config
# -------------------------------------------------------------------

ARG TOOLCHAIN="/home/esp32-toolchain"

ARG ESP_BASE="${TOOLCHAIN}/esp"
ENV ESP_PATH "${ESP_BASE}/esp-toolchain"
ENV IDF_PATH "${ESP_BASE}/esp-idf"

ARG LLVM_BASE="${TOOLCHAIN}/llvm"
ARG LLVM_PATH="${LLVM_BASE}/llvm_xtensa"
ARG LLVM_BUILD_PATH="${LLVM_BASE}/llvm_build"
ARG LLVM_INSTALL_PATH="${LLVM_BASE}/llvm_install"

ARG RUSTC_BASE="${TOOLCHAIN}/rustc"
ARG RUSTC_PATH="${RUSTC_BASE}/rust_xtensa"
ARG RUSTC_BUILD_PATH="${RUSTC_BASE}/rust_build"

ENV PATH "/root/.cargo/bin:${ESP_PATH}/bin:${PATH}"

# -------------------------------------------------------------------
# Install expected depdendencies
# -------------------------------------------------------------------

RUN apt-get update \
      && apt-get install -y \
      bison \
      cmake \
      curl \
      flex \
      g++ \
      gcc \
      git \
      gperf \
      libncurses-dev \
      make \
      ninja-build \
      python \
      python-pip \
      wget \
      && rm -rf /var/lib/apt/lists/*

# # -------------------------------------------------------------------
# # Setup esp32 toolchain
# # -------------------------------------------------------------------

# WORKDIR "${ESP_BASE}"
# RUN curl \
#       --proto '=https' \
#       --tlsv1.2 \
#       -sSf \
#       -o "${ESP_PATH}.tar.gz" \
#       "https://dl.espressif.com/dl/xtensa-esp32-elf-linux64-${ESP_VERSION}.tar.gz" \
#       && mkdir "${ESP_PATH}" \
#       && tar -xzf "${ESP_PATH}.tar.gz" -C "${ESP_PATH}" --strip-components 1 \
#       && rm -rf "${ESP_PATH}.tar.gz"

# # -------------------------------------------------------------------
# # Setup esp-idf
# # -------------------------------------------------------------------

# WORKDIR "${ESP_BASE}"
# RUN  git clone \
#       --recursive --single-branch -b "${IDF_VERSION}" \
#       https://github.com/espressif/esp-idf.git \
#       && pip install --user -r "${IDF_PATH}/requirements.txt"

# -------------------------------------------------------------------
# Build rust-xtensa
# -------------------------------------------------------------------

WORKDIR "${RUSTC_BASE}"
RUN git clone \
      --recursive --single-branch \
      https://github.com/MabezDev/rust-xtensa.git \
      "${RUSTC_PATH}" \
      && mkdir -p "${RUSTC_BUILD_PATH}" \
      && cd "${RUSTC_PATH}" \
      && git reset --hard "${RUSTC_VERSION}" \
      && ./configure \
      --prefix "${RUSTC_BUILD_PATH}" \
      && python ./x.py build \
      && python ./x.py install

# -------------------------------------------------------------------
# Setup rustup toolchain
# -------------------------------------------------------------------

RUN curl \
      --proto '=https' \
      --tlsv1.2 \
      -sSf \
      https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable \
      && rustup component add rustfmt \
      && rustup toolchain link xtensa "${RUSTC_BUILD_PATH}" \
      && cargo install cargo-xbuild bindgen

# -------------------------------------------------------------------
# Install expected depdendencies
# -------------------------------------------------------------------

FROM debian:buster-slim

# -------------------------------------------------------------------
# Install expected depdendencies
# -------------------------------------------------------------------

RUN apt-get update \
      && apt-get install -y \
      bison \
      cmake \
      curl \
      flex \
      g++ \
      gcc \
      git \
      gperf \
      libncurses-dev \
      make \
      ninja-build \
      python \
      python-pip \
      wget \
      && rm -rf /var/lib/apt/lists/*

# esptool allows us to convert the ELF binary into an image and flash it to an ESP32
RUN pip3 install esptool

# -------------------------------------------------------------------
# Our Project
# -------------------------------------------------------------------

ENV PROJECT="/home/project/"

ENV XARGO_RUST_SRC="${RUSTC_PATH}/src"
ENV TEMPLATES="${TOOLCHAIN}/templates"
ENV LIBCLANG_PATH="${LLVM_INSTALL_PATH}/lib"
ENV CARGO_HOME="${PROJECT}target/cargo"

VOLUME "${PROJECT}"
WORKDIR "${PROJECT}"

COPY bindgen-project build-project create-project image-project xbuild-project flash-project /usr/local/bin/
COPY templates/ "${TEMPLATES}"

CMD ["/usr/local/bin/build-project"]
