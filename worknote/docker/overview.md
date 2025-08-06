# 概述

## Docker 是什么？

Docker 翻译过来就是“码头工人”，而它搬运的东西就是集装箱（Container），Container 里面存放的是不同类型的程序和代码。Docker 能够将应用程序和基础设施分开，以便我们实现程序在各个主流系统之间进行快速交付、测试和部署。以 Image 的方式交付程序可以实现标准化、可移植的优点，减少开发和生产中运行代码的差异。

Docker 属于容器技术的一种，但近几年来 Docker 已经火得成为了容器的代名词。早在 1979 年，Chroot jail 被用于“Change Root”，它被认为是最早的容器化技术之一，后来 FreeBSD Jail 于 2000 年在 FreeBSD OS 中引入，旨在为简单的 Chroot 文件隔离带来更多安全性。2013 年，Docker 推出了第一个版本，依赖 Linux 内核特性 namespace 和 Cgroup，实现操作系统级别虚拟化。

## 可以使用 Docker 做什么？

**快速、一致的交付应用程序**

开发人员使用容器可以使程序和服务在标准化环境中工作，从而缩短了开发生命周期。容器非常适合持续集成和持续部署（CI/CD）工作流。

工作中容器有以下场景：

- 开发人员在本地编写代码可以使用 Docker 容器与同事共享。
- 使用 Docker 将他们的程序推送到测试环境并执行自动化和测试。
- 发现 Bug 时，在开发环境进行修复，并重新部署到测试环境进行测试和验证。
- 测试完成后，为客户提供修复就把更新的镜像推送到生产环境。

**响应式部署和拓展**

Docker 容器可移植性非常高，可以运行在开发人员的本地电脑、虚拟机、数据中心的物理服务器、各种云提供商。

Docker 的轻量级特性可以让我们轻松的动态管理应用程序，根据业务的需求可以实时的拓展和删除。

**相同硬件条件下运行更多应用程序**

Docker 非常轻量和快速，操作系统级别的虚拟化，可以使 Docker 运行更多应用程序，Docker 非常适合高密度环境以及需要以更少资源完成更多任务的中小型部署。

## Docker Engine

Docker Engine 是用来运行和管理容器的核心程序，主要包含以下组件：

- 后台运行的守护进程 dockerd。
- 和 dockerd 进行交互的 REST API Server。
- 命令行 CLI 接口，和 REST API Server 进行交互（就是常用的 docker 命令）。

## Docker 架构

Docker 使用 C/S （客户端/服务端）架构。Docker 客户端与 Docker 守护进程通信，后者负责构建、运行、分发 Docker 容器。Docker 客户端和守护程序可以运行在同一系统上，你也可以将 Docker 客户端连接到远程 Docker 守护进程。Docker 客户端和守护进程使用 REST API 通过 UNIX 套接字或网络接口进行通信。另一个 Docker 客户端是 Docker Compose，它是使用一组容器组成的应用程序。

![](https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/docker-arch.png)

Docker Damon: dockerd，负责监听 Docker API 的请求和管理 Docker 对象，例如镜像、容器、网络和 volume。

Docker Client: docker，Docker Client 是用户和 Docker 交互的主要方式，诸如使用 docker run 此类命令时，client 会将这些命令发送到 dockerd 由 dockerd 去执行。

Image: 镜像，镜像是带有创建 Docker 容器命令说明的只读模板，通常，镜像基于另外的一些基础镜像并加上一些自定义的功能，例如我构建一个基于 Ubuntu 的镜像，并在这个镜像安装 Nginx，这样就构建了一个属于我们的镜像。

Registry: 镜像仓库，存储着我们构建的镜像。镜像仓库分为公有仓库和私有仓库，Docker Hub 是一个由 Docker 公司运行和管理的基于云的公有镜像仓库，Docker Hub 允许任何用户自由的发布和使用镜像，对于公司或者组织来说，通常使用的是内部的私有仓库，私有仓库的镜像仅允许内部人员使用。

Containers: 容器，容器是一个镜像的可运行实例，可以使用 Docker REST API 或者 CLI 来操作容器，容器的实质是系统上的一个进程，但与直接在宿主执行的进程不同，容器进程运行在属于自己的独立命名空间。因此容器可以拥有独立的文件系统、网络配置、进程空间，用户空间。

底层技术支持：Namespaces（隔离）、CGroups（资源限制）、UnionFS（联合文件系统）、COW（写时复制）。

## Docker 与虚拟机

在传统虚拟化中，Hypervisor 基于物理硬件进行虚拟化，每一个 VM 都包含一个操作系统、操作系统运行时所需的硬件虚拟文件、应用程序及其关联的库文件和依赖项。不同操作系统的虚拟机可以运行在同一台物理服务器上，每个虚拟机之间是操作系统级别的隔离。

<img src="https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/vm-docker.png" style="zoom:50%;" />

容器不是基于底层物理硬件进行的虚拟化，而是基于操作系统的虚拟化，因此每个单独的容器只包含应用程序及其关联的库文件和依赖项，这也是容器轻量快速的原因。因为所有容器都共享宿主机的内核和物理资源，并不是每个容器都包含一个操作系统，所有容器之间是进程级别的隔离。

<img src="https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/docker-vm.png" style="zoom:45.5%;" />

虚拟机基于物理硬件进行虚拟化，容器基于操作系统的虚拟化，这是虚拟机和容器最大的区别。容器虽然更加轻量快速，但是因为共享一个底层内核，因此容器与虚拟机在资源隔离方面有着先天的劣势，这也是目前容器技术暂时不会取代虚拟机模式的原因之一。虚拟机的每一个实例都是一个完整的操作系统，当虚拟机数量增加时会非常耗费系统的资源，这也是虚拟机的劣势。虚拟机和容器一样，都可以通过提高物理机的 CPU 和内存来获得创建更多实例的机会。然而，容器在未来会走得更远，因为它支持微服务架构，可以更精细的部署和拓展应用程序组件。