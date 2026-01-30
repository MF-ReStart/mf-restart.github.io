# Kubelet 概述

我们可以使用 Kubectl 命令行工具管理 Kubernetes 集群。默认情况下，`kubectl` 在 `$HOME/.kube` 目录下查找名为 `config` 的文件。 你可以通过设置 `KUBECONFIG` 环境变量或者设置 [`--kubeconfig`](https://kubernetes.io/docs/reference/generated/kubectl/kubectl/)参数来指定其他 kubeconfig 文件。使用 kubeconfig 文件来组织有关集群、用户、命名空间和身份认证机制的信息。`kubectl` 命令行工具使用 kubeconfig 文件来查找选择集群所需的信息，并与集群的 API 服务器进行通信。

说明：用于配置集群访问的文件称为 kubeconfig 文件。这是引用配置文件的通用方法。这并不意味着有一个名为 `kubeconfig` 的文件。

## [支持多集群]()、用户和身份认证机制[ ](https://kubernetes.io/zh/docs/concepts/configuration/organize-cluster-access-kubeconfig/#支持多集群-用户和身份认证机制)

假设您有多个集群，并且您的用户和组件以多种方式进行身份认证。比如：

- 正在运行的 kubelet 可能使用证书在进行认证。
- 用户可能通过令牌进行认证。
- 管理员可能拥有多个证书集合提供给各用户。

使用 kubeconfig 文件，您可以组织集群、用户和命名空间。您还可以定义上下文，以便在集群和命名空间之间快速轻松地切换。

## 上下文（Context）

通过 kubeconfig 文件中的 context 元素，使用简便的名称来对访问参数进行分组。每个上下文都有三个参数：cluster、namespace 和 user。默认情况下，kubectl 命令行工具使用当前上下文中的参数与集群进行通信。

选择当前上下文

```bash
kubectl config use-context
```

## KUBECONFIG 环境变量

`KUBECONFIG` 环境变量包含一个 kubeconfig 文件列表。 对于 Linux 和 Mac，列表以冒号分隔。对于 Windows，列表以分号分隔。 `KUBECONFIG` 环境变量不是必要的。 如果 `KUBECONFIG` 环境变量不存在，`kubectl` 使用默认的 kubeconfig 文件，`$HOME/.kube/config`。

如果 `KUBECONFIG` 环境变量存在，`kubectl` 使用 `KUBECONFIG` 环境变量中列举的文件合并后的有效配置。

## 语法

使用以下语法 `kubectl` 从终端窗口运行命令：

```bash
kubectl [command] [TYPE] [NAME] [flags]
```

- `command`: 指定要对一个或多个资源执行的操作，例如 `create`、`get`、`describe`、`delete`。
- `TYPE`: 指定资源类型。资源类型不区分大小写， 可以指定单数、复数或缩写形式。
- `NAME`: 指定资源的名称。名称区分大小写。 如果省略名称，则显示所有资源的详细信息 `kubectl get pods`。
- `flags`: 指定可选的参数。

## Kubectl --help

### 基本指令(初级)

- create: 从文件或标准输入创建资源。
- expose: 将资源作为新的 Kubernetes 服务公开。
- run: 在集群上运行指定的镜像。
- set: 设置对象的特定功能。

### 基本指令(中级)

- explain: 解释文档参考资料。
- get: 显示一个或多个资源。
- edit: 编辑服务器上的资源。
- delete: 通过文件名、标准输入、资源和名称或通过资源和标签选择器删除资源。

### 部署命令

- rollout: 管理资源的发布。
- scale: 对 deployment、ReplicaSet、Replication Controller 或 StatefulSet 扩容缩容。
- autoscale: 自动扩容缩容。

### 集群管理命令

- certificate: 修改证书资源。
- cluster-info: 显示集群信息。
- top: 显示资源(CPU/内存/存储)使用情况。
- cordon: 将节点标记为不可调度。
- uncordon: 将节点标记为可调度的。
- drain: 更新一个或多个节点上的污点。
- taint: 驱逐节点上的应用准备下线维护。

### 疑难解答和调试命令

- describe: 描述显示特定资源或资源组的详细信息。
- logs: 打印一个容器的日志。
- attach: 连接到正在运行的容器上。
- exec: 在容器中执行命令。
- port-forward: 转发一个或多个本地端口到一个 pod。
- proxy: 运行到 Kubernetes API 服务器的代理。
- cp: 在容器和容器之间复制文件和目录。
- auth: 授权检查。
- debug: 使用交互式调试容器调试群集资源。

### 高级命令

- diff: 由文件名或标准输入指定当前联机配置和应用时的配置差异。
- apply: 通过文件名或标准输入对资源应用配置。
- patch: 使用补丁更新资源的字段。
- replace: 用文件名或标准输入替换资源。
- wait: 等待一个或多个资源的特定条件。
- kustomize: 从 kustomization.yaml 文件中的指令生成一组 API 资源。

### 设置命令

- label: 更新资源上的标签。
- annotate: 更新一个或多个资源上的注解。
- completion: kubectl 命令自动补全。

### 其他命令

- api-resources: 打印受支持的 API 资源。
- api-versions: 打印受支持的 API 版本。
- config: 修改 Kubeconfig 文件。
- plugin: 提供与插件交互的实用程序。
- version: 打印当前上下文客户端和服务版本信息。

## Kubectl 管理应用生命周期

创建应用

```bash
kubectl create deployment myapp-deployment --image=ikubernetes/myapp:v1 --replicas=3
```

发布应用

```bash
kubectl expose deployment myapp-deployment --name=myapp-service --type=NodePort --port=8000 --target-port=80 --protocol=TCP
```

升级应用

```bash
kubectl set image deployment/myapp-deployment myapp=ikubernetes/myapp:v2
kubectl rollout status deployment myapp-deployment # 查看升级状态
```

回滚应用

```bash
kubectl rollout history deployment myapp-deployment # 查看版本发布历史记录
kubectl rollout history deployment myapp-deployment --revision=3 # 查看指定版本发布的详细信息
kubectl rollout undo deployment myapp-deployment # 回滚到上一个版本
kubectl rollout undo deployment myapp-deployment --to-revision=2 # 回滚到指定的版本
```

删除应用

```bash
kubectl delete deployments.apps myapp-deployment
kubectl delete service myapp-service
```

