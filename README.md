# LSMT Marine Autonomy - ROS 2 & VRX Simulation Workspace

A hardware-agnostic, containerised **ROS 2 Humble** and **Gazebo Garden (VRX)** development environment for the Leeds Sustainable Marine Team (LSMT) Njord autonomous surface vessel (ASV) project.

---

## Table of Contents
1. [Environment & Docker / Apptainer Setup](#1-environment--docker--apptainer-setup)
2. [Container & Workspace Architecture](#2-container--workspace-architecture)
3. [Simulation Architecture](#3-simulation-architecture)
4. [Launching & Controlling the Simulation](#4-launching--controlling-the-simulation)
5. [Development Process & Instructions](#5-development-process--instructions)

---

## 1. Environment & Docker / Apptainer Setup

### Prerequisites & Hardware Support
- **Personal Linux PCs (with root/sudo access):** **Git**, **Docker**, and **Docker Compose** (`docker compose` plugin).
- **University PCs (without root access):** **Git** and **Apptainer** (or **Singularity**). No `sudo` or Docker daemon access is needed.

#### GPU Acceleration Support
Both launch scripts automatically detect your hardware:
- **NVIDIA GPUs:** Full hardware acceleration via `docker-compose.nvidia.yml` on Docker (requires **[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)**) or `--nv` on Apptainer/Singularity.
- **AMD & Intel GPUs:** Full hardware acceleration out of the box via Linux Direct Rendering Infrastructure (`/dev/dri`) and Mesa, with no extra toolkit required.
- **No GPU (CPU-only):** Automatically falls back to Mesa CPU software rendering (`llvmpipe`).

### First-Time Setup

#### Option A: Personal Linux Machine (Docker)

1. **Clone the repository:**
   ```bash
   git clone git@github.com:Leeds-Sustainable-Marine-Team-LSMT/lsmt_simulation_workspace.git
   cd lsmt_simulation_workspace
   ```
   *(Or using HTTPS: `git clone https://github.com/Leeds-Sustainable-Marine-Team-LSMT/lsmt_simulation_workspace.git`)*

2. **Build the Docker image (run once):**
   This downloads Ubuntu 22.04, ROS 2 Humble, Gazebo Garden, `ros_gz` bridges, and all VRX dependencies defined in `Dockerfile`:
   ```bash
   sudo docker compose build
   ```

3. **Launch the container:**
   ```bash
   ./launch_lsmt.sh
   ```

4. **Compile the ROS 2 workspace (first time only):**
   Once inside the container (`root@<hostname>:/ros2_ws#`), compile the workspace and source the overlay:
   ```bash
   colcon build --merge-install
   source install/setup.bash
   ```

> **Note:** After completing the first-time setup above, both `/opt/ros/humble/setup.bash` and `/ros2_ws/install/setup.bash` are **automatically sourced** every time the container starts. You do not need to run `colcon build` again unless you edit or add packages in `src/`.

#### Option B: University PCs without Root Access (Apptainer / Singularity)

University lab workstations typically block `docker` and `sudo`, so `launch_lsmt.sh` and `docker compose` cannot be used there. Instead, use `launch_lsmt_uni.sh`, which runs the exact same environment rootlessly using a `.sif` container image via **Apptainer** or **Singularity**.

1. **Clone the repository on the university PC:**
   ```bash
   git clone git@github.com:Leeds-Sustainable-Marine-Team-LSMT/lsmt_simulation_workspace.git
   cd lsmt_simulation_workspace
   ```

2. **Obtain the `.sif` image (`lsmt.sif`) without root access:**
   *(If your lab already has a shared `.sif` file, skip this step and pass its path directly to `./launch_lsmt_uni.sh /path/to/lsmt.sif`. If the lab uses `singularity` instead of `apptainer`, substitute `singularity` in the commands below.)*
   - **Method 1 (Pull from a container registry):**
     ```bash
     apptainer pull lsmt.sif docker://<registry>/<image>:<tag>
     ```
   - **Method 2 (Export from a Docker machine and convert):**
     On a personal machine where `sudo docker compose build` has already been run, export the image as a `.tar` archive:
     ```bash
     sudo docker save lsmt_simulation_workspace-ros-dev:latest -o lsmt.tar
     ```
     Transfer `lsmt.tar` to the university PC (USB or `scp`), then build the `.sif` image inside `lsmt_simulation_workspace`:
     ```bash
     apptainer build lsmt.sif docker-archive://lsmt.tar
     ```

3. **Launch the container:**
   ```bash
   ./launch_lsmt_uni.sh
   ```
   *(Or pass a custom/shared image path: `./launch_lsmt_uni.sh /path/to/lsmt.sif`, or set `LSMT_SIF=/path/to/lsmt.sif`.)*

4. **Compile the ROS 2 workspace (first time only):**
   ```bash
   colcon build --merge-install
   source install/setup.bash
   ```

---

## 2. Container & Workspace Architecture

The project separates the **container infrastructure** (at the repository root) from the **ROS 2 source packages** (inside `src/`). Because Apptainer `.sif` images are read-only, `build/`, `install/`, and `log/` are bind-mounted to local host folders (ignored by `.gitignore`) instead of Docker named volumes:

| Container Path | Host Location (Docker) | Host Location (Uni PC / Apptainer) | Purpose |
| :--- | :--- | :--- | :--- |
| `/ros2_ws/src` | `./src` | `./src` | **Live-synced source code.** Edit ROS 2 C++/Python packages in VS Code on the host; changes appear immediately inside the container. |
| `/ros2_ws/build` | Docker volume (`ros2_build`) | `./build` (git-ignored) | Persistent CMake/Colcon intermediate build files. |
| `/ros2_ws/install` | Docker volume (`ros2_install`) | `./install` (git-ignored) | Persistent compiled ROS 2 binaries and environment hooks. |
| `/ros2_ws/log` | Docker volume (`ros2_log`) | `./log` (git-ignored) | Persistent `colcon` build and runtime logs. |

- **`Dockerfile`:** Defines the Ubuntu 22.04 + ROS 2 Humble + Gazebo Garden image and pre-installs `ros_gz` bridges and VRX dependencies.
- **`docker-compose.yml` & `docker-compose.nvidia.yml`:** Passes X11 display sockets, `/dev/dri` GPU devices, and NVIDIA PRIME render offload into the Docker container so Gazebo and RViz2 windows open natively on the host desktop.
- **`launch_lsmt.sh`:** Docker launch script for personal machines; grants local X11 display access (`xhost +local:root`), checks for an active NVIDIA GPU via `nvidia-smi`, and starts the container.
- **`launch_lsmt_uni.sh`:** Rootless Apptainer/Singularity launch script for university PCs; auto-detects `apptainer` or `singularity`, adds `--nv` when an NVIDIA GPU is present, bind-mounts `./src`, `./build`, `./install`, and `./log`, and runs as your normal user account (so files stay owned by you with no `xhost` or `chmod 777` needed). It also explicitly sources `/opt/ros/humble/setup.bash` and `/ros2_ws/install/setup.bash` using `--norc` so your host `~/.bashrc` does not override the container environment.

---

## 3. Simulation Architecture

### Repository & Package Structure

- `Dockerfile` - Container OS, ROS 2 Humble & Gazebo Garden image definition
- `docker-compose.yml` - Base Docker configuration & persistent volumes
- `docker-compose.nvidia.yml` - NVIDIA GPU hardware acceleration override for Docker
- `launch_lsmt.sh` - Hardware-detecting Docker launch script (personal PCs)
- `launch_lsmt_uni.sh` - Rootless Apptainer/Singularity launch script (university PCs)
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
Start the container (`./launch_lsmt.sh` on Docker, or `./launch_lsmt_uni.sh` on a uni PC) and launch the default Sydney Regatta world:
```bash
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta
```
Other available task worlds include `follow_path_task`, `navigation_task`, `wayfinding_task`, and `stationkeeping_task`.

For lower-memory laptops (e.g. 8 GB RAM or integrated graphics), run VRX headless (full physics, sensors, and ROS 2 bridges without the heavy 3D Gazebo GUI) and visualise topics in `rviz2`:
```bash
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta headless:=True
```

### Step 2: Open a Second Terminal Inside the Running Container
- **On Docker (personal PC):** Open a new terminal tab (`Ctrl+Shift+T`) on your host machine and attach to the running container:
  ```bash
  sudo docker exec -it $(sudo docker ps -q) bash
  ```
- **On Uni PCs (Apptainer / Singularity):** Simply open a new terminal tab and run `./launch_lsmt_uni.sh` again. Apptainer instances run directly under your user session, sharing the host network and the bind-mounted `/ros2_ws` directories without needing `docker exec`.

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
  ```
- **For a Python package (`ament_python`):**
  ```bash
  cd /ros2_ws/src
  ros2 pkg create <package_name> --build-type ament_python --dependencies rclpy std_msgs geometry_msgs
  ```
*(When using Docker as `root`, also run `chmod -R 777 <package_name>` inside the container so VS Code on the host machine has write permissions to edit the new files. On Apptainer/Singularity, files are already owned by your user so `chmod` is not needed.)*

### Resetting / Cleaning the Build Cache
If you ever want to perform a completely clean rebuild (wiping `build/`, `install/`, and `log/` without touching `src/`), run on your **host machine**:
- **Docker:**
  ```bash
  sudo docker compose down -v
  ```
- **Uni PC (Apptainer / Singularity):**
  ```bash
  rm -rf build/ install/ log/
  ```
