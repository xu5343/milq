#!/bin/bash
#适用于 Debian 11 / 12 系统
set -e

INSTALL_PREFIX="/usr/local"
CURRENT_VERSION_FILE="/usr/local/opencv_version_installed"

install_dependencies() {
    sudo apt update
    sudo apt install -y \
    build-essential cmake git pkg-config unzip wget \
    libjpeg-dev libpng-dev libtiff-dev \
    libavcodec-dev libavformat-dev libswscale-dev \
    libv4l-dev libxvidcore-dev libx264-dev \
    libgtk-3-dev \
    libatlas-base-dev gfortran \
    python3-dev python3-pip

    echo "Fixing NumPy version..."
    pip3 uninstall -y numpy || true
    pip3 install numpy==1.26.4
}

uninstall_all() {
    echo "Removing previous OpenCV..."

    sudo rm -rf /usr/local/include/opencv4
    sudo rm -rf /usr/local/lib/libopencv*
    sudo rm -rf /usr/local/lib/cmake/opencv4
    sudo rm -rf /usr/local/bin/opencv_*
    sudo rm -rf /usr/local/share/opencv4
    sudo rm -f /usr/local/lib/python3*/dist-packages/cv2*.so
    sudo ldconfig

    rm -f $CURRENT_VERSION_FILE

    echo "✅ Old OpenCV removed"
}

install_opencv() {
    VERSION=$1

    echo "Installing OpenCV $VERSION"

    uninstall_all
    install_dependencies

    rm -rf opencv opencv_contrib *.zip

    wget -O opencv.zip https://github.com/opencv/opencv/archive/${VERSION}.zip
    wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/${VERSION}.zip

    unzip opencv.zip
    unzip opencv_contrib.zip

    mv opencv-${VERSION} opencv
    mv opencv_contrib-${VERSION} opencv_contrib

    cd opencv
    mkdir build && cd build

    PY_EXEC=$(which python3)
    PY_INCLUDE=$(python3 -c "from sysconfig import get_paths; print(get_paths()['include'])")
    PY_SITE=$(python3 -c "import site; print(site.getsitepackages()[0])")

    cmake .. \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
    -D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules \
    -D OPENCV_ENABLE_NONFREE=ON \
    -D BUILD_opencv_python3=ON \
    -D BUILD_opencv_python2=OFF \
    -D PYTHON3_EXECUTABLE=${PY_EXEC} \
    -D PYTHON3_INCLUDE_DIR=${PY_INCLUDE} \
    -D PYTHON3_PACKAGES_PATH=${PY_SITE} \
    -D BUILD_TESTS=OFF \
    -D BUILD_EXAMPLES=OFF

    make -j$(nproc)
    sudo make install
    sudo ldconfig

    cd ../..
    rm -rf opencv opencv_contrib *.zip

    echo $VERSION > $CURRENT_VERSION_FILE

    echo "Testing Python binding..."

    python3 - <<EOF
import cv2
print("✅ OpenCV Version:", cv2.__version__)
EOF

    echo "✅ Installation completed successfully."
}

show_version() {
    if [ -f $CURRENT_VERSION_FILE ]; then
        echo "Installed OpenCV version: $(cat $CURRENT_VERSION_FILE)"
        python3 -c "import cv2; print('Python binding:', cv2.__version__)"
    else
        echo "未安装 OpenCV."
    fi
}

# =====================
# MENU
# =====================

while true; do
    echo ""
    echo "====== OpenCV Manager ======"
    echo "1) 安装 4.5.1"
    echo "2) 安装 4.8.1"
    echo "3) 卸载"
    echo "4) 重装当前版本"
    echo "5) 查看当前版本"
    echo "6) 退出"
    echo "============================"
    read -p "Select option: " choice

    case $choice in
        1)
            install_opencv 4.5.1
            ;;
        2)
            install_opencv 4.8.1
            ;;
        3)
            uninstall_all
            ;;
        4)
            if [ -f $CURRENT_VERSION_FILE ]; then
                VERSION=$(cat $CURRENT_VERSION_FILE)
                install_opencv $VERSION
            else
                echo "No version installed."
            fi
            ;;
        5)
            show_version
            ;;
        6)
            exit 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
done
