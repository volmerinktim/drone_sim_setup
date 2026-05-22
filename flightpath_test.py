#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, QoSReliabilityPolicy, QoSHistoryPolicy

from px4_msgs.msg import OffboardControlMode
from px4_msgs.msg import TrajectorySetpoint
from px4_msgs.msg import VehicleCommand

class FlightPathTest(Node):
    def __init__(self):
        super().__init__('flightpath_test')

        qos_profile = QoSProfile(
            reliability=QoSReliabilityPolicy.BEST_EFFORT,
            history=QoSHistoryPolicy.KEEP_LAST,
            depth=5
        )

        # Publishers
        self.offboard_mode_pub = self.create_publisher(OffboardControlMode, '/fmu/in/offboard_control_mode', qos_profile)
        self.trajectory_setpoint_pub = self.create_publisher(TrajectorySetpoint, '/fmu/in/trajectory_setpoint', qos_profile)
        self.vehicle_command_pub = self.create_publisher(VehicleCommand, '/fmu/in/vehicle_command', qos_profile)

        # 10Hz stream loop timer
        self.timer = self.create_timer(0.1, self.timer_callback) 
        
        # Flight State Machine
        self.flight_state = "STARTUP"
        self.state_timer = 0

        # Square Flight Path Waypoints (Relative to takeoff point)
        self.waypoints = [
            [0.0, 0.0, -5.0],  # Waypoint 0: Stay at Takeoff Hover
            [5.0, 0.0, -5.0],  # Waypoint 1: Move X by 5m
            [5.0, 5.0, -5.0],  # Waypoint 2: Move Y by 5m
            [0.0, 5.0, -5.0],  # Waypoint 3: Move X back to 0
            [0.0, 0.0, -5.0]   # Waypoint 4: Return to home
        ]
        self.current_wp_idx = 0
        self.loop_count = 0

    def send_command(self, command, param1=0.0, param2=0.0):
        """Helper function to send raw commands (Arm, Mode change) to PX4"""
        msg = VehicleCommand()
        msg.timestamp = int(self.get_clock().now().nanoseconds / 1000)
        msg.param1 = float(param1)
        msg.param2 = float(param2)
        msg.command = command
        msg.target_system = 1
        msg.target_component = 1
        msg.source_system = 1
        msg.source_component = 1
        msg.from_external = True
        self.vehicle_command_pub.publish(msg)

    def timer_callback(self):
        current_timestamp = int(self.get_clock().now().nanoseconds / 1000)
        self.state_timer += 1

        # ALWAYS stream offboard heartbeats first (PX4 requires this to stay in Offboard mode)
        offboard_msg = OffboardControlMode()
        offboard_msg.timestamp = current_timestamp
        offboard_msg.position = True
        offboard_msg.velocity = False
        offboard_msg.acceleration = False
        offboard_msg.attitude = False
        offboard_msg.body_rate = False
        self.offboard_mode_pub.publish(offboard_msg)

        # State Machine Handling
        if self.flight_state == "STARTUP":
            # Stream heartbeats for 2 seconds (20 loops) before commanding modes
            if self.state_timer > 20:
                self.flight_state = "ARMING"
                self.state_timer = 0

        elif self.flight_state == "ARMING":
            self.get_logger().info("Sending Arm and Offboard commands...")
            self.send_command(VehicleCommand.VEHICLE_CMD_COMPONENT_ARM_DISARM, 1.0) # 1.0 = Arm
            self.send_command(VehicleCommand.VEHICLE_CMD_DO_SET_MODE, 1.0, 6.0)     # 1.0 = Custom, 6.0 = Offboard
            self.flight_state = "TAKEOFF"
            self.state_timer = 0

        elif self.flight_state == "TAKEOFF":
            # Hold takeoff setpoint [0, 0, -5] for 5 seconds (50 loops) to lift off safely
            target = self.waypoints[0]
            self.publish_setpoint(current_timestamp, target)
            if self.state_timer > 50:
                self.flight_state = "NAVIGATING"
                self.get_logger().info("Takeoff complete. Starting square path pattern.")

        elif self.flight_state == "NAVIGATING":
            target = self.waypoints[self.current_wp_idx]
            self.publish_setpoint(current_timestamp, target)

            self.loop_count += 1
            if self.loop_count >= 50: # Switch waypoints every 5 seconds
                self.current_wp_idx = (self.current_wp_idx + 1) % len(self.waypoints)
                self.loop_count = 0
                self.get_logger().info(f'Navigating to Waypoint {self.current_wp_idx}: {target}')

    def publish_setpoint(self, timestamp, target):
        setpoint_msg = TrajectorySetpoint()
        setpoint_msg.timestamp = timestamp
        setpoint_msg.position = [float(target[0]), float(target[1]), float(target[2])]
        setpoint_msg.yaw = 0.0
        self.trajectory_setpoint_pub.publish(setpoint_msg)

def main(args=None):
    rclpy.init(args=args)
    node = FlightPathTest()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()