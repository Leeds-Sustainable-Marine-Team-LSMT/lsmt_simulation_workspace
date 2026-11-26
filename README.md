# LSMT Marine Autonomy - ROS 2 & VRX Simulation Workspace

A hardware-agnostic, containerised **ROS 2 Humble** and **Gazebo Garden (VRX)** development environment for the Leeds Sustainable Marine Team (LSMT) Njord autonomous surface vessel (ASV) project.

---

## Table of Contents
1. [Environment & Docker Setup](#1-environment--docker-setup)
2. [Docker & Workspace Architecture](#2-docker--workspace-architecture)
3. [Simulation Architecture](#3-simulation-architecture)
4. [Launching & Controlling the Simulation](#4-launching--controlling-the-simulation)
5. [Development Process & Instructions](#5-development-process--instructions)

---

## 1. Environment & Docker Setup

### Prerequisites & Hardware Support
Before starting, ensure you have the following installed on your Linux host machine:
- **Git**
- **Docker** and **Docker Compose** (`docker compose` plugin)

#### GPU Acceleration Support
The environment automatically adapts to your hardware when launched via `./launch_lsmt.sh`:
- **NVIDIA GPUs:** Full hardware acceleration via `docker-compose.nvidia.yml` (requires **[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)** on the host).
- **AMD & Intel GPUs:** Full hardware acceleration out of the box via Linux Direct Rendering Infrastructure (`/dev/dri`) and Mesa, with no extra toolkit required.
- **No GPU (CPU-only):** Automatically falls back to Mesa CPU software rendering (`llvmpipe`).

### First-Time Setup: From Zero to Running

#### Step 1: Clone the Repository
```bash
git clone git@github.com:Leeds-Sustainable-Marine-Team-LSMT/lsmt_simulation_workspace.git
cd lsmt_simulation_workspace
```
*(Or using HTTPS: `git clone https://github.com/Leeds-Sustainable-Marine-Team-LSMT/lsmt_simulation_workspace.git`)*

#### Step 2: Build the Docker Image (Run Once)
This downloads Ubuntu 22.04, ROS 2 Humble, Gazebo Garden, `ros_gz` bridges, and all VRX dependencies defined in the `Dockerfile`:
```bash
sudo docker compose build
```

#### Step 3: Launch the Container
This script automatically detects your host hardware (NVIDIA, AMD, or Intel) and boots the container with the correct GPU acceleration:
```bash
./launch_lsmt.sh
```

#### Step 4: Compile the ROS 2 Workspace (First Time Only)
Once inside the container (`root@<hostname>:/ros2_ws#`), compile the VRX packages using `colcon` and source the overlay:
```bash
colcon build --merge-install
source install/setup.bash
```

> **Note:** After completing the first-time setup above, both `/opt/ros/humble/setup.bash` and `/ros2_ws/install/setup.bash` are **automatically sourced** every time the container starts. You do not need to run `colcon build` again unless you edit or add packages in `src/`.

---

## 2. Docker & Workspace Architecture

The project separates the **Docker infrastructure** (at the repository root) from the **ROS 2 source packages** (inside `src/`), linking them together via bind mounts and persistent volumes:

| Container Path | Host Location | Purpose |
| :--- | :--- | :--- |
| `/ros2_ws/src` | `./src` (in this repo folder) | **Live-synced source code.** Edit or create ROS 2 C++/Python packages in VS Code on your host machine; changes appear immediately inside the container. |
| `/ros2_ws/build` | Docker volume (`ros2_build`) | Persistent CMake/Colcon intermediate build files. |
| `/ros2_ws/install` | Docker volume (`ros2_install`) | Persistent compiled ROS 2 binaries and environment hooks. |
| `/ros2_ws/log` | Docker volume (`ros2_log`) | Persistent `colcon` build and runtime logs. |

- **`Dockerfile`:** Defines the Ubuntu 22.04 + ROS 2 Humble + Gazebo Garden image and pre-installs `ros_gz` bridges and VRX dependencies.
- **`docker-compose.yml` & `docker-compose.nvidia.yml`:** Passes X11 display sockets, `/dev/dri` GPU devices, and NVIDIA PRIME render offload into the container so Gazebo and RViz2 windows open natively on the host desktop.
- **`launch_lsmt.sh`:** Grants local X11 display access (`xhost +local:root`), checks for an active NVIDIA GPU via `nvidia-smi`, and starts the container.

---

## 3. Simulation Architecture

### Repository & Package Structure

- `Dockerfile` - Container OS, ROS 2 Humble & Gazebo Garden image definition
- `docker-compose.yml` - Base container configuration & persistent volumes
- `docker-compose.nvidia.yml` - NVIDIA GPU hardware acceleration override
- `launch_lsmt.sh` - Hardware-detecting container launch script
- `src/` - ROS 2 Workspace Source Directory
  - **`vrx/`** - Upstream VRX simulation packages (treat as read-only)
    - `vrx_urdf/` - Default WAM-V catamaran description (`wamv_description`, `wamv_gazebo`)
    - `vrx_gz/` - Gazebo Garden ocean worlds, launch files, and `ros_gz` bridges
    - `vrx_ros/` - Base VRX ROS 2 interface packages
  - **`lsmt_control/`** - C++ (`ament_cmake`) low-level thruster allocation and control package
    - `src/` - C++ control nodes (e.g. `/cmd_vel` to WAM-V thruster allocation)
    - `include/lsmt_control/` - C++ header files
    - `CMakeLists.txt` & `package.xml`
  - **Future LSMT packages** (placed directly inside `src/` alongside `vrx/` and `lsmt_control/`, e.g. `lsmt_navigation/`, `lsmt_perception/`)

### How ROS 2 Packages Work (`package.xml` & `CMakeLists.txt` / `setup.py`)
Every ROS 2 package inside `src/` contains configuration files so `colcon build` knows how to find, build, and install it:
1. **`package.xml` (Package Manifest & Dependency List):**
   - Identifies the directory as a ROS 2 package (`<name>...</name>`) and declares which ROS 2 libraries (`<depend>rclcpp</depend>`, `<depend>rclpy</depend>`, etc.) it requires. Without `package.xml`, `colcon build` ignores the directory.
2. **Build Recipe (`CMakeLists.txt` for C++ / `setup.py` for Python):**
   - **C++ (`ament_cmake`):** Uses `add_executable(...)` and `ament_target_dependencies(...)` in `CMakeLists.txt` to compile `.cpp` files in `src/` into native binaries and install them into `/ros2_ws/install/lib/` for `ros2 run`. Launch/config/URDF folders are installed with `install(DIRECTORY ... DESTINATION share/${PROJECT_NAME})`.
   - **Python (`ament_python`):** Uses `setup.py` (`entry_points` console scripts and `data_files`) to register Python nodes and install launch/config files into `/ros2_ws/install/`.

### Autonomy & Hardware Isolation Pipeline
Because LSMT's final hull and custom thruster placement are still being finalised, the autonomy stack is split behind a clean vessel-agnostic interface on the default WAM-V catamaran:

1. **High-Level Autonomy (`lsmt_navigation`, `lsmt_perception`):** State estimation (GPS + IMU -> local odometry), buoy/obstacle perception, and path planning / Line-of-Sight (LOS) guidance publish vessel-agnostic velocity commands (e.g. `/cmd_vel`, `geometry_msgs/msg/Twist`).
2. **Low-Level Thruster Allocation (`lsmt_control`):** Subscribes to `/cmd_vel` and converts desired surge/yaw commands into the vessel's thruster inputs. On the default WAM-V, this drives `/wamv/thrusters/left/thrust`, `/wamv/thrusters/right/thrust`, and their `pos` topics (`std_msgs/msg/Float64`).
3. **VRX Simulation (`vrx_gz`):** Bridges thruster commands and vessel sensors between ROS 2 and Gazebo Garden. Key WAM-V sensor topics include:
   - `/wamv/sensors/gps/gps/fix` (`sensor_msgs/msg/NavSatFix`)
   - `/wamv/sensors/imu/imu/data` (`sensor_msgs/msg/Imu`)
   - `/wamv/sensors/lidars/...` (`sensor_msgs/msg/LaserScan` / `PointCloud2`)
   - `/wamv/sensors/cameras/...` (`sensor_msgs/msg/Image`)
   - `/wamv/sensors/position/ground_truth_odometry` (`nav_msgs/msg/Odometry`)

When LSMT's custom Njord hull and thruster layout are finalised, only the robot URDF and the low-level thruster allocation node need updating; the high-level localisation, perception, and path-planning nodes remain untouched.

---

## 4. Launching & Controlling the Simulation

### Step 1: Launch VRX Simulation
Start the container (`./launch_lsmt.sh`) and launch the default Sydney Regatta world:
```bash
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta
```
Other available task worlds include `follow_path_task`, `navigation_task`, `wayfinding_task`, and `stationkeeping_task`.

### Step 2: Open a Second Terminal Inside the Running Container
On your **host machine**, open a new terminal tab (`Ctrl+Shift+T`) and attach to the running container:
```bash
sudo docker exec -it $(sudo docker ps -q) bash
```

### Step 3: Inspect WAM-V Topics & Test Thrusters Manually
List the active WAM-V sensor and thruster topics:
```bash
ros2 topic list | grep wamv
```
To manually test the WAM-V's left and right thrusters from the terminal (use `-1` to publish a single message after connecting to the bridge):
```bash
# Apply forward thrust to both rear thrusters
ros2 topic pub -1 /wamv/thrusters/left/thrust std_msgs/msg/Float64 "{data: 200.0}"
ros2 topic pub -1 /wamv/thrusters/right/thrust std_msgs/msg/Float64 "{data: 200.0}"

# Stop both thrusters
ros2 topic pub -1 /wamv/thrusters/left/thrust std_msgs/msg/Float64 "{data: 0.0}"
ros2 topic pub -1 /wamv/thrusters/right/thrust std_msgs/msg/Float64 "{data: 0.0}"
```

---

## 5. Development Process & Instructions

### Rebuilding After Editing Code in `src/`
Whenever you modify source files, launch files, URDF/Xacro models, or build configs inside `src/`, re-run inside the container:
```bash
cd /ros2_ws
colcon build --merge-install
source install/setup.bash
```

#### Fast Single-Package Rebuild
Because `src/vrx/` is large, once VRX has been built at least once you can rebuild only your custom LSMT package(s) (such as `lsmt_control`) using `--packages-select`:
```bash
cd /ros2_ws
colcon build --merge-install --packages-select lsmt_control
source install/setup.bash
```

### Creating a New LSMT ROS 2 Package
Create custom packages inside `/ros2_ws/src` alongside `vrx/` (never inside `vrx/`):

- **For a C++ package (`ament_cmake`):**
  ```bash
  cd /ros2_ws/src
  ros2 pkg create <package_name> --build-type ament_cmake --dependencies rclcpp std_msgs geometry_msgs
  chmod -R 777 <package_name>
  ```
- **For a Python package (`ament_python`):**
  ```bash
  cd /ros2_ws/src
  ros2 pkg create <package_name> --build-type ament_python --dependencies rclpy std_msgs geometry_msgs
  chmod -R 777 <package_name>
  ```
*(Run `chmod -R 777 <package_name>` inside the container so VS Code on the host machine has write permissions to edit the new files.)*

### Resetting / Cleaning the Build Cache
If you ever want to perform a completely clean rebuild (wiping `build/`, `install/`, and `log/` volumes without touching `src/`), run this on your **host machine**:
```bash
sudo docker compose down -v
```
