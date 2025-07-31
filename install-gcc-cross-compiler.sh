#!/bin/bash

# Цвета для вывода
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Прерывание выполнения скрипта при ошибке
set -e

# Директории для исходников и установки
SRC_DIR=$HOME/src
CROSS_DIR=$HOME/opt/cross

# Переменные для версий GCC и binutils
BINUTILS_VERSION="2.42"
GCC_VERSION="13.2.0"

# Функция для вывода предупреждения
warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Функция для вывода успешного сообщения
success() {
    echo -e "${GREEN}$1${NC}"
}

# Функция для информационного сообщения
info() {
    echo -e "${BLUE}$1${NC}"
}

# Функция для проверки текущих версий
check_current_versions() {
    echo -e "\nТекущие версии в системе:"
    
    # Проверка binutils
    if command -v ld &> /dev/null; then
        echo -n "binutils: "
        ld --version | head -n1 | cut -d' ' -f7
    else
        warning "binutils не установлен"
    fi
    
    # Проверка GCC
    if command -v gcc &> /dev/null; then
        echo -n "gcc: "
        gcc --version | head -n1 | cut -d' ' -f4
    else
        warning "gcc не установлен"
    fi
    
    # Рекомендации по версиям
    echo -e "\nРекомендации по версиям:"
    info "Для большинства систем лучше использовать:"
    info "- binutils: 2.35-2.42 (стабильные версии)"
    info "- gcc: 10.3.0-13.2.0 (проверенные версии)"
    info "Для новых процессоров (AMD Zen 3/4, Intel Alder Lake и новее):"
    info "- binutils: 2.40 или новее"
    info "- gcc: 12.1.0 или новее"
    warning "\nНе используйте слишком старые версии (binutils < 2.34, gcc < 9.0.0)"
    warning "и слишком новые (нестабильные) версии для кросс-компиляции!"
}

# Функция для определения количества ядер и потоков
show_cpu_info() {
    local cores=$(nproc --all)
    local threads=$(grep -c ^processor /proc/cpuinfo)
    echo "Информация о процессоре:"
    echo "Физические ядра: $cores"
    echo "Логические потоки: $threads"
    warning "Если вы используете все ядра/потоки, процессор будет загружен на 100%!"
    echo ""
}

# Функция для определения дистрибутива
get_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# Функция для установки пакетов
install_packages() {
    local distro=$(get_distro)
    echo "Установка необходимых пакетов для $distro..."
    
    case $distro in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y build-essential bison flex libgmp3-dev libmpc-dev libmpfr-dev \
                               texinfo wget mtools xorriso qemu-system grub-pc-bin dosfstools nasm
            ;;
        arch|manjaro)
            sudo pacman -Sy --noconfirm base-devel bison flex gmp libmpc mpfr texinfo \
                                      wget mtools xorriso qemu grub dosfstools nasm
            ;;
        fedora|centos|rhel)
            sudo dnf install -y gcc gcc-c++ make bison flex gmp-devel libmpc-devel \
                               mpfr-devel texinfo wget mtools xorriso qemu grub2 dosfstools nasm
            ;;
        *)
            echo "Неизвестный дистрибутив. Установите зависимости вручную."
            warning "Обязательные пакеты: build-essential, bison, flex, libgmp3-dev, libmpc-dev,"
            warning "libmpfr-dev, texinfo, wget, mtools, xorriso, qemu, grub, dosfstools, nasm"
            exit 1
            ;;
    esac
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
    local target=$1
    echo "Скачивание и разархивирование binutils $BINUTILS_VERSION..."
    cd $SRC_DIR
    if [ ! -f "binutils-$BINUTILS_VERSION.tar.gz" ]; then
        wget "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz" -O "binutils-$BINUTILS_VERSION.tar.gz"
    fi
    tar -xzf "binutils-$BINUTILS_VERSION.tar.gz"
    
    echo "Сборка и установка binutils для $target..."
    mkdir -p $SRC_DIR/build-binutils-$target
    cd $SRC_DIR/build-binutils-$target
    $SRC_DIR/binutils-$BINUTILS_VERSION/configure --target=$target --prefix=$CROSS_DIR --with-sysroot --disable-nls --disable-werror
    make -j$NUM_CORES
    make install
}

# Функция для сборки и установки GCC
install_gcc() {
    local target=$1
    echo "Скачивание и разархивирование gcc $GCC_VERSION..."
    cd $SRC_DIR
    if [ ! -f "gcc-$GCC_VERSION.tar.gz" ]; then
        wget "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz" -O "gcc-$GCC_VERSION.tar.gz"
    fi
    tar -xzf "gcc-$GCC_VERSION.tar.gz"
    
    echo "Сборка и установка GCC для $target..."
    cd $SRC_DIR/gcc-$GCC_VERSION
    ./contrib/download_prerequisites

    mkdir -p $SRC_DIR/build-gcc-$target
    cd $SRC_DIR/build-gcc-$target
    $SRC_DIR/gcc-$GCC_VERSION/configure --target=$target --prefix=$CROSS_DIR --disable-nls --enable-languages=c,c++ --without-headers
    make -j$NUM_CORES all-gcc
    make -j$NUM_CORES all-target-libgcc
    make install-gcc
    make install-target-libgcc
}

# Функция для настройки окружения
setup_environment() {
    echo "Настройка окружения..."
    if ! grep -q "$CROSS_DIR/bin" ~/.bashrc; then
        echo "export CROSS_COMPILER_DIR=\"$HOME/opt/cross\"" >> ~/.bashrc
        echo 'export PATH="$CROSS_COMPILER_DIR/bin:$PATH"' >> ~/.bashrc
    fi
}

# Функция для проверки установки
check_installation() {
    local target=$1
    echo "Проверка установки для $target..."
    if ! command -v ${target}-gcc &> /dev/null; then
        warning "Компилятор ${target}-gcc не найден в PATH!"
    else
        ${target}-gcc --version
        success "GCC Cross Compiler для $target успешно установлен."
    fi
    
    warning "\nДля корректной работы компилятора требуется:"
    warning "1. Либо перезапустить текущий терминал"
    warning "2. Либо выполнить команду: source ~/.bashrc"
    warning "3. Либо перезагрузить компьютер"
    echo ""
    info "После этого проверьте работу компилятора командой:"
    info "${target}-gcc --version"
}

# Функция для установки компилятора
install_compiler() {
    local target=$1
    install_packages
    mkdir -p $SRC_DIR
    mkdir -p $CROSS_DIR
    install_binutils $target
    install_gcc $target
    setup_environment
    check_installation $target
}

# Функция для выбора количества ядер
select_cores() {
    show_cpu_info
    local max_cores=$(nproc --all)
    read -p "Введите количество ядер для сборки (до $max_cores, по умолчанию все): " cores_input
    
    if [ -z "$cores_input" ]; then
        NUM_CORES=$max_cores
        warning "Будет использовано ВСЕ ядер/потоков ($NUM_CORES)! Процессор будет загружен на 100%!"
    else
        if [[ $cores_input =~ ^[0-9]+$ ]] && [ $cores_input -gt 0 ] && [ $cores_input -le $max_cores ]; then
            NUM_CORES=$cores_input
            success "Будет использовано $NUM_CORES ядер/потоков."
        else
            warning "Некорректный ввод. Будет использовано 1 ядро."
            NUM_CORES=1
        fi
    fi
}

# Функция для выбора версий
select_versions() {
    check_current_versions
    
    read -p "Введите версию binutils (по умолчанию $BINUTILS_VERSION): " user_binutils_version
    read -p "Введите версию GCC (по умолчанию $GCC_VERSION): " user_gcc_version
    
    # Если версия была введена, используем её
    BINUTILS_VERSION=${user_binutils_version:-$BINUTILS_VERSION}
    GCC_VERSION=${user_gcc_version:-$GCC_VERSION}
    
    info "Будут использованы следующие версии:"
    info "binutils: $BINUTILS_VERSION"
    info "gcc: $GCC_VERSION"
    
    # Проверка на слишком старые версии
    local binutils_major=$(echo $BINUTILS_VERSION | cut -d. -f1)
    local binutils_minor=$(echo $BINUTILS_VERSION | cut -d. -f2)
    if [ $binutils_major -lt 2 ] || ([ $binutils_major -eq 2 ] && [ $binutils_minor -lt 34 ]); then
        warning "Вы используете очень старую версию binutils ($BINUTILS_VERSION)!"
        warning "Рекомендуется использовать версию 2.35 или новее."
    fi
    
    local gcc_major=$(echo $GCC_VERSION | cut -d. -f1)
    if [ $gcc_major -lt 9 ]; then
        warning "Вы используете очень старую версию GCC ($GCC_VERSION)!"
        warning "Рекомендуется использовать версию 10.3.0 или новее."
    fi
}

# Функция для выбора архитектуры
select_architecture() {
    echo "Выберите архитектуру:"
    echo "1) i686-elf (32-bit)"
    echo "2) x86_64-elf (64-bit)"
    echo "3) Обе архитектуры"
    read -p "Введите номер выбора: " arch_choice

    case $arch_choice in
        1) 
            install_compiler "i686-elf"
            ;;
        2)
            install_compiler "x86_64-elf"
            ;;
        3)
            install_compiler "i686-elf"
            install_compiler "x86_64-elf"
            ;;
        *)
            echo "Некорректный выбор. Используется i686-elf по умолчанию."
            install_compiler "i686-elf"
            ;;
    esac
}

# Главное меню
main_menu() {
    echo "Выберите действие:"
    echo "1) Установить компилятор"
    echo "2) Удалить компилятор"
    echo "3) Удалить архивы и мусор"
    echo "4) Переустановить компилятор"
    echo "5) Проверить текущие версии"
    echo "6) Выход"
    read -p "Введите номер действия: " action

    case $action in
        1)
            # Установка компилятора
            select_versions
            select_cores
            select_architecture
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
            ;;
        4)
            # Переустановка компилятора
            cleanup
            select_versions
            select_cores
            select_architecture
            ;;
        5)
            # Проверить текущие версии
            check_current_versions
            main_menu
            ;;
        6)
            # Выход
            echo "Выход из скрипта."
            exit 0
            ;;
        *)
            echo "Некорректный выбор. Выход."
            exit 1
            ;;
    esac
}

# Запуск главного меню
main_menu
