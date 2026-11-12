FROM osrf/ros:humble-desktop

# Install basic development extensions and networking tools
RUN apt-get update && apt-get install -y \
    nano \
    python3-colcon-common-extensions \
    mesa-utils \
    wget \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Add OSRF Repository (Gazebo Garden is hosted here, not on Ubuntu default servers)
RUN wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable jammy main" > /etc/apt/sources.list.d/gazebo-stable.list

# Force ROS 2 to link with Gazebo Garden
ENV GZ_VERSION=garden

# Update lists with the new OSRF server and install Garden, bridges, and VRX dependencies
RUN apt-get update && apt-get install -y \
    gz-garden \
    libgz-msgs9-dev \
    ros-humble-ros-gzgarden-sim \
    ros-humble-ros-gzgarden-bridge \
    ros-humble-ros-gzgarden-interfaces \
    ros-humble-xacro \
    ros-humble-vision-msgs \
    ros-humble-gps-msgs \
    ros-humble-actuator-msgs \
    python3-sdformat13 \
    && rm -rf /var/lib/apt/lists/*

# Enable NVIDIA GPU passthrough for X11/GLX rendering
ENV NVIDIA_VISIBLE_DEVICES \
    ${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_CAPABILITIES \
    ${NVIDIA_DRIVER_CAPABILITIES:+$NVIDIA_DRIVER_CAPABILITIES,}graphics,compute,utility

# Set up the workspace
RUN mkdir -p /ros2_ws/src
WORKDIR /ros2_ws

# Auto-source ROS 2 and workspace overlay (if built) on container entry
RUN echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc && \
    echo "if [ -f /ros2_ws/install/setup.bash ]; then source /ros2_ws/install/setup.bash; fi" >> ~/.bashrc

CMD ["/bin/bash"]
