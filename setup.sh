#!/bin/bash
set -e

echo "============================================"
echo " Drone Simulation - Full Setup Script"
echo " This will take 20-30 minutes"
echo "============================================"

# 1. System update
echo "[1/8] Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
    git curl wget nano tmux python3-pip ccache \
    build-essential cmake \
    libboost-all-dev liblog4cxx-dev libcairo2-dev \
    libapr1-dev libaprutil1-dev \
    x11-xserver-utils

# 2. ROS 2 Humble
echo "[2/8] Installing ROS 2 Humble..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository universe -y
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
    http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
    | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt-get update
sudo apt-get install -y \
    ros-humble-ros-base \
    ros-humble-rmw-fastrtps-cpp \
    python3-colcon-common-extensions \
    python3-rosdep
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
source /opt/ros/humble/setup.bash

# 3. MicroXRCEAgent
echo "[3/8] Installing MicroXRCEAgent..."
pip3 install pyserial
git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git ~/MicroXRCEAgent
cd ~/MicroXRCEAgent && mkdir -p build && cd build
cmake .. && make -j$(nproc) && sudo make install && sudo ldconfig
cd ~

# 4. PX4-Autopilot
echo "[4/8] Cloning PX4-Autopilot v1.15.4..."
git clone --branch v1.15.4 --depth 1 \
    https://github.com/PX4/PX4-Autopilot.git ~/PX4-Autopilot \
    --recurse-submodules
cd ~/PX4-Autopilot
bash Tools/setup/ubuntu.sh --no-nuttx
cd ~

# 5. Gazebo
echo "[5/8] Installing Gazebo..."
sudo apt-get install -y gazebo ros-humble-gazebo-ros-pkgs

# 6. px4_ws
echo "[6/8] Building px4_ws..."
mkdir -p ~/px4_ws/src
cd ~/px4_ws/src
git clone --branch release/1.15 https://github.com/PX4/px4_msgs.git
git clone https://github.com/Jaeyoung-Lim/px4-offboard.git px4_offboard
cd ~/px4_ws
source /opt/ros/humble/setup.bash
colcon build --symlink-install
echo "source ~/px4_ws/install/setup.bash" >> ~/.bashrc

# 7. QGroundControl
echo "[7/8] Downloading QGroundControl..."
mkdir -p ~/ros2_ws
wget -O ~/ros2_ws/QGroundControl.AppImage https://github.com/mavlink/qgroundcontrol/releases/download/v4.3.0/QGroundControl.AppImage

# 8. Flight scripts
echo "[8/8] Downloading flight scripts..."
mkdir -p ~/ros2_ws
curl -o ~/flightpath_test.py \
    https://raw.githubusercontent.com/volmerinktim/drone_sim_setup/main/flightpath_test.py
curl -o ~/ros2_ws/tmux_launch.sh \
    https://raw.githubusercontent.com/volmerinktim/drone_sim_setup/main/tmux_launch.sh
chmod +x ~/ros2_ws/tmux_launch.sh

echo "============================================"
echo " Setup complete! Restart your terminal, then:"
echo ""
echo " Step 1 - Generate flight path:"
echo ""
echo " Step 2 - Launch simulation:"
echo "   cd ~/ros2_ws && bash tmux_launch.sh"
echo "============================================"
