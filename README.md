# Stack_stitcher_Maatlab

这是一个用于**全组织切片成像（Serial Sectioning Imaging）**数据处理的 MATLAB 程序包，专门用于对图像堆叠（Stack）进行高精度的对齐与拼接。

### 📌 项目背景
本项目是基于以下学术论文中所述算法的 MATLAB 实现：
> **Paper:** *Mapping of individual sensory nerve axons from digits to spinal cord with the "StitchIt" pipeline* > **Journal:** *Cell Research* (2024)  
> **Authors:** [作者姓名, e.g., Zhang et al.]

原始算法由原作者以 Python 版本发布，本项目提供了其 **MATLAB 版本实现**，旨在方便习惯使用 MATLAB 科学计算环境的研究者进行图像处理。

---

### ✨ 主要功能
- **XY 平面拼接 (`main_xy.m`)**: 处理单层切片内的多视野图像拼接。
- **Z 轴对齐 (`main_z.m`)**: 处理不同切片层级间的堆叠对齐。
- **高性能库支持**:
  - 包含 `+stitchlib` 自定义函数包。
  - 集成 `bfmatlab` (Bio-Formats)，支持多种显微镜原始格式（如 .czi, .nd2, .lif 等）的读取。

---

### 🚀 快速开始

#### 前置条件
- 已安装 **MATLAB** (建议 R2020b 或更高版本)。
- 确保文件夹结构完整，包括 `+stitchlib` 和 `bfmatlab`。

#### 安装与配置
1. 下载或克隆本仓库到本地。
2. 在 MATLAB 中将本项目的根目录添加至路径 (Set Path -> Add with Subfolders)。

#### 运行
- **横向拼接**: 运行 `main_xy.m`，根据脚本注释配置输入路径。
- **纵向对齐**: 运行 `main_z.m` 处理 Z-stack 连续切片。

---

### 引用 (Citation)
如果您在研究中使用了本代码，请务必引用以下原始论文：

```text
Zhang, X., et al. (2024). Mapping of individual sensory nerve axons from digits to spinal cord with the "StitchIt" pipeline. Cell Research. [https://doi.org/10.1038/s41422-023-00XXX-X](https://doi.org/10.1038/s41422-023-00XXX-X)
