#!/bin/bash
# 1. Define the Session Name
SESSION="drone_sim"
# 2. Define the Function FIRST (so the script knows what it is)
send_cmd() {
    tmux send-keys -t "$1" "source /opt/ros/humble/setup.bash && source ~/px4_ws/install/setup.bash" C-m
    tmux send-keys -t "$1" "$2" C-m
}
# 3. Kill any old sessions and residual simulator processes to prevent errors
tmux kill-session -t "$SESSION" 2>/dev/null
sudo killall -9 ruby gz server gz sim px4 MicroXRCEAgent px4-mcap_log px4-nav_io python3 2>/dev/null
# 4. Start the session and create the 4-pane grid layout
tmux new-session -d -s "$SESSION" -n "Main"
tmux split-window -v -t "$SESSION"       # Creates Pane 1 (bottom)
tmux select-pane -t 0
tmux split-window -h -t "$SESSION"       # Creates Pane 2/2.1 (top-right)
tmux select-pane -t 1
tmux split-window -h -t "$SESSION"       # Creates Pane 3 (bottom-right)
# 5. Send the commands to the specific panes
# PANE 0: MicroXRCEAgent Bridge (DDS <-> ROS2, port 8888)
send_cmd "$SESSION.0" "MicroXRCEAgent udp4 -p 8888"
# PANE 1: Your Custom Flight Plan Script
tmux send-keys -t "$SESSION.1" "source /opt/ros/humble/setup.bash && source ~/px4_ws/install/setup.bash" C-m
tmux send-keys -t "$SESSION.1" "python3 ~/flightpath_test.py"
# PANE 2: PX4 SITL (connects to Gazebo on port 4560)
tmux send-keys -t "$SESSION.2" "cd ~/PX4-Autopilot" C-m
tmux send-keys -t "$SESSION.2" "make px4_sitl none_iris" C-m
# PANE 3: Gazebo Harmonic via simulation-gazebo script
tmux send-keys -t "$SESSION.3" "python3 ~/PX4-Autopilot/Tools/simulation/gz/simulation-gazebo --world default" C-m
# --- THE MAGIC LAYOUT LINE ---
tmux select-layout -t "$SESSION" tiled
# Attach to session
tmux attach-session -t "$SESSION"
