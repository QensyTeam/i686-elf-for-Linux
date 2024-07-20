#!/bin/bash

# Прерывание выполнения скрипта при ошибке
set -e

# Директории для исходников и установки
echo "Создание рабочих директорий и установка пакетов необходимых для сборки"

SRC_DIR=$HOME/src
CROSS_DIR=$HOME/opt/cross

# Пакеты, необходимые для сборки
sudo apt update
sudo apt install -y build-essential bison flex libgmp3-dev libmpc-dev libmpfr-dev texinfo wget mtools xorriso qemu-system

# Создание рабочих директорий
mkdir -p $SRC_DIR
mkdir -p $CROSS_DIR

# Загрузка исходных кодов binutils и gcc
echo "Скачивание и разархивирование необходимых архивов таких как gcc 13.2.0 и binutils 2.42"
cd $SRC_DIR
wget https://ftp.gnu.org/gnu/binutils/binutils-2.42.tar.gz
wget https://ftp.gnu.org/gnu/gcc/gcc-13.2.0/gcc-13.2.0.tar.gz
tar -xvf binutils-2.42.tar.gz
tar -xvf gcc-13.2.0.tar.gz

# Сборка и установка binutils
echo "Сборка и установка binutils"
mkdir -p $SRC_DIR/build-binutils
cd $SRC_DIR/build-binutils
$SRC_DIR/binutils-2.42/configure --target=i686-elf --prefix=$CROSS_DIR --with-sysroot --disable-nls --disable-werror
make
make install

# Сборка и установка GCC
echo "Сборка и установка GCC"
cd $SRC_DIR/gcc-13.2.0
./contrib/download_prerequisites

mkdir -p $SRC_DIR/build-gcc
cd $SRC_DIR/build-gcc
$SRC_DIR/gcc-13.2.0/configure --target=i686-elf --prefix=$CROSS_DIR --disable-nls --enable-languages=c,c++ --without-headers
make all-gcc
make all-target-libgcc
make install-gcc
make install-target-libgcc

# Настройка окружения
echo "Настройка окружения"
if ! grep -q "$CROSS_DIR/bin" ~/.bashrc; then
    echo 'export PREFIX="$HOME/opt/cross"' >> ~/.bashrc
    source ~/.bashrc
    echo 'export TARGET=i686-elf' >> ~/.bashrc
    source ~/.bashrc
    echo 'export PATH="$PREFIX/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
fi

# Проверка установки
echo "Проверка установки"
i686-elf-gcc --version

echo "GCC Cross Compiler для i686-elf успешно установлен."
