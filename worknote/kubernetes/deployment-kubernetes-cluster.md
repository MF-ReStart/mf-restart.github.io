# 部署 Kubernetes 集群

Kubernetes 官方提供多种部署方式：

- 云解决方案。
- 使用部署工具安装 Kubernetes。
- Windows Kubernetes。

我们这里使用部署工具来安装 Kubernetes，官方提供的工具主要有以下几个：

- Kubeadm: 官方维护的为了给创建 Kubernetes 集群提供最佳实践的一个工具，涉及集群生命周期管理等知识。

- Kops: 在 AWS 上安装 Kubernetes 集群。
- Kubespray: Ansible 部署，OS 级别通用的部署方式，可以是裸机和云的环境。

这里我们使用 Kubeadm 部署，这是官方推荐的部署方式，Kubeadm 可用于生产级别的集群部署。

## 先决条件

- 一台或多台运行着下列系统的机器：
  - Ubuntu 16.04+
  - Debian 9+
  - CentOS 7+
  - Red Hat Enterprise Linux (RHEL) 7+
  - Fedora 25+
  - HypriotOS v1.0.1+
  - Flatcar Container Linux （使用 2512.3.0 版本测试通过）

- 每台机器 2 GB 或更多的 RAM （如果少于这个数字将会影响你应用的运行内存)。

- 2 CPU 核或更多。
- 集群中的所有机器的网络彼此均能相互连接(公网和内网都可以)。

- 节点之中不可以有重复的主机名、MAC 地址或 product_uuid。
- 开启机器上的某些端口（Kubernetes 服务所占用的端口必须开启）。
- 禁用交换分区。为了保证 kubelet 正常工作，你必须禁用交换分区。

## 环境配置

节点准备

```bash
k8s-master 10.10.110.190
k8s-ndoe1  10.10.110.191
k8s-node2  10.10.110.192
Operating System: Ubuntu 18.04.5 LTS
```

架构图

![](https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/Kubeadm-Kubernetes.png)

配置节点

```bash
# 关闭防火墙
systemctl stop ufw
ufw disable

# 检查所有节点网络接口的mac地址和product_uuid唯一性
ip link
cat /sys/class/dmi/id/product_uuid

# 禁用swap分区
swapoff -a

# 设置主机名
hostnamectl set-hostname [hostname]

# 配置hosts解析
cat >> /etc/hosts << EOF
10.10.110.190 k8s-master
10.10.110.191 k8s-node1
10.10.110.192 k8s-node2
EOF

# 允许iptables检查桥接流量
modprobe br_netfilter
lsmod | grep br_netfilter

cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

# 节点时间同步
timedatectl set-local-rtc 1
timedatectl set-timezone Asia/Shanghai
echo "*/5 *  *  *  * /usr/sbin/ntpdate ntp.aliyun.com &>/dev/null" | crontab
```

## 安装 Container Runtime

为了在 Pod 中运行容器，Kubernetes 需要使用容器运行时。

```bash
# 卸载旧版本
apt-get remove docker docker-engine docker.io containerd runc

# 更新apt包索引和安装包
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
    
# 添加Docker的官方GPG密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置稳定存储库
echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  
# 安装Docker引擎
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# 配置docker镜像加速,kubernetes官方建议docker驱动采用systemd,如果不修改kubeadm init时会有warning提示
cat <<EOF | tee /etc/docker/daemon.json
{
  "registry-mirrors": ["https://265wemgl.mirror.aliyuncs.com"], 
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl daemon-reload
systemctl restart docker.service
```

## 安装 kubeadm、kubelet 和 kubectl

你需要在每台机器上安装以下的软件包：

- `kubeadm`：用来初始化集群的指令。
- `kubelet`：在集群中的每个节点上用来启动 Pod 和容器等。
- `kubectl`：用来与集群通信的命令行工具。

kubeadm 不能帮你安装或者管理 kubelet 或 kubectl，所以你需要确保它们与通过 kubeadm 安装的控制平面的版本相匹配。

```bash
apt-get update && apt-get install -y apt-transport-https curl

curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl # 阻止软件自动更新
```

## 初始化控制平面节点

控制平面节点是运行控制平面组件的机器， 包括 etcd （集群数据库） 和 API Server（命令行工具 kubectl 与之通信）。

在所有 master 节点执行

```bash
kubeadm init \
  --apiserver-advertise-address=10.10.110.190 \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.21.0 \
  --service-cidr=10.96.0.0/12 \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=all
```

- --apiserver-advertise-address 服务器所公布的其正在监听的 IP 地址。
- --image-repository 默认拉取镜像地址为 k8s.gcr.io（国内网络无法拉取），这里指定阿里云镜像仓库地址。
- --kubernetes-version 指定 k8s 安装版本。
- --service-cidr 集群内部虚拟网络，pod 统一访问入口。
- --pod-network-cidr 指明 pod 网络可以使用的 IP 地址段。

拷贝 kubectl 连接 k8s 所使用的认证文件到当前用户的默认路径。

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## 安装 Pod 网络附加组件

你必须部署一个基于 Pod 网络插件的容器网络接口 (CNI)，以便你的 Pod 可以相互通信。 在安装网络之前，集群 DNS (CoreDNS) 将不会启动。这也是为什么 node 的状态其实是 NotReady 的原因。Kubernetes 常用的网络插件包括 Calico、Flannel、Canal 和 Weave，这里我们使用 Calico 来为 Kubernetes 集群提供网络策略支持。

你可以使用以下命令在控制平面节点或具有 kubeconfig 凭据的节点上安装 Pod 网络附加组件：

```bash
# 下载 calico 官方配置文件(国内网络可能会下载失败)
wget https://docs.projectcalico.org/manifests/calico.yaml

# 修改 calico 配置文件
- name: CALICO_IPV4POOL_CIDR
  value: "10.244.0.0/16"	# 修改为kubeadm init时指定的--pod-network-cidr网段
  
# 应用配置文件
kubectl apply -f calico.yaml

# 查看 pods 运行状态
kubectl get pods -n kube-system
```

## 加入节点

节点是你的工作负载（容器和 Pod 等）运行的地方。要将新节点添加到集群，请对每台计算机执行以下操作：

- SSH 到机器。
- 成为 root （例如 `sudo su -`）。
- 运行 `kubeadm init` 输出的命令。例如：

```bash
kubeadm join 10.10.110.190:6443 --token 54sx6k.gi533yr3f4yimvky \
    --discovery-token-ca-cert-hash sha256:3f16fb0f5c1ed611af164b8f5df6891ee60bba760286b860d125d08a304ed4b0
```

执行 kubeadm init 之后，默认生成的 token 有效期为 24 小时，过期之后就需要重新创建 token，操作如下：

```bash
# 列出token列表
kubeadm token list

# 创建token
kubeadm token create
bvw33z.dd7p7h2t151vc6ej  # 这里是新生成的token

# 获取CA证书公钥哈希值
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
3f16fb0f5c1ed611af164b8f5df6891ee60bba760286b860d125d08a304ed4b0

# 使用新的token和公钥哈希值加入节点
kubeadm join 10.10.110.190:6443 --token $(新生成的token) \
    --discovery-token-ca-cert-hash sha256:$(新生成的公钥哈希值)
```

## 部署 Dashboard

Dashboard 是基于网页的 Kubernetes 用户界面。 你可以使用 Dashboard 将容器应用部署到 Kubernetes 集群中，也可以对容器应用排错，还能管理集群资源。 你可以使用 Dashboard 获取运行在集群中的应用的概览信息，也可以创建或者修改 Kubernetes 资源 （如 Deployment，Job，DaemonSet 等等）。 例如，你可以对 Deployment 实现弹性伸缩、发起滚动升级、重启 Pod 或者使用向导创建新的应用。

默认情况下不会部署 Dashboard。可以通过以下命令部署：

```yaml
# 下载dashboard配置清单文件
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml

# dashboard默认的service是ClusterIP类型,我们需要修改为NodePort类型,才能让外部访问到我们的dashboard
---
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30023
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort
---

# 访问地址
https://nodeip:30023
```

访问 Dashboard 管理页面所需的 token，可以通过以下命令创建：

```bash
# 我们首先在kubernetes-dashboard命名空间中创建名为admin-user的service account
kubectl create serviceaccount admin-user -n kubernetes-dashboard
kubectl get serviceaccounts -n kubernetes-dashboard

# 创建集群角色绑定,给admin-user用户授权
kubectl create clusterrolebinding admin-user --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:admin-user

# 获取kubernetes-dashboard命名空间下admin-user用户的登录token
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
```

## 设置 k8s 命令自动补全

```bash
apt-get install -y bash-completion
locate bash_completion
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

