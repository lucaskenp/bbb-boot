#!/bin/bash
# Build U-Boot para BeagleBone Black (AM335x)
#
# Uso standalone (fora do Buildroot):
#   ./build.sh
#   ./build.sh menuconfig
#   ./build.sh clean
#
# Dentro do container Docker (bbb-embedded-linux):
#   O Buildroot usa UBOOT_OVERRIDE_SRCDIR e chama make diretamente.
#   Este script é apenas para desenvolvimento/debug isolado.
#
# Cross compiler necessário:
#   sudo apt install gcc-arm-linux-gnueabihf  (Ubuntu/Debian)
#   OU usar o toolchain do Buildroot após um build:
#     export CROSS_COMPILE=/workspace/project/output_uboot/host/bin/arm-buildroot-linux-gnueabi-

set -e

ARCH=arm
DEFCONFIG=am335x_evm_defconfig
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabihf-}"
JOBS="${JOBS:-$(nproc)}"

# Verificar cross compiler
if ! command -v "${CROSS_COMPILE}gcc" &>/dev/null; then
    echo "ERRO: cross compiler não encontrado: ${CROSS_COMPILE}gcc"
    echo ""
    echo "Instale com:"
    echo "  sudo apt install gcc-arm-linux-gnueabihf"
    echo ""
    echo "Ou use o toolchain do Buildroot:"
    echo "  export CROSS_COMPILE=/workspace/project/output_uboot/host/bin/arm-buildroot-linux-gnueabi-"
    exit 1
fi

export ARCH CROSS_COMPILE

case "${1:-build}" in
    build)
        echo "==> Configurando com $DEFCONFIG..."
        make "$DEFCONFIG"
        echo "==> Compilando com $JOBS jobs..."
        make -j"$JOBS"
        echo ""
        echo "==> Artefatos gerados:"
        ls -lh MLO u-boot.img 2>/dev/null || true
        ;;
    menuconfig)
        make "$DEFCONFIG"
        make menuconfig
        ;;
    clean)
        make distclean
        ;;
    *)
        echo "Uso: $0 [build|menuconfig|clean]"
        exit 1
        ;;
esac
