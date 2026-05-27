#!/bin/bash
set -e
echo "============================================"
echo " Drone Simulation - Full Setup Script"
echo " This will take 20-30 minutes"
echo "============================================"
# 1. System update
echo "[1/9] Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
    git curl wget nano tmux python3-pip ccache \
    build-essential cmake \
    libboost-all-dev liblog4cxx-dev libcairo2-dev \
    libapr1-dev libaprutil1-dev \
    x11-xserver-utils
# 2. ROS 2 Humble
echo "[2/9] Installing ROS 2 Humble..."
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
echo "[3/9] Installing MicroXRCEAgent..."
pip3 install pyserial
if [ ! -d ~/MicroXRCEAgent ]; then
    git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git ~/MicroXRCEAgent
    cd ~/MicroXRCEAgent && mkdir -p build && cd build
    cmake .. && make -j$(nproc) && sudo make install && sudo ldconfig
    cd ~
else
    echo "MicroXRCEAgent already installed, skipping..."
fi
# 4. PX4-Autopilot
echo "[4/9] Cloning PX4-Autopilot v1.15.4..."
if [ ! -d ~/PX4-Autopilot ]; then
    git clone --branch v1.15.4 --depth 1 \
        https://github.com/PX4/PX4-Autopilot.git ~/PX4-Autopilot \
        --recurse-submodules
    cd ~/PX4-Autopilot
    bash Tools/setup/ubuntu.sh --no-nuttx
    cd ~
else
    echo "PX4-Autopilot already installed, skipping..."
fi
# 5. Gazebo Harmonic
echo "[5/9] Installing Gazebo Harmonic..."
sudo curl https://packages.osrfoundation.org/gazebo.gpg \
    --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] \
    http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null
sudo apt-get update
sudo apt-get install -y gz-harmonic
# Add GZ resource path to bashrc
GZ_PATH="export GZ_SIM_RESOURCE_PATH=\$HOME/PX4-Autopilot/Tools/simulation/gz/models:\$HOME/PX4-Autopilot/Tools/simulation/gz/worlds"
grep -qxF "$GZ_PATH" ~/.bashrc || echo "$GZ_PATH" >> ~/.bashrc
# 6. px4_ws
echo "[6/9] Building px4_ws..."
if [ ! -d ~/px4_ws ]; then
    mkdir -p ~/px4_ws/src
    cd ~/px4_ws/src
    git clone --branch release/1.15 https://github.com/PX4/px4_msgs.git
    git clone https://github.com/Jaeyoung-Lim/px4-offboard.git px4_offboard
    cd ~/px4_ws
    source /opt/ros/humble/setup.bash
    colcon build --symlink-install
    echo "source ~/px4_ws/install/setup.bash" >> ~/.bashrc
else
    echo "px4_ws already installed, skipping..."
fi
# 7. QGroundControl
echo "[7/9] Downloading QGroundControl..."
mkdir -p ~/ros2_ws
wget -O ~/ros2_ws/QGroundControl.AppImage https://github.com/mavlink/qgroundcontrol/releases/download/v4.3.0/QGroundControl.AppImage
chmod +x ~/ros2_ws/QGroundControl.AppImage
# 8. Serial device permissions for QGroundControl
echo "[8/9] Configuring serial device permissions..."
sudo usermod -a -G dialout $USER
sudo apt-get remove -y modemmanager || true
echo "Serial permissions configured. A restart is required for group changes to take effect."
# 9. Flight scripts
echo "[9/9] Downloading flight scripts..."
curl -o ~/flightpath_test.py \
    https://raw.githubusercontent.com/volmerinktim/drone_sim_setup/main/flightpath_test.py
curl -o ~/ros2_ws/tmux_launch.sh \
    https://raw.githubusercontent.com/volmerinktim/drone_sim_setup/main/tmux_launch.sh
chmod +x ~/ros2_ws/tmux_launch.sh
echo "============================================"
echo " Setup complete! Restart your terminal, then:"
echo ""
echo " Step 1 - Generate flight path:"
echo "   python3 ~/flightpath_test.py"
echo ""
echo " Step 2 - Launch simulation (3 terminals):"
echo ""
echo "   Terminal 1 - PX4:"
echo "     cd ~/PX4-Autopilot && make px4_sitl none_iris"
echo ""
echo "   Terminal 2 - Gazebo Harmonic:"
echo "     gz sim -r ~/PX4-Autopilot/Tools/simulation/gz/worlds/default.sdf"
echo ""
echo "   Terminal 3 - Bridge:"
echo "     cd ~/PX4-Autopilot/Tools/simulation/gz/simulation-gazebo"
echo "     python3 simulation-gazebo --gz-sim --model x500"
echo ""
echo "   Or use the tmux launcher:"
echo "     cd ~/ros2_ws && bash tmux_launch.sh"
echo "============================================"
