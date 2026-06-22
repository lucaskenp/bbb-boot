# Boot pelo SD card — BeagleBone Black

Procedimento para gravar o U-Boot no SD card e bootar a BBB a partir dele.

## Pré-requisitos

- SD card acessível no host como `/dev/sdX` (ajustar conforme `lsblk`)
- Arquivos compilados disponíveis (ver `build.sh` ou build via Buildroot)
- WSL2: SD card passado para o Linux via `usbipd attach --wsl --busid <id>`

## Por que dois passos de gravação

O ROM bootloader do AM335x procura o MLO em dois lugares, nesta ordem:

1. **Setores raw** — offset fixo no dispositivo (setor 256 = 0x20000 bytes)
2. **Partição FAT** — arquivo `MLO` na raiz da primeira partição FAT

O boot via FAT sozinho falha em algumas combinações de cartão/ROM porque o parser
FAT do ROM é primitivo e pode não localizar o `MLO` se houver outros arquivos ou
diretórios criados antes dele (ex: `System Volume Information` do Windows).

A abordagem confiável: gravar o MLO nos setores raw **e** manter os arquivos na
FAT. O `u-boot.img` fica apenas na FAT — o SPL compilado com `CONFIG_SPL_FS_FAT=y`
consegue lê-lo de lá após inicializar o DDR3.

## Passo 1 — Particionar e formatar (primeira vez)

```bash
# Substituir /dev/sdX pelo device correto
sudo fdisk /dev/sdX
```

Dentro do `fdisk`:

```
o       nova tabela de partição DOS
n       nova partição
p       primária
1       número 1
Enter   setor inicial padrão (2048)
+128M   tamanho (suficiente para MLO + u-boot.img)
t       mudar tipo
c       FAT32 LBA
a       marcar como bootável
w       gravar e sair
```

```bash
sudo apt install dosfstools
sudo mkfs.vfat -F 32 -n "BOOT" /dev/sdX1
```

## Passo 2 — Copiar arquivos para a partição FAT

```bash
sudo mkdir -p /mnt/sdboot
sudo mount /dev/sdX1 /mnt/sdboot

sudo cp MLO        /mnt/sdboot/MLO
sudo cp u-boot.img /mnt/sdboot/u-boot.img

ls -lah /mnt/sdboot
sync
sudo umount /mnt/sdboot
```

Via Buildroot (`bbb-embedded-linux`), os arquivos ficam em `output_uboot/images/`:

```bash
sudo cp output_uboot/images/MLO        /mnt/sdboot/MLO
sudo cp output_uboot/images/u-boot.img /mnt/sdboot/u-boot.img
```

## Passo 3 — Gravar MLO nos setores raw

```bash
sudo dd if=MLO of=/dev/sdX bs=512 seek=256
sync
```

Este passo escreve o MLO no offset fixo que o ROM bootloader do AM335x verifica
antes de tentar a FAT. Sem ele, o ROM não encontra o SPL e o boot falha
silenciosamente (sem nenhuma saída na serial).

## Atualizar após novo build

Apenas os passos 2 e 3 — sem reformatar:

```bash
sudo mount /dev/sdX1 /mnt/sdboot
sudo cp MLO        /mnt/sdboot/MLO
sudo cp u-boot.img /mnt/sdboot/u-boot.img
sync
sudo umount /mnt/sdboot

sudo dd if=MLO of=/dev/sdX bs=512 seek=256
sync
```

## Boot na BBB

Conectar o adaptador USB-UART (J1) e abrir o terminal serial antes de energizar:

```bash
# No bbb-embedded-linux:
./scripts/serial-connect.sh /dev/ttyUSB0   # Ctrl+A Ctrl+X para sair
```

Sequência de boot:

1. Inserir SD card na BBB
2. Segurar o botão **S2** (próximo ao slot do SD)
3. Conectar mini-USB para energizar
4. Soltar S2 após ~2 segundos

## Saída esperada na serial

```
U-Boot SPL 2023.10 (...)
Trying to boot from MMC1

U-Boot 2023.10 (...)
CPU  : AM335X-GP rev 2.1
Model: TI AM335x BeagleBone Black
DRAM:  512 MiB
...
Hit any key to stop autoboot:  0
=>
```

O prompt `=>` indica que o U-Boot está rodando. Sem kernel no SD, o `distro_bootcmd`
tenta todas as interfaces (MMC, USB, rede) e cai no shell após timeout.

## Pinos da serial (J1)

```
J1.1 = GND          conectar ao GND do adaptador
J1.4 = RX da BBB    conectar ao TX do adaptador (3.3V obrigatório)
J1.5 = TX da BBB    conectar ao RX do adaptador
```

115200 baud, 8N1, sem flow control.
