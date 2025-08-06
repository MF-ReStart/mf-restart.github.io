# 概述

> **[info] 说明**
> 
> 此文档仅为个人的学习笔记，记录下来是为了以后遗忘时可以翻阅。最好的 Kubernetes 文档在 [kubernetes.io](https://kubernetes.io/zh/docs/home/)，请大家去官网学习！

## Kubernetes 是什么？

Kubernetes 是一个可移植的、可扩展的开源平台，用于管理容器化的工作负载和服务，可促进声明式配置和自动化。Kubernetes 拥有一个庞大且快速增长的生态系统。Kubernetes 的服务、支持和工具广泛可用。

名称 Kubernetes 源于希腊语，意为“舵手”或“飞行员”。Google 在 2014 年开源了 Kubernetes 项目， Kubernetes 建立在 [Google 在大规模运行生产工作负载方面拥有十几年的经验](https://research.google/pubs/pub43438) 的基础上，结合了社区中最好的想法和实践。

### 时光回溯

让我们回顾一下为什么 Kubernetes 如此有用。

**传统部署时代**：

早期，各个组织机构在物理服务器上运行应用程序。无法为物理服务器中的应用程序定义资源边界，这会导致资源分配问题。 例如，如果在物理服务器上运行多个应用程序，则可能会出现一个应用程序占用大部分资源的情况， 结果可能导致其他应用程序的性能下降。 一种解决方案是在不同的物理服务器上运行每个应用程序，但是由于资源利用不足而无法扩展， 并且维护许多物理服务器的成本很高。

**虚拟化部署时代：**

作为解决方案，引入了虚拟化。虚拟化技术允许你在单个物理服务器的 CPU 上运行多个虚拟机（VM）。 虚拟化允许应用程序在 VM 之间隔离，并提供一定程度的安全，因为一个应用程序的信息不能被另一应用程序随意访问。

虚拟化技术能够更好地利用物理服务器上的资源，并且因为可轻松地添加或更新应用程序而可以实现更好的可伸缩性，降低硬件成本等等。

每个 VM 是一台完整的计算机，在虚拟化硬件之上运行所有组件，包括其自己的操作系统。

**容器部署时代：**

容器类似于 VM，但是它们具有被放宽的隔离属性，可以在应用程序之间共享操作系统（OS）。 因此，容器被认为是轻量级的。容器与 VM 类似，具有自己的文件系统、CPU、内存、进程空间等。 由于它们与基础架构分离，因此可以跨云和 OS 发行版本进行移植。

容器因具有许多优势而变得流行起来。下面列出的是容器的一些好处：

- 敏捷应用程序的创建和部署：与使用 VM 镜像相比，提高了容器镜像创建的简便性和效率。
- 持续开发、集成和部署：通过快速简单的回滚（由于镜像不可变性），支持可靠且频繁的容器镜像构建和部署。
- 关注开发与运维的分离：在构建/发布时而不是在部署时创建应用程序容器镜像， 从而将应用程序与基础架构分离。
- 可观察性不仅可以显示操作系统级别的信息和指标，还可以显示应用程序的运行状况和其他指标信号。
- 跨开发、测试和生产的环境一致性：在便携式计算机上与在云中相同地运行。
- 跨云和操作系统发行版本的可移植性：可在 Ubuntu、RHEL、CoreOS、本地、 Google Kubernetes Engine 和其他任何地方运行。
- 以应用程序为中心的管理：提高抽象级别，从在虚拟硬件上运行 OS 到使用逻辑资源在 OS 上运行应用程序。
- 松散耦合、分布式、弹性、解放的微服务：应用程序被分解成较小的独立部分， 并且可以动态部署和管理 - 而不是在一台大型单机上整体运行。
- 资源隔离：可预测的应用程序性能。
- 资源利用：高效率和高密度。

### Kubernetes 能做什么？

容器是打包和运行应用程序的最好方式。在生产环境中，你需要管理运行应用程序的容器，并确保不会停机。 例如，如果一个容器发生故障，则需要启动另一个容器。如果由系统处理此行为，会不会更容易？

这就是 Kubernetes 来解决这些问题的方法！ Kubernetes 为你提供了一个可弹性运行分布式系统的框架。 Kubernetes 会满足你的扩展要求、故障转移、部署模式等。 例如，Kubernetes 可以轻松管理系统的 Canary 部署。

Kubernetes 为你提供：

- 服务发现和负载均衡

  Kubernetes 可以使用 DNS 名称或自己的 IP 地址公开容器，如果进入容器的流量很大， Kubernetes 可以负载均衡并分配网络流量，从而使部署稳定。

- 存储编排

  Kubernetes 允许你自动挂载你选择的存储系统，例如本地存储、公共云提供商等。

- 自动部署和回滚

  你可以使用 Kubernetes 描述已部署容器的所需状态，它可以以受控的速率将实际状态更改为期望状态。例如，你可以自动化 Kubernetes 来为你的部署创建新容器， 删除现有容器并将它们的所有资源用于新容器。

- 自动完成装箱计算

  Kubernetes 允许你指定每个容器所需 CPU 和内存（RAM）。 当容器指定了资源请求时，Kubernetes 可以做出更好的决策来管理容器的资源。

- 自我修复

  Kubernetes 重新启动失败的容器、替换容器、杀死不响应用户定义的运行状况检查的容器，并且在准备好服务之前不将其通告给客户端。

- 密钥与配置管理

  Kubernetes 允许你存储和管理敏感信息，例如密码、OAuth 令牌和 ssh 密钥。 你可以在不重建容器镜像的情况下部署和更新密钥和应用程序配置，也无需在堆栈配置中暴露密钥。

### Kubernetes 不是什么？

Kubernetes 不是传统的、包罗万象的 PaaS（平台即服务）系统。 由于 Kubernetes 在容器级别而不是在硬件级别运行，它提供了 PaaS 产品共有的一些普遍适用的功能， 例如部署、扩展、负载均衡、日志记录和监视。 但是，Kubernetes 不是单体系统，默认解决方案都是可选和可插拔的。 Kubernetes 提供了构建开发人员平台的基础，但是在重要的地方保留了用户的选择和灵活性。

Kubernetes：

- 不限制支持的应用程序类型。 Kubernetes 旨在支持极其多种多样的工作负载，包括无状态、有状态和数据处理工作负载。 如果应用程序可以在容器中运行，那么它应该可以在 Kubernetes 上很好地运行。
- 不部署源代码，也不构建你的应用程序。 持续集成(CI)、交付和部署（CI/CD）工作流取决于组织的文化和偏好以及技术要求。
- 不提供应用程序级别的服务作为内置服务，例如中间件（例如，消息中间件）、 数据处理框架（例如，Spark）、数据库（例如，mysql）、缓存、集群存储系统 （例如，Ceph）。这样的组件可以在 Kubernetes 上运行，并且/或者可以由运行在 Kubernetes 上的应用程序通过可移植机制（例如， [开放服务代理](https://openservicebrokerapi.org/)）来访问。

- 不要求日志记录、监视或警报解决方案。 它提供了一些集成作为概念证明，并提供了收集和导出指标的机制。
- 不提供或不要求配置语言/系统（例如 jsonnet），它提供了声明性 API， 该声明性 API 可以由任意形式的声明性规范所构成。
- 不提供也不采用任何全面的机器配置、维护、管理或自我修复系统。
- 此外，Kubernetes 不仅仅是一个编排系统，实际上它消除了编排的需要。 编排的技术定义是执行已定义的工作流程：首先执行 A，然后执行 B，再执行 C。 相比之下，Kubernetes 包含一组独立的、可组合的控制过程， 这些过程连续地将当前状态驱动到所提供的所需状态。 如何从 A 到 C 的方式无关紧要，也不需要集中控制，这使得系统更易于使用 且功能更强大、系统更健壮、更为弹性和可扩展。

## Kubernetes 组件

当你部署完 Kubernetes, 即拥有了一个完整的集群。

一个 Kubernetes 集群由一组被称作节点的机器组成。这些节点上运行 Kubernetes 所管理的容器化应用。集群具有至少一个工作节点。

工作节点托管作为应用负载的组件的 Pod 。控制平面管理集群中的工作节点和 Pod 。 为集群提供故障转移和高可用性，这些控制平面一般跨多主机运行，集群跨多个节点运行。

本文档概述了交付正常运行的 Kubernetes 集群所需的各种组件。

### 控制平面组件（Control Plane Components）

控制平面的组件对集群做出全局决策（比如调度），以及检测和响应集群事件（例如，当不满足部署的 `replicas` 字段时，启动新的 pod）。

控制平面组件可以在集群中的任何节点上运行。 然而，为了简单起见，设置脚本通常会在同一个计算机（一般使用 master 节点）上启动所有控制平面组件，并且不会在此计算机上运行用户容器。 

#### kube-apiserver 

API 服务器是 Kubernetes 控制面的组件， 该组件公开了 Kubernetes API。 API 服务器是 Kubernetes 控制面的前端。

Kubernetes API 服务器的主要实现是 kube-apiserver。 kube-apiserver 设计上考虑了水平伸缩，也就是说，它可通过部署多个实例进行伸缩。 你可以运行 kube-apiserver 的多个实例，并在这些实例之间平衡流量。

#### etcd

etcd 是兼具一致性和高可用性的键值数据库，可以作为保存 Kubernetes 所有集群数据的后台数据库。

你的 Kubernetes 集群的 etcd 数据库通常需要有个备份计划。

要了解 etcd 更深层次的信息，请参考 [etcd 文档](https://etcd.io/docs/)。

#### kube-scheduler

控制平面组件，负责监视新创建的、未指定运行节点（node）的 Pods，选择节点让 Pod 在上面运行。

调度决策考虑的因素包括单个 Pod 和 Pod 集合的资源需求、硬件/软件/策略约束、亲和性和反亲和性规范、数据位置、工作负载间的干扰和最后时限。

#### kube-controller-manager

在主节点上运行控制器的组件。

从逻辑上讲，每个控制器都是一个单独的进程， 但是为了降低复杂性，它们都被编译到同一个可执行文件，并在一个进程中运行。

这些控制器包括：

- 节点控制器（Node Controller）：负责在节点出现故障时进行通知和响应。

- 副本控制器（Replication Controller）：负责为系统中的每个副本控制器对象维护正确数量的 Pod。

- 端点控制器（Endpoints Controller）：填充端点(Endpoints)对象(即加入 Service 与 Pod)。

- 服务帐户和令牌控制器（Service Account & Token Controllers）：为新的命名空间创建默认帐户和 API 访问令牌。

### Node 组件

节点组件在每个节点上运行，维护运行的 Pod 并提供 Kubernetes 运行环境。

#### kubelet

一个在集群中每个节点（node）上运行的代理。 它保证容器（containers）都运行在 Pod 中。

kubelet 接收一组通过各类机制提供给它的 PodSpecs，确保这些 PodSpecs 中描述的容器处于运行状态且健康。 kubelet 不会管理不是由 Kubernetes 创建的容器。

#### kube-proxy

kube-proxy 是集群中每个节点上运行的网络代理， 实现 Kubernetes 服务（Service） 概念的一部分。

kube-proxy 维护节点上的网络规则。这些网络规则允许从集群内部或外部的网络会话与 Pod 进行网络通信。

如果操作系统提供了数据包过滤层并可用的话，kube-proxy 会通过它来实现网络规则。否则， kube-proxy 仅转发流量本身。

#### 容器运行时（Container Runtime）

容器运行环境是负责运行容器的软件。

Kubernetes 支持多个容器运行环境：Docker、 containerd、CRI-O 以及任何实现 [Kubernetes CRI (容器运行环境接口)](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-node/container-runtime-interface.md)。

### 插件（Addons）

插件使用 Kubernetes 资源（DaemonSet、 Deployment等）实现集群功能。 因为这些插件提供集群级别的功能，插件中命名空间域的资源属于 kube-system 命名空间。

#### DNS

尽管其他插件都并非严格意义上的必需组件，但几乎所有 Kubernetes 集群都应该有[集群 DNS](https://kubernetes.io/zh/docs/concepts/services-networking/dns-pod-service/)， 因为很多示例都需要 DNS 服务。

集群 DNS 是一个 DNS 服务器，和环境中的其他 DNS 服务器一起工作，它为 Kubernetes 服务提供 DNS 记录。

Kubernetes 启动的容器自动将此 DNS 服务器包含在其 DNS 搜索列表中。

#### Web 界面（仪表盘）

[Dashboard](https://kubernetes.io/zh/docs/tasks/access-application-cluster/web-ui-dashboard/) 是Kubernetes 集群的通用、基于 Web 的用户界面。 它使用户可以管理集群中运行的应用程序以及集群本身并进行故障排除。

#### Ingress Controller

为了让 Ingress 资源工作，集群必须有一个正在运行的 Ingress 控制器。

#### 容器资源监控

容器资源监控将关于容器的一些常见的时间序列度量值保存到一个集中的数据库中，并提供用于浏览这些数据的界面，参考 [Prometheus 项目](https://prometheus.io/) 结合 [Grafana 项目](https://grafana.com/)。

#### 集群层面日志

[集群层面日志](https://kubernetes.io/zh/docs/concepts/cluster-administration/logging/) 机制负责将容器的日志数据保存到一个集中的日志存储中，该存储能够提供搜索和浏览接口。

## Kubernetes API

Kubernetes 控制面的核心是 API 服务器。 API 服务器负责提供 HTTP API，以供用户、集群中的不同部分和集群外部组件相互通信。

Kubernetes API 使你可以查询和操纵 Kubernetes API 中对象（例如：Pod、Namespace、ConfigMap 和 Event）的状态。

大部分操作都可以通过 kubectl 命令行接口或类似 kubeadm 这类命令行工具来执行， 这些工具在背后也是调用 API。不过，你也可以使用 REST 调用来访问这些 API。

## 使用 Kubernetes 对象

### 理解 Kubernetes 对象

本页说明了 Kubernetes 对象在 Kubernetes API 中是如何表示的，以及如何在 `.yaml` 格式的文件中表示。

#### 理解 Kubernetes 对象

在 Kubernetes 系统中，Kubernetes 对象是持久化的实体。 Kubernetes 使用这些实体去表示整个集群的状态。特别地，它们描述了如下信息：

- 哪些容器化应用在运行（以及在哪些节点上运行）。
- 可以被应用使用的资源。
- 关于应用运行时表现的策略，比如重启策略、升级策略，以及容错策略。

Kubernetes 对象是 “目标性记录” —— 一旦创建对象，Kubernetes 系统将持续工作以确保对象存在。 通过创建对象，本质上是在告知 Kubernetes 系统，所需要的集群工作负载看起来是什么样子的， 这就是 Kubernetes 集群的期望状态（Desired State）。

操作 Kubernetes 对象 —— 无论是创建、修改，或者删除 —— 都需要使用 [Kubernetes API](https://kubernetes.io/zh/docs/concepts/overview/kubernetes-api)。 比如，当使用 kubectl 命令行接口时，CLI 会执行必要的 Kubernetes API 调用， 也可以在程序中使用 [客户端库](https://kubernetes.io/zh/docs/reference/using-api/client-libraries/)直接调用 Kubernetes API。

#### 对象规约（Spec）与状态（Status）

几乎每个 Kubernetes 对象包含两个嵌套的对象字段，它们负责管理对象的配置： 对象 `spec`（规约）和对象 `status`（状态） 。 对于具有 `spec` 的对象，你必须在创建对象时设置其内容，描述你希望对象所具有的特征： 期望状态（Desired State） 。

`status` 描述了对象的当前状态（Current State），它是由 Kubernetes 系统和组件设置并更新的。在任何时刻，Kubernetes [控制平面](https://kubernetes.io/zh/docs/reference/glossary/?all=true#term-control-plane) 都一直积极地管理着对象的实际状态，以使之与期望状态相匹配。

#### 描述 Kubernetes 对象

创建 Kubernetes 对象时，必须提供对象的规约，用来描述该对象的期望状态， 以及关于对象的一些基本信息（例如名称）。 当使用 Kubernetes API 创建对象时（或者直接创建，或者基于`kubectl`）， API 请求必须在请求体中包含 JSON 格式的信息。 大多数情况下，需要在 `.yaml` 文件中为 `kubectl` 提供这些信息。`kubectl` 在发起 API 请求时，会将这些信息转换成 JSON 格式。

#### 必需字段

在想要创建的 Kubernetes 对象对应的 `.yaml` 文件中，需要配置如下的字段：

- `apiVersion` - 创建该对象所使用的 Kubernetes API 的版本。
- `kind` - 想要创建的对象的类别。
- `metadata` - 帮助唯一性标识对象的一些数据，包括一个 `name` 字符串、UID 和可选的 `namespace`。

### Kubernetes 对象管理

#### 命令式命令

用命令式命令时，用户可以在集群中的活动对象上进行操作。用户将操作传给 `kubectl` 命令作为参数或标志。

这是开始或者在集群中运行一次性任务的最简单方法。因为这个技术直接在活动对象上操作，所以它不提供以前配置的历史记录。

通过创建 Deployment 对象来运行 nginx 容器的实例：

```bash
kubectl run nginx --image nginx
```

#### 命令式对象配置

在命令式对象配置中，kubectl 命令指定操作（创建，替换等），可选标志和至少一个文件名。指定的文件必须包含 YAML 或 JSON 格式的对象的完整定义。

创建配置文件中定义的对象：

```bash
kubectl create -f nginx.yaml
```

### 对象名称和 IDs

集群中的每一个对象都有一个名称来标识在同类资源中的唯一性。

每个 Kubernetes 对象也有一个 UID 来标识在整个集群中的唯一性。

比如，在同一个名字空间中有一个名为 myapp-1234 的 Pod, 但是可以命名一个 Pod 和一个 Deployment 同为 myapp-1234。

对于用户提供的非唯一性的属性，Kubernetes 提供了 标签（Labels）和 注解（Annotation）机制。

### 名字空间

Kubernetes 支持多个虚拟集群，它们底层依赖于同一个物理集群。 这些虚拟集群被称为名字空间。

#### 何时使用多个名字空间

名字空间适用于存在很多跨多个团队或项目的用户的场景。对于只有几到几十个用户的集群，根本不需要创建或考虑名字空间。当需要名称空间提供的功能时，请开始使用它们。

名字空间为名称提供了一个范围。资源的名称需要在名字空间内是唯一的，但不能跨名字空间。 名字空间不能相互嵌套，每个 Kubernetes 资源只能在一个名字空间中。

名字空间是在多个用户之间划分集群资源的一种方法（通过资源配额）。

不需要使用多个名字空间来分隔轻微不同的资源，例如同一软件的不同版本： 使用标签来区分同一名字空间中的不同资源。

#### 使用名字空间

名字空间的创建和删除在[名字空间的管理指南文档](https://kubernetes.io/zh/docs/tasks/administer-cluster/namespaces/)描述。

**说明：** 避免使用前缀 `kube-` 创建名字空间，因为它是为 Kubernetes 系统名字空间保留的。

##### 查看名字空间

你可以使用以下命令列出集群中现存的名字空间：

```bash
kubectl get namespace
```

Kubernetes 会创建四个初始名字空间：

- `default` 没有指明使用其它名字空间的对象所使用的默认名字空间。
- `kube-system` Kubernetes 系统创建对象所使用的名字空间。
- `kube-public` 这个名字空间是自动创建的，所有用户（包括未经过身份验证的用户）都可以读取它。 这个名字空间主要用于集群使用，以防某些资源在整个集群中应该是可见和可读的。 这个名字空间的公共方面只是一种约定，而不是要求。
- `kube-node-lease` 此名字空间用于与各个节点相关的租期（Lease）对象； 此对象的设计使得集群规模很大时节点心跳检测性能得到提升。

##### 为请求设置名字空间

要为当前请求设置名字空间，请使用 `--namespace` 参数。

例如：

```bash
kubectl run nginx --image=nginx --namespace=<名字空间名称>
kubectl get pods --namespace=<名字空间名称>
```

##### 设置名字空间偏好

你可以永久保存名字空间，以用于对应上下文中所有后续 kubectl 命令。

#### 名字空间和 DNS

当你创建一个服务 时， Kubernetes 会创建一个相应的 DNS 条目。

该条目的形式是 <服务名称>.<名字空间名称>.svc.cluster.local，这意味着如果容器只使用 <服务名称>，它将被解析到本地名字空间的服务。这对于跨多个名字空间（如开发、分级和生产） 使用相同的配置非常有用。如果你希望跨名字空间访问，则需要使用完全限定域名（FQDN）。

#### 并非所有对象都在名字空间中

大多数 kubernetes 资源（例如 Pod、Service、副本控制器等）都位于某些名字空间中。 但是名字空间资源本身并不在名字空间中。而且底层资源，例如 [节点](https://kubernetes.io/zh/docs/concepts/architecture/nodes/) 和持久化卷不属于任何名字空间。

查看哪些 Kubernetes 资源在名字空间中，哪些不在名字空间中：

```bash
# 位于名字空间中的资源
kubectl api-resources --namespaced=true

# 不在名字空间中的资源
kubectl api-resources --namespaced=false
```

### 标签和选择算符

标签（Labels）是附加到 Kubernetes 对象（比如 Pods）上的键值对。 标签旨在用于指定对用户有意义且相关的对象的标识属性，但不直接对核心系统有语义含义。 标签可以用于组织和选择对象的子集。标签可以在创建时附加到对象，随后可以随时添加和修改。 每个对象都可以定义一组键/值标签。每个键对于给定对象必须是唯一的。

#### 动机

标签使用户能够以松散耦合的方式将他们自己的组织结构映射到系统对象，而无需客户端存储这些映射。

服务部署和批处理流水线通常是多维实体（例如，多个分区或部署、多个发行序列、多个层，每层多个微服务）。 管理通常需要交叉操作，这打破了严格的层次表示的封装，特别是由基础设施而不是用户确定的严格的层次结构。

示例标签：

- `"release" : "stable"`, `"release" : "canary"`
- `"environment" : "dev"`, `"environment" : "qa"`, `"environment" : "production"`
- `"tier" : "frontend"`, `"tier" : "backend"`, `"tier" : "cache"`
- `"partition" : "customerA"`, `"partition" : "customerB"`
- `"track" : "daily"`, `"track" : "weekly"`

这些只是常用标签的例子; 你可以任意制定自己的约定。请记住，对于给定对象标签的键必须是唯一的。

#### 语法和字符集

标签是键值对。有效的标签键有两个段：可选的前缀和名称，用斜杠（/）分隔。 名称段是必需的，必须小于等于 63 个字符，以字母数字字符（[a-z0-9A-Z]）开头和结尾， 带有破折号（-），下划线（_），点（ .）和之间的字母数字。 前缀是可选的。如果指定，前缀必须是 DNS 子域：由点（.）分隔的一系列 DNS 标签，总共不超过 253 个字符， 后跟斜杠（/）。

如果省略前缀，则假定标签键对用户是私有的。 向最终用户对象添加标签的自动系统组件（例如 kube-scheduler、kube-controller-manager、 kube-apiserver、kubectl 或其他第三方自动化工具）必须指定前缀。

kubernetes.io/ 前缀是为 Kubernetes 核心组件保留的。

有效标签值必须为 63 个字符或更少，并且必须为空或以字母数字字符（[a-z0-9A-Z]）开头和结尾， 中间可以包含破折号（-）、下划线（_）、点（.）和字母或数字。

#### 标签选择算符

与名称和 UID 不同， 标签不支持唯一性。通常，我们希望许多对象携带相同的标签。

通过 标签选择算符，客户端/用户可以识别一组对象。标签选择算符是 Kubernetes 中的核心分组原语。

API 目前支持两种类型的选择算符：基于等值的 和 基于集合的。标签选择算符可以由逗号分隔的多个 需求 组成。 在多个需求的情况下，必须满足所有要求，因此逗号分隔符充当逻辑 与（&&）运算符。

空标签选择算符或者未指定的选择算符的语义取决于上下文， 支持使用选择算符的 API 类别应该将算符的合法性和含义用文档记录下来。

##### 基于等值的需求

基于等值 或 基于不等值 的需求允许按标签键和值进行过滤。 匹配对象必须满足所有指定的标签约束，尽管它们也可能具有其他标签。 可接受的运算符有 = 、 == 和 != 三种。 前两个表示相等（并且只是同义词），而后者表示不相等。例如：

```bash
environment = production
tier != frontend
```

##### 基于集合的需求

基于集合 的标签需求允许你通过一组值来过滤键。 支持三种操作符：in、notin 和 exists (只可以用在键标识符上)。例如：

```bash
environment in (production, qa)
tier notin (frontend, backend)
partition
!partition
```

- 第一个示例选择了所有键等于 environment 并且值等于 production 或者 qa 的资源。
- 第二个示例选择了所有键等于 tier 并且值不等于 frontend 或者 backend 的资源，以及所有没有 tier 键标签的资源。
- 第三个示例选择了所有包含了有 partition 标签的资源；没有校验它的值。
- 第四个示例选择了所有没有 partition 标签的资源；没有校验它的值。 类似地，逗号分隔符充当 与 运算符。因此，使用 partition 键（无论为何值）和 environment 不同于 qa 来过滤资源可以使用 partition, environment notin（qa) 来实现。

基于集合的标签选择算符是相等标签选择算符的一般形式，因为 environment=production 等同于 environment in（production）；!= 和 notin 也是类似的。

基于集合的要求可以与基于相等的要求混合使用。例如：partition in (customerA, customerB),environment!=qa。

### 注解

你可以使用 Kubernetes 注解为对象附加任意的非标识的元数据。客户端程序（例如工具和库）能够获取这些元数据信息。

##### 为对象附加元数据

你可以使用标签或注解将元数据附加到 Kubernetes 对象。 标签可以用来选择对象和查找满足某些条件的对象集合。 相反，注解不用于标识和选择对象。 注解中的元数据，可以很小，也可以很大，可以是结构化的，也可以是非结构化的，能够包含标签不允许的字符。

注解和标签一样，是键/值对：

```json
"metadata": {
  "annotations": {
    "key1" : "value1",
    "key2" : "value2"
  }
}
```

##### 语法和字符集

注解（Annotations）存储的形式是键/值对。有效的注解键分为两部分： 可选的前缀和名称，以斜杠（/）分隔。 名称段是必需项，并且必须在63个字符以内，以字母数字字符（[a-z0-9A-Z]）开头和结尾， 并允许使用破折号（-），下划线（_），点（.）和字母数字。 前缀是可选的。如果指定，则前缀必须是DNS子域：一系列由点（.）分隔的DNS标签， 总计不超过253个字符，后跟斜杠（/）。 如果省略前缀，则假定注解键对用户是私有的。 由系统组件添加的注解 （例如，kube-scheduler，kube-controller-manager，kube-apiserver，kubectl 或其他第三方组件），必须为终端用户添加注解前缀。

kubernetes.io/ 和 k8s.io/ 前缀是为 Kubernetes 核心组件保留的。

例如，下面是一个 Pod 的配置文件，其注解中包含 imageregistry:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: annotations-demo
  annotations:
    imageregistry: "https://hub.docker.com/"
spec:
  containers:
  - name: nginx
    image: nginx:1.7.9
    ports:
    - containerPort: 80
```

### 字段选择器

字段选择器（Field selectors）允许你根据一个或多个资源字段的值 [筛选 Kubernetes 资源](https://kubernetes.io/zh/docs/concepts/overview/working-with-objects/kubernetes-objects)。 下面是一些使用字段选择器查询的例子：

- `metadata.name=my-service`
- `metadata.namespace!=default`
- `status.phase=Pending`

下面这个 kubectl 命令将筛选出 `status.phase` 字段值为 `Running` 的所有 Pod：

```bash
kubectl get pods --field-selector status.phase=Running
```

##### 支持的字段

你可在字段选择器中使用 =、==和 != （= 和 == 的意义是相同的）操作符。 例如，下面这个 kubectl 命令将筛选所有不属于 default 命名空间的 Kubernetes 服务：

```bash
kubectl get services  --all-namespaces --field-selector metadata.namespace!=default
```

##### 链式选择器

同标签和其他选择器一样， 字段选择器可以通过使用逗号分隔的列表组成一个选择链。 下面这个 kubectl 命令将筛选 status.phase 字段不等于 Running 同时 spec.restartPolicy 字段等于 Always 的所有 Pod：

```bash
kubectl get pods --field-selector=status.phase!=Running,spec.restartPolicy=Always
```

##### 多种资源类型

你能够跨多种资源类型来使用字段选择器。 下面这个 kubectl 命令将筛选出所有不在 default 命名空间中的 StatefulSet 和 Service：

```bash
kubectl get statefulsets,services --all-namespaces --field-selector metadata.namespace!=default
```

## Kubernetes 架构

### 节点

Kubernetes 通过将容器放入在节点（Node）上运行的 Pod 中来执行你的工作负载。 节点可以是一个虚拟机或者物理机器，取决于所在的集群配置。 每个节点包含运行 Pods 所需的服务， 这些 Pods 由控制面负责管理。

通常集群中会有若干个节点；而在一个学习用或者资源受限的环境中，你的集群中也可能只有一个节点。

节点上的组件包括 kubelet、 容器运行时以及 kube-proxy。

#### 管理

向 API 服务器添加节点的方式主要有两种：

1. 节点上的 kubelet 向控制面执行自注册。
2. 你，或者别的什么人，手动添加一个 Node 对象。

在你创建了 Node 对象或者节点上的 kubelet 执行了自注册操作之后， 控制面会检查新的 Node 对象是否合法。例如，如果你使用下面的 JSON 对象来创建 Node 对象：

```json
{
  "kind": "Node",
  "apiVersion": "v1",
  "metadata": {
    "name": "10.240.79.157",
    "labels": {
      "name": "my-first-k8s-node"
    }
  }
}
```

Kubernetes 会在内部创建一个 Node 对象作为节点的表示。Kubernetes 检查 kubelet 向 API 服务器注册节点时使用的 metadata.name 字段是否匹配。 如果节点是健康的（即所有必要的服务都在运行中），则该节点可以用来运行 Pod。 否则，直到该节点变为健康之前，所有的集群活动都会忽略该节点。

### 控制面到节点通信

本文列举控制面节点（确切说是 API 服务器）和 Kubernetes 集群之间的通信路径。 目的是为了让用户能够自定义他们的安装，以实现对网络配置的加固，使得集群能够在不可信的网络上（或者在一个云服务商完全公开的 IP 上）运行。

#### 节点到控制面

Kubernetes 采用的是中心辐射型（Hub-and-Spoke）API 模式。 所有从集群（或所运行的 Pods）发出的 API 调用都终止于 apiserver（其它控制面组件都没有被设计为可暴露远程服务）。 apiserver 被配置为在一个安全的 HTTPS 端口（443）上监听远程连接请求， 并启用一种或多种形式的客户端身份认证机制。 一种或多种客户端鉴权机制应该被启用， 特别是在允许使用匿名请求 或服务账号令牌的时候。

应该使用集群的公共根证书开通节点，这样它们就能够基于有效的客户端凭据安全地连接 apiserver。 一种好的方法是以客户端证书的形式将客户端凭据提供给 kubelet。 请查看 kubelet TLS 启动引导 以了解如何自动提供 kubelet 客户端证书。

想要连接到 apiserver 的 Pod 可以使用服务账号安全地进行连接。 当 Pod 被实例化时，Kubernetes 自动把公共根证书和一个有效的持有者令牌注入到 Pod 里。 kubernetes 服务（位于所有名字空间中）配置了一个虚拟 IP 地址，用于（通过 kube-proxy）转发 请求到 apiserver 的 HTTPS 末端。

控制面组件也通过安全端口与集群的 apiserver 通信。

这样，从集群节点和节点上运行的 Pod 到控制面的连接的缺省操作模式即是安全的， 能够在不可信的网络或公网上运行。

#### 控制面到节点

从控制面（apiserver）到节点有两种主要的通信路径。 第一种是从 apiserver 到集群中每个节点上运行的 kubelet 进程。 第二种是从 apiserver 通过它的代理功能连接到任何节点、Pod 或者服务。

##### API 服务器到 kubelet

从 apiserver 到 kubelet 的连接用于：

- 获取 Pod 日志。
- 挂接（通过 kubectl）到运行中的 Pod。
- 提供 kubelet 的端口转发功能。

这些连接终止于 kubelet 的 HTTPS 末端。 默认情况下，apiserver 不检查 kubelet 的服务证书。这使得此类连接容易受到中间人攻击， 在非受信网络或公开网络上运行也是 不安全的。

为了对这个连接进行认证，使用 --kubelet-certificate-authority 标志给 apiserver 提供一个根证书包，用于 kubelet 的服务证书。

如果无法实现这点，又要求避免在非受信网络或公共网络上进行连接，可在 apiserver 和 kubelet 之间使用 SSH 隧道。

最后，应该启用 kubelet 用户认证和/或鉴权 来保护 kubelet API。

##### apiserver 到节点、Pod 和服务

从 apiserver 到节点、Pod 或服务的连接默认为纯 HTTP 方式，因此既没有认证，也没有加密。 这些连接可通过给 API URL 中的节点、Pod 或服务名称添加前缀 `https:` 来运行在安全的 HTTPS 连接上。 不过这些连接既不会验证 HTTPS 末端提供的证书，也不会提供客户端证书。 因此，虽然连接是加密的，仍无法提供任何完整性保证。 这些连接目前还不能安全地在非受信网络或公共网络上运行。

## 工作负载

工作负载是在 Kubernetes 上运行的应用程序。

无论你的负载是单一组件还是由多个一同工作的组件构成，在 Kubernetes 中你可以在一组 Pods 中运行它。 在 Kubernetes 中，Pod 代表的是集群上处于运行状态的一组容器。

Kubernetes Pods 有确定的生命周期。 例如，一旦某 Pod 在你的集群中运行，Pod 运行所在的节点出现致命错误时， 所有该节点上的 Pods 都会失败。Kubernetes 将这类失败视为最终状态：即使该节点后来恢复正常运行，你也需要创建新的 Pod 来恢复应用。

不过，为了让用户的日子略微好过一些，你并不需要直接管理每个 Pod。 相反，你可以使用负载资源来替你管理一组 Pods。 这些资源配置控制器来确保合适类型的、处于运行状态的 Pod 个数是正确的，与你所指定的状态相一致。

Kubernetes 提供若干种内置的工作负载资源：

- Deployment 和 ReplicaSet （替换原来的资源 ReplicationController）。 Deployment 很适合用来管理你的集群上的无状态应用，Deployment 中的所有 Pod 都是相互等价的，并且在需要的时候被换掉。
- StatefulSet 让你能够运行一个或者多个以某种方式跟踪应用状态的 Pods。 例如，如果你的负载会将数据作持久存储，你可以运行一个 StatefulSet，将每个 Pod 与某个 PersistentVolume 对应起来。你在 StatefulSet 中各个 Pod 内运行的代码可以将数据复制到同一 StatefulSet 中的其它 Pod 中以提高整体的服务可靠性。
- DaemonSet 定义提供节点本地支撑设施的 Pods。这些 Pods 可能对于你的集群的运维是非常重要的，例如作为网络链接的辅助工具或者作为网络插件的一部分等等。每次你向集群中添加一个新节点时，如果该节点与某 DaemonSet 的规约匹配，则控制面会为该 DaemonSet 调度一个 Pod 到该新节点上运行。
- Job 和 CronJob。 定义一些一直运行到结束并停止的任务。Job 用来表达的是一次性的任务，而 CronJob 会根据其时间规划反复运行。

### pods

Pod 是可以在 Kubernetes 中创建和管理的、最小的可部署的计算单元。

Pod（就像在鲸鱼荚或者豌豆荚中）是一组（一个或多个） 容器； 这些容器共享存储、网络、以及怎样运行这些容器的声明。 Pod 中的内容总是并置（colocated）的并且一同调度，在共享的上下文中运行。 Pod 所建模的是特定于应用的“逻辑主机”，其中包含一个或多个应用容器， 这些容器是相对紧密的耦合在一起的。 在非云环境中，在相同的物理机或虚拟机上运行的应用类似于在同一逻辑主机上运行的云应用。

除了应用容器，Pod 还可以包含在 Pod 启动期间运行的 Init 容器。 你也可以在集群中支持临时性容器 的情况外，为调试的目的注入临时性容器。

#### 什么是 Pod？

说明： 除了 Docker 之外，Kubernetes 支持很多其他容器运行时（容器运行时是负责运行容器的软件）， Docker 是最有名的运行时， 使用 Docker 的术语来描述 Pod 会很有帮助。

Pod 的共享上下文包括一组 Linux 名字空间、控制组（cgroup）和可能一些其他的隔离方面，即用来隔离 Docker 容器的技术。 在 Pod 的上下文中，每个独立的应用可能会进一步实施隔离。

就 Docker 概念的术语而言，Pod 类似于共享名字空间和文件系统卷的一组 Docker 容器。

#### 使用 Pod

通常你不需要直接创建 Pod，甚至单实例 Pod。 相反，你会使用诸如 Deployment 或 Job 这类工作负载资源来创建 Pod。如果 Pod 需要跟踪状态， 可以考虑 StatefulSet 资源。

Kubernetes 集群中的 Pod 主要有两种用法：

- 运行单个容器的 Pod。“每个 Pod 一个容器” 模型是最常见的 Kubernetes 用例； 在这种情况下，可以将 Pod 看作单个容器的包装器，并且 Kubernetes 直接管理 Pod，而不是容器。
- 运行多个协同工作的容器的 Pod。 Pod 可能封装由多个紧密耦合且需要共享资源的共处容器组成的应用程序。 这些位于同一位置的容器可能形成单个内聚的服务单元 —— 一个容器将文件从共享卷提供给公众， 而另一个单独的 “挂斗”（sidecar）容器则刷新或更新这些文件。 Pod 将这些容器和存储资源打包为一个可管理的实体。

说明： 将多个并置、同管的容器组织到一个 Pod 中是一种相对高级的使用场景。 只有在一些场景中，容器之间紧密关联时你才应该使用这种模式。

每个 Pod 都旨在运行给定应用程序的单个实例。如果希望横向扩展应用程序（例如，运行多个实例以提供更多的资源），则应该使用多个 Pod，每个实例使用一个 Pod。 在 Kubernetes 中，这通常被称为副本（Replication）。 通常使用一种工作负载资源及其控制器来创建和管理一组 Pod 副本。

### 工作负载资源

工作负载是指在 Kubernetes 上运行的应用程序，一个 pod 可以运行一个或多个工作负载。工作负载资源是用来管理一组 pod 的，确保这些被管理的 pod ，处于我们期望的运行状态。

#### Deployments

一个 Deployment 为 Pods （pod 表示集群上正在运行的一组容器） 和 ReplicaSets （下一代副本控制器）提供声明式的更新能力。

你负责描述 Deployment 中的目标状态，而 Deployment 控制器（Controller）以受控速率更改实际状态， 使其变为期望状态。你可以定义 Deployment 以创建新的 ReplicaSet，或删除现有 Deployment， 并通过新的 Deployment 收养其资源。

#### ReplicaSet

ReplicaSet 的目的是维护一组在任何时候都处于运行状态的 Pod 副本的稳定集合。 因此，它通常用来保证给定数量的、完全相同的 Pod 的可用性。

#### StatefulSets

StatefulSet 是用来管理有状态应用的工作负载 API 对象。

StatefulSet 用来管理某 Pod 集合的部署和扩缩， 并为这些 Pod 提供持久存储和持久标识符。

和 Deployment 类似， StatefulSet 管理基于相同容器规约的一组 Pod。但和 Deployment 不同的是， StatefulSet 为它们的每个 Pod 维护了一个有粘性的 ID。这些 Pod 是基于相同的规约来创建的， 但是不能相互替换：无论怎么调度，每个 Pod 都有一个永久不变的 ID。

#### DaemonSet

DaemonSet 确保全部（或者某些）节点上运行一个 Pod 的副本。 当有节点加入集群时， 也会为他们新增一个 Pod 。 当有节点从集群移除时，这些 Pod 也会被回收。删除 DaemonSet 将会删除它创建的所有 Pod。

DaemonSet 的一些典型用法：

- 在每个节点上运行集群守护进程。
- 在每个节点上运行日志收集守护进程。
- 在每个节点上运行监控守护进程。

一种简单的用法是为每种类型的守护进程在所有的节点上都启动一个 DaemonSet。 一个稍微复杂的用法是为同一种守护进程部署多个 DaemonSet；每个具有不同的标志， 并且对不同硬件类型具有不同的内存、CPU 要求。

#### Jobs

Job 会创建一个或者多个 Pods，并将继续重试 Pods 的执行，直到指定数量的 Pods 成功终止。 随着 Pods 成功结束，Job 跟踪记录成功完成的 Pods 个数。 当数量达到指定的成功个数阈值时，任务（即 Job）结束。 删除 Job 的操作会清除所创建的全部 Pods。

一种简单的使用场景下，你会创建一个 Job 对象以便以一种可靠的方式运行某 Pod 直到完成。 当第一个 Pod 失败或者被删除（比如因为节点硬件失效或者重启）时，Job 对象会启动一个新的 Pod。

#### CronJob

CronJob 创建基于时间调度的 Jobs。

一个 CronJob 对象就像 crontab (cron table) 文件中的一行。 它用 Cron 格式进行编写， 并周期性地在给定的调度时间执行 Job。

#### ReplicationController

ReplicationController 确保在任何时候都有特定数量的 Pod 副本处于运行状态。 换句话说，ReplicationController 确保一个 Pod 或一组同类的 Pod 总是可用的。

#### ReplicationController 的替代方案

**ReplicaSet**
ReplicaSet 是下一代 ReplicationController， 支持新的基于集合的标签选择算符。 它主要被 Deployment 用来作为一种编排 Pod 创建、删除及更新的机制。 请注意，我们推荐使用 Deployment 而不是直接使用 ReplicaSet，除非 你需要自定义更新编排或根本不需要更新。

**Deployment （推荐）**

Deployment 是一种更高级别的 API 对象， 它以类似于 kubectl rolling-update 的方式更新其底层 ReplicaSet 及其 Pod。 如果你想要这种滚动更新功能，那么推荐使用 Deployment，因为与 kubectl rolling-update 不同， 它们是声明式的、服务端的，并且具有其它特性。
