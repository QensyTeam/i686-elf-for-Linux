#!/bin/bash

# Прерывание выполнения скрипта при ошибке
set -e

# Определение количества ядер процессора для параллельной сборки
NUM_CORES=$(nproc)

# Директории для исходников и установки
SRC_DIR=$HOME/src
CROSS_DIR=$HOME/opt/cross

# Переменные для версий GCC и binutils
BINUTILS_VERSION="2.42"
GCC_VERSION="13.2.0"

# Функция для установки пакетов
install_packages() {
    echo "Установка необходимых пакетов..."
    sudo apt update
    sudo apt install -y build-essential bison flex libgmp3-dev libmpc-dev libmpfr-dev texinfo wget mtools xorriso qemu-system grub-pc-bin dosfstools
}

# Функция для удаления установленных файлов и директорий
cleanup() {
    echo "Удаление исходных кодов, сборочных директорий и установленных файлов..."
    rm -rf $SRC_DIR
    rm -rf $CROSS_DIR
    echo "Очистка завершена."
}

# Функция для сборки и установки binutils
install_binutils() {
    echo "Скачивание и разархивирование binutils $BINUTILS_VERSION..."
    cd $SRC_DIR
    wget "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz"
    tar -xvf "binutils-$BINUTILS_VERSION.tar.gz"
    
    echo "Сборка и установка binutils..."
    mkdir -p $SRC_DIR/build-binutils
    cd $SRC_DIR/build-binutils
    $SRC_DIR/binutils-$BINUTILS_VERSION/configure --target=i686-elf --prefix=$CROSS_DIR --with-sysroot --disable-nls --disable-werror
    make -j$NUM_CORES
    make install
}

# Функция для сборки и установки GCC
install_gcc() {
    echo "Скачивание и разархивирование gcc $GCC_VERSION..."
    cd $SRC_DIR
    wget "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz"
    tar -xvf "gcc-$GCC_VERSION.tar.gz"
    
    echo "Сборка и установка GCC..."
    cd $SRC_DIR/gcc-$GCC_VERSION
    ./contrib/download_prerequisites

    mkdir -p $SRC_DIR/build-gcc
    cd $SRC_DIR/build-gcc
    $SRC_DIR/gcc-$GCC_VERSION/configure --target=i686-elf --prefix=$CROSS_DIR --disable-nls --enable-languages=c,c++ --without-headers
    make -j$NUM_CORES all-gcc
    make -j$NUM_CORES all-target-libgcc
    make install-gcc
    make install-target-libgcc
}

# Функция для настройки окружения
setup_environment() {
    echo "Настройка окружения..."
    if ! grep -q "$CROSS_DIR/bin" ~/.bashrc; then
        echo 'export PREFIX="$HOME/opt/cross"' >> ~/.bashrc
        echo 'export TARGET=i686-elf' >> ~/.bashrc
        echo 'export PATH="$PREFIX/bin:$PATH"' >> ~/.bashrc
        source ~/.bashrc
    fi
}

# Функция для проверки установки
check_installation() {
    echo "Проверка установки..."
    i686-elf-gcc --version
    echo "GCC Cross Compiler для i686-elf успешно установлен."
}

# Меню выбора действия
echo "Выберите действие:"
echo "1) Установить компилятор"
echo "2) Удалить компилятор"
echo "3) Удалить архивы и мусор"
echo "4) Переустановить компилятор"
echo "5) Выход"
read -p "Введите номер действия: " action

case $action in
    1)
        # Установка компилятора
        read -p "Введите версию binutils (по умолчанию $BINUTILS_VERSION): " user_binutils_version
        read -p "Введите версию GCC (по умолчанию $GCC_VERSION): " user_gcc_version
        
        # Если версия была введена, используем её
        BINUTILS_VERSION=${user_binutils_version:-$BINUTILS_VERSION}
        GCC_VERSION=${user_gcc_version:-$GCC_VERSION}

        # Установка
        install_packages
        mkdir -p $SRC_DIR
        mkdir -p $CROSS_DIR
        install_binutils
        install_gcc
        setup_environment
        check_installation
        ;;
    2)
        # Удалить компилятор
        cleanup
        ;;
    3)
        # Удалить архивы и мусор
        echo "Удаление архивов..."
        rm -rf $SRC_DIR/*.tar.gz
        echo "Удаление мусора..."
        rm -rf $SRC_DIR
        rm -rf $CROSS_DIR
        ;;
    4)
        # Переустановка компилятора
        cleanup
        install_packages
        mkdir -p $SRC_DIR
        mkdir -p $CROSS_DIR
        install_binutils
        install_gcc
        setup_environment
        check_installation
        ;;
    5)
        # Выход
        echo "Выход из скрипта."
        exit 0
        ;;
    *)
        echo "Некорректный выбор. Выход."
        exit 1
        ;;
esac
