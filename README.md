# LSMT Marine Autonomy - ROS 2 & VRX Simulation Workspace

A hardware-agnostic, containerized **ROS 2 Humble** and **Gazebo Garden (VRX)** development environment for the Leeds Sustainable Marine Team (LSMT) Njord project.

---

## Prerequisites

Before starting, ensure you have the following installed on your Linux host machine:
- **Git**
- **Docker** and **Docker Compose** (`docker compose` plugin)
- *(NVIDIA GPU users only)* **[NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)** for hardware-accelerated rendering (`launch_lsmt.sh` automatically detects NVIDIA, AMD, or Intel GPUs).

---

## Quick Start: From Zero to Running VRX

### 1. Clone the Repository
Clone this workspace to your computer and navigate into the folder:

```bash
git clone git@github.com:Leeds-Sustainable-Marine-Team-LSMT/lsmt_simulation_workspace.git
cd lsmt_simulation_workspace
```
*(Or using HTTPS: `git clone https://github.com/Leeds-Sustainable-Marine-Team-LSMT/lsmt_simulation_workspace.git`)*

---

### 2. Build the Docker Image (Run Once)
This downloads Ubuntu 22.04, ROS 2 Humble, Gazebo Garden, `ros_gz` bridges, and all VRX dependencies defined in the `Dockerfile`:

```bash
sudo docker compose build
```

---

### 3. Launch the Container
This script automatically detects your host hardware (NVIDIA, AMD, or Intel) and boots the container with the correct GPU acceleration:

```bash
./launch_lsmt.sh
```

---

### 4. Compile the ROS 2 Workspace (First Time Only)
Once inside the container (`root@<hostname>:/ros2_ws#`), compile the VRX packages using `colcon` and source the workspace:

```bash
colcon build --merge-install
source install/setup.bash
```

> **Note:** Your compiled `build/`, `install/`, and `log/` folders are saved inside persistent Docker volumes. You **do not** need to run `colcon build` again unless you edit or add packages in `src/`.

---

### 5. Launch the VRX Simulation
Inside the container, launch the default Sydney Regatta competition world in Gazebo Garden:

```bash
ros2 launch vrx_gz competition.launch.py world:=sydney_regatta
```

---

## Subsequent Runs (Daily Usage)

After completing the first-time setup above, both `/opt/ros/humble/setup.bash` and `/ros2_ws/install/setup.bash` are **automatically sourced** every time the container starts.

Next time you open a terminal, simply run:

1. **On your host machine:**
   ```bash
   cd ~/lsmt_simulation_workspace
   ./launch_lsmt.sh
   ```
2. **Inside the container:**
   ```bash
   ros2 launch vrx_gz competition.launch.py world:=sydney_regatta
   ```

---

## Development Workflow & File Storage

| Container Path | Host Location | Purpose |
| :--- | :--- | :--- |
| `/ros2_ws/src` | `./src` (in this repo folder) | **Live-synced source code.** Edit or create ROS 2 C++/Python packages in VS Code on your host machine; changes appear immediately inside the container. |
| `/ros2_ws/build` | Docker volume (`ros2_build`) | Persistent CMake/Colcon intermediate build files. |
| `/ros2_ws/install` | Docker volume (`ros2_install`) | Persistent compiled ROS 2 binaries and environment hooks. |
| `/ros2_ws/log` | Docker volume (`ros2_log`) | Persistent `colcon` build and runtime logs. |

### Rebuilding After Editing Code in `src/`
Whenever you modify C++ code, launch files, or add a new package inside `src/`, re-run inside the container:

```bash
colcon build --merge-install
source install/setup.bash
```

### Resetting / Cleaning the Build Cache
If you ever want to perform a completely clean rebuild (wiping `build/`, `install/`, and `log/` without touching `src/`), run this on your **host machine**:

```bash
sudo docker compose down -v
```
