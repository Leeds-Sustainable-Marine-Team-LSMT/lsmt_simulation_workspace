# LSMT Marine Autonomy - ROS 2 Workspace

A hardware-agnostic, containerized ROS 2 Humble development environment for the LSMT Njord team.

**1. Clone the repository**

bash
git clone git@github.com:Hemish-Patel/lsmt_workspace.git
cd lsmt_workspace

**2. Build the Environment (Run Once)**
This will download Ubuntu 22.04 and ROS 2 Humble, then compile the container.

bash
sudo docker compose build

**3. Launch the Container**
This script automatically detects your host hardware (NVIDIA, AMD, or Intel) and boots the container with the correct GPU acceleration.

bash
./launch_lsmt.sh

## Development Workflow
Once the script runs, you will be dropped into the container at `root@hostname:/ros2_ws#`. 

Any ROS 2 C++ or Python packages you create inside the `src/` directory will instantly sync to your host computer. You can edit your code in VS Code on your host machine, and compile it (`colcon build`) inside the container.
