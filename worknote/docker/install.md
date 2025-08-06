# 安装

Docker 引擎支持 Mac 和 Windows桌面版，还有支持各种 Linux 的主流发行版本，Docker 官方[安装文档](https://docs.docker.com/engine/install/)参考。

Docker Engine 有 3 种更新通道：stable、test、nightly。

- stable: 最新并且可用的稳定版本。
- test: GA 发布之前的预览测试版本。
- nightly: 针对下一个主要发行版本的每晚自动构建包。

## CentOS 安装 Docker

**操作系统要求**

要安装 Docker 引擎，您需要 CentOS 7 或 8 的维护版本，不支持测试或存档版本。

必须启用 centos-extras 库，默认情况下已启用此存储库，但如果你已禁用它，则需要重新启用它。

推荐使用 overlay2 存储驱动。

**卸载旧版本**

```bash
sudo yum remove docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-engine
```

**安装方法**

可以根据以下不同的方式去安装 Docker:

- 大部分用户使用设置 Docker 存储库的方法去安装，这也是官方推荐的安装方法。
- 下载 RPM 包进行手动安装和管理，这在没有外网的机器上安装 Docker 非常有用。
- 在测试和开发环境中，使用脚本自动化安装 Docker。

**使用存储库安装**

```bash
# 设置存储库
sudo yum install -y yum-utils

sudo yum-config-manager \
  --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo
  
# 安装 Docker 引擎
sudo yum install -y docker-ce docker-ce-cli containerd.io
```

## Ubuntu 安装 Docker

**操作系统要求**

要安装 Docker，你需要以下 Ubuntu 64 位版本：

- Ubuntu 20.04 (LTS)
- Ubuntu 18.04 (LTS)

**卸载旧版本**

```bash
sudo apt-get remove docker docker-engine docker.io containerd runc
```

**使用存储库安装**

```bash
# 更新 apt 包索引并安装包
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release
  
# 添加 Docker 官方的 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置稳定存储库
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
# 安装 Docker 引擎
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
```

