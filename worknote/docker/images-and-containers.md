# 镜像和容器

## 镜像依赖技术

镜像相当于是一个 root 文件系统，除了提供容器运行时所需的程序、库、资源、配置等文件外，还包含一些为运行时准备的配置参数：例如匿名卷、环境变量、用户等。镜像不包含任何动态的数据，镜像内容在其构建之后就不会被改变。一个镜像可以被重复使用多次，创建无数个相同的容器，所以我们在前面说镜像是带有创建 Docker 容器命令说明的只读模板。镜像还可以是一种标准化的软件交付方式，镜像内包含基础运行环境和程序代码。

镜像的分层依赖于一系列的底层技术，例如联合文件系统（Union FileSystem）、写时复制（copy no write）。

**联合文件系统（Union FileSystem）**

联合文件系统可以将多个目录（也称为分支，因为联合文件系统支持对文件系统的修改作为一次提交来层层叠加）的内容联合挂载到一个目录下，而不修改目录的物理位置。联合文件系统还支持只读和可读写目录共存，这是实现镜像拥有只读层和可读写层的原理。联合文件系统是 Docker 镜像的基石，镜像的分层可以让不同容器之间共享资源。例如两个使用 Ubuntu:20.04 镜像创建的容器，一个容器安装了 Nginx，另一个容器安装了 Tomcat，那么这两个容器其实是共享 Ubuntu:20.04 镜像层，只有安装 Nginx 和 Tomcat 的那一层才是它们自己的改动层，联合文件系统在实现资源共享的同时提高了存储效率。

Docker 目前支持的联合文件系统有：overlay2、overlay、aufs、btrfs、vfs、devicemapper。

aufs 是 Docker 以前版本默认的存储驱动，如果 Linux 内核是 4.0 或者更高版本，并且使用 Docker Engine - Community，请使用新的 overlay2，它的性能比 aufs 存储驱动更好。

**写时复制（copy no write）**

我们已经知道 Docker 镜像是由多个只读层叠加构建的，那么在启动容器时，我们对容器的操作是如何被保存的呢？其实，Docker 启动时会加载镜像的只读层并在镜像层的顶部添加一个读写层，如果此时在容器中修改了一个已存在的文件，该文件将会从读写层下面的只读层复制到读写层并进行修改，该文件的只读版本仍然存在，但是容器已经无法看到存在于下层的这个文件了。只有被修改的文件才会被复制到读写层，写时复制最大限度减少了 I/O 和后续层的大小。

## 容器依赖技术

在宿主机上看，一个容器其实就是宿主机的一个进程，但是这个进程是和宿主机存在隔离的。容器内的进程只能看到自己 namespace 的“世界”，与宿主机上的其他进程互相无感知。主要是使用了 Linux 内核底层的 namespace 和  cgroup 技术。

**Namespace 资源隔离**

namespace 是 Linux 提供的一种由内核实现的隔离技术。是在 Unix 的 chroot 系统调用（通过修改根目录把用户监禁在一个特定目录下）的基础上，实现了六种 namespace 隔离机制。

| Namespace | 系统调用参数  | 隔离内容                   |
| --------- | ------------- | -------------------------- |
| UTS       | CLONE_NEWUTS  | 主机名和域名               |
| IPC       | CLONE_NEWIPC  | 共享内存、信号量、消息队列 |
| PID       | CLONE_NEWPID  | 进程号                     |
| Network   | CLONE_NEWNET  | 网络设备、网络协议栈、端口 |
| Mount     | CLONE_NEWNS   | 文件系统挂载点             |
| User      | CLONE_NEWUSER | 用户和用户组               |

**Cgroup 资源限制**

Cgroup（Control Group）是 Linux 内核的一个功能，用来限制、控制与分离一个进程组群的资源（例如 CPU、内存、磁盘 IO 等）。Cgroup 可以为系统中运行的进程分配资源，拒绝进程访问某些资源，还提供 Cgroup 配置的监控。

Cgroup 的主要作用有：

- Resource limitation: 限制资源使用，例如 CPU、内存、磁盘。
- Prioritization: 优先级控制，为进程组分配特定的 CPU（多核） 或者磁盘 IO 吞吐。
- Accounting: 统计资源使用量，CPU 使用时间、内存使用量等，按量计费非常有用。
- Control: 进程组控制，挂起或者恢复执行进程。

Cgroup 子系统：

| Cgroup 子系统 | 作用                                                         |
| ------------- | ------------------------------------------------------------ |
| blkio         | 为块设备设定 IO 限制，例如磁盘                               |
| cpu           | 使用调度程序提供对 CPU 的 Cgroup 任务访问                    |
| cpuacct       | 自动生成 cgroup 中任务所使用的 CPU 报告                      |
| cpuset        | 给 Cgroup 中的任务分配独立 CPU（多核）和内存节点             |
| memory        | 为 Cgroup 任务提供对 Memory 的限制                           |
| freezer       | 暂停和恢复 Cgroup 任务                                       |
| devices       | 允许或拒绝 Cgroup 任务对设备的访问                           |
| net_cls       | 标记网络数据包，可允许 Linux 流量控制程序识别从具体 Cgroup 中生成的数据包 |
| net_prio      | 设计网络流量的优先级                                         |
| hugetlb       | 主要针对于 HugeTLB 系统进行限制，这是一个大页文件系统        |

## 镜像和容器的操作

### 配置镜像加速

每一个开通了阿里云容器镜像服务的用户，都会有一个镜像加速地址。

```bash
[root@docker ~]# sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://265wemgl.mirror.aliyuncs.com"]
}
EOF
[root@docker ~]# sudo systemctl daemon-reload
[root@docker ~]# sudo systemctl restart docker
```

### 下载镜像

[Docker Hub](https://hub.docker.com/search?q=&type=image) 是 Docker 官方提供的公共镜像仓库，使用 docker pull 命令默认就是从这个仓库拉取镜像。拉取镜像的命令格式如下：

```bash
[root@docker ~]# docker pull [OPTIONS] NAME[:TAG|@DIGEST]
```

镜像名称后面可以跟上标签或者镜像摘要，不写的话 Docker 默认拉取 latest（最新版本）。如果要拉取某一个镜像，但是不知道仓库中是否有这个镜像，可以使用搜索查看，--filter 是根据条件对搜索结果进行过滤。

```bash
[root@docker ~]# docker search --filter STARS=100  nginx
NAME                          DESCRIPTION                                     STARS     OFFICIAL   AUTOMATED
nginx                         Official build of Nginx.                        15928     [OK]
jwilder/nginx-proxy           Automated Nginx reverse proxy for docker con…   2101                 [OK]
richarvey/nginx-php-fpm       Container running Nginx + PHP-FPM capable of…   820                  [OK]
jc21/nginx-proxy-manager      Docker container for managing Nginx proxy ho…   288
linuxserver/nginx             An Nginx container, brought to you by LinuxS…   160
tiangolo/nginx-rtmp           Docker image with Nginx using the nginx-rtmp…   147                  [OK]
jlesage/nginx-proxy-manager   Docker container for Nginx Proxy Manager        145                  [OK]
alfg/nginx-rtmp               NGINX, nginx-rtmp-module and FFmpeg from sou…   111                  [OK]
[root@docker ~]#
```

这里下载的是 ubuntu:20.04 的镜像，library/ubuntu 指的用户名/仓库名，library 则是官方默认的名字。

```bash
[root@docker ~]# docker pull ubuntu:20.04
20.04: Pulling from library/ubuntu
Digest: sha256:626ffe58f6e7566e00254b638eb7e0f3b11d4da9675088f4781a50ae288f3322
Status: Downloaded newer image for ubuntu:20.04
docker.io/library/ubuntu:20.04
[root@docker ~]#
```

### 查看镜像

我们可以列出下载的镜像信息，信息包含仓库名、标签、镜像 ID、创建时间以及所占的空间。

```bash
[root@docker ~]# docker image ls
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
nginx        latest    f652ca386ed1   5 days ago     141MB
ubuntu       20.04     ba6acccedd29   7 weeks ago    72.8MB
ubuntu       latest    ba6acccedd29   7 weeks ago    72.8MB
ubuntu       18.04     5a214d77f5d7   2 months ago   63.1MB
[root@docker ~]#
```

### 启动容器

下载好镜像之后，我们就能以镜像为基础去启动一个容器了。这里以 ubuntu:20.04 的镜像启动一个容器，并在容器中执行 date 命令后退出并删除容器，屏幕打印的信息与我们平时执行 date 命令一样，但是这个信息是执行容器内的 date 命令打印出来的。

```bash
[root@docker ~]# docker run --rm ubuntu:20.04 /bin/date
Wed Dec  8 09:34:46 UTC 2021
[root@docker ~]#
```

上面是以非交互式启动的容器，容器还可以交互式启动。其中，-t 是分配一个伪终端并绑定到容器的标准输入上，-i 是以交互式启动，就是让容器的标准输入保持打开。在交互模式下，用户创建容器之后自动进入到容器环境了，我们可以看到 ubuntu 容器也拥有自己的根目录结构。

```bash
[root@docker ~]# docker run -it ubuntu:20.04 /bin/bash
root@cc0a1a750941:/# ls
bin  boot  dev  etc  home  lib  lib32  lib64  libx32  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
[root@docker ~]#
```

但是更多时候，我们的容器都是后台运行，就是不把容器内的执行结果输出到宿主机上，通过 -d 参数实现。后台运行启动的容器，会返回一个唯一的容器 ID。

```bash
[root@docker ~]# docker run -d ubuntu:20.04 /bin/sh -c "while true; do echo 'hello docker' >> /var/log/docker.log; sleep 1; done"
20b03a8a8d7463efa2ad2cd045db654be27a83f4f499a9fb8df83436d2cfdc53
[root@docker ~]#
```

可以通过 docker container ls 命令来查看运行容器的信息，加上 -a 参数是显示所有容器。

```bash
[root@docker ~]# docker container ls
CONTAINER ID   IMAGE          COMMAND                  CREATED          STATUS          PORTS     NAMES
20b03a8a8d74   ubuntu:20.04   "/bin/sh -c 'while t…"   26 minutes ago   Up 26 minutes             flamboyant_booth
[root@docker ~]#
```

### 进入容器

我们使用 -d 参数创建的容器，默认会丢到后台去运行，但是很多时候我们需要进入到一个后台运行的容器进行某些操作，这时候就需要使用到 exec 命令了。

```bash
[root@docker ~]# docker exec -it flamboyant_booth bash
root@20b03a8a8d74:/# ls
bin  boot  dev  etc  home  lib  lib32  lib64  libx32  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
root@20b03a8a8d74:/#
```

如果仅使用 -i 参数，由于没有 -t 参数分配的伪终端，进入容器后没有 Linux 命令提示符，但是仍然可以执行命令并返回结果。所以一般 -it 参数一起使用。

```bash
[root@docker ~]# docker exec -i flamboyant_booth bash
date
Mon Dec 13 01:24:06 UTC 2021
pwd
/
```

我们使用 exec 命令进入容器，如果这个标准输入 exit 时，并不会导致容器停止。容器还在正常运行，只是这个标准输入断开了。可以按下 Ctrl + d 或者在容器命令行执行 exit 退出容器。

```bash
[root@docker ~]# docker exec -it flamboyant_booth bash
root@20b03a8a8d74:/# date
Mon Dec 13 01:31:49 UTC 2021
root@20b03a8a8d74:/# exit
```

### 停止容器

我们可以手动执行 docker container stop 命令停止容器。当然，容器内的应用程序运行结束时，容器也会自动退出。退出状态的容器需要使用 docker container ls -a 命令才能看到。我们还可以使用 docker container start 命令来启动容器，docker container restart 命令是将一个容器停止再重新启动。

```bash
[root@docker ~]# docker container ls -a
CONTAINER ID   IMAGE          COMMAND                  CREATED      STATUS      PORTS     NAMES
20b03a8a8d74   ubuntu:20.04   "/bin/sh -c 'while t…"   2 days ago   Up 2 days             flamboyant_booth
[root@docker ~]# docker container stop flamboyant_booth
flamboyant_booth
[root@docker ~]# docker container ls -a
CONTAINER ID   IMAGE          COMMAND                  CREATED      STATUS                       PORTS     NAMES
20b03a8a8d74   ubuntu:20.04   "/bin/sh -c 'while t…"   2 days ago   Exited (137) 2 seconds ago             flamboyant_booth
[root@docker ~]#
```

### 删除容器

容器是有生命周期的。因为运行结束而进入退出状态的容器，或者因为发布版本而被替换的容器，这些容器都不处于运行的状态，我们可以使用 docker container rm 命令来删除这些容器。如果要删除一个运行状态的容器，可以使用 -f 参数，docker 会发送 SIGKILL 信号停止容器进程并删除容器。

```bash
[root@docker ~]# docker container ls -a
CONTAINER ID   IMAGE          COMMAND                  CREATED        STATUS                      PORTS     NAMES
6ca17aec7f97   ubuntu:20.04   "bash date"              28 hours ago   Exited (126) 28 hours ago             condescending_bouman
20b03a8a8d74   ubuntu:20.04   "/bin/sh -c 'while t…"   3 days ago     Up 29 hours                           flamboyant_booth
[root@docker ~]# docker container rm 6ca17aec7f97
6ca17aec7f97
[root@docker ~]# docker container ls -a
CONTAINER ID   IMAGE          COMMAND                  CREATED      STATUS        PORTS     NAMES
20b03a8a8d74   ubuntu:20.04   "/bin/sh -c 'while t…"   4 days ago   Up 30 hours             flamboyant_booth
[root@docker ~]#
```

如果需要删除所有退出状态的容器，可以使用 docker container prune 命令一次性清理。

```bash
[root@docker ~]# docker container ls -a
CONTAINER ID   IMAGE          COMMAND                  CREATED          STATUS                      PORTS     NAMES
c38b5ecba22c   ubuntu:20.04   "/bin/bash -c pwd"       5 seconds ago    Exited (0) 3 seconds ago              gallant_torvalds
c69212a7de81   ubuntu:20.04   "/bin/bash -c date"      19 seconds ago   Exited (0) 17 seconds ago             quizzical_raman
20b03a8a8d74   ubuntu:20.04   "/bin/sh -c 'while t…"   4 days ago       Up 30 hours                           flamboyant_booth
[root@docker ~]# docker container prune
WARNING! This will remove all stopped containers.
Are you sure you want to continue? [y/N] y
Deleted Containers:
c38b5ecba22c24c15789a53b89a687ec7ecf918e2b4e42d3548d5c101cac54e7
c69212a7de811575b2dc7994059ba3bf18479312d18273c1e5f63e0685860696

Total reclaimed space: 0B
[root@docker ~]#
```

### 删除镜像

删除本地的镜像使用 docker image rm 命令，或者 docker rmi 命令。其中，可以使用镜像 ID、镜像名、摘要来指定要删除的镜像。下面我们删除 redis 镜像：

```bash
[root@docker ~]# docker image ls
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
redis        latest    aea9b698d7d1   11 days ago    113MB
nginx        latest    f652ca386ed1   11 days ago    141MB
centos       latest    5d0da3dc9764   2 months ago   231MB
[root@docker ~]# docker image rm redis:latest
Untagged: redis:latest
Untagged: redis@sha256:2f502d27c3e9b54295f1c591b3970340d02f8a5824402c8179dcd20d4076b796
Deleted: sha256:aea9b698d7d1d2fb22fe74868e27e767334b2cc629a8c6f9db8cc1747ba299fd
Deleted: sha256:beb6c508926e807f60b6a3816068ee3e2cece7654abaff731e4a26bcfebe04d8
Deleted: sha256:a5b5ed3d7c997ffd7c58cd52569d8095a7a3729412746569cdbda0dfdd228d1f
Deleted: sha256:ee76d3703ec1ab8abc11858117233a3ac8c7c5e37682f21a0c298ad0dc09a9fe
Deleted: sha256:60abc26bc7704070b2977b748ac0fd4ca94b818ed4ba1ef59ca8803e95920161
Deleted: sha256:6a2f1dcfa7455f60a810bb7c4786d62029348f64c4fcff81c48f8625cf0d995a
[root@docker ~]# docker image ls
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
nginx        latest    f652ca386ed1   11 days ago    141MB
centos       latest    5d0da3dc9764   2 months ago   231MB
[root@docker ~]#
```

### 备份迁移

**save 和 load**

docker save 命令可以保存一个或多个镜像，例如将本地的 centos 镜像和 ubuntu 镜像保存到 image.tar 文件中。

```bash
[root@docker ~]# docker save -o images.tar centos:latest ubuntu:latest
[root@docker ~]# ll -sh images.tar
300M -rw------- 1 root root 300M Dec 15 11:40 images.tar
[root@docker ~]#
```

docker load 命令用于将由 docker save 命令打包生成的 tar 文件载入到本地镜像。

```bash
[root@docker ~]# docker load -i images.tar
74ddd0ec08fa: Loading layer [==================================================>]  238.6MB/238.6MB
Loaded image: centos:latest
Loaded image: ubuntu:latest
[root@docker ~]#
```

**export 和 import**

docker export 命令可以保存 container 文件系统，例如将运行中的容器保存为 ubuntu.tar 文件。

```bash
[root@docker ~]# docker export 20b03a8a8d74 -o ubuntu.tar
```

docker import 命令用于将由 docker export 命令打包生成的 tar 文件载入到本地镜像。

```bash
[root@docker ~]# docker import ubuntu.tar ubuntu:1.0
sha256:bcead6020c0ca44be9d380d29e6cf1e5ed304e855f93858e897374ca7ec84734
[root@docker ~]#
```

docker save 命令保存的是镜像，docker export 命令保存的是容器。docker load 命令用来载入镜像包文件，docker import 命令用来载入容器包文件，但是两者都是将包文件载入到本地镜像。在载入镜像时，docker load 命令不能对镜像重命名，而 docker import 命令可以对镜像指定名称。

### 容器日志

后台运行的容器，应用程序的日志并不会打印出来。如果没有配置数据持久化，日志文件是存放在容器内的。但是我们不需要进入容器才能查看日志，我们可以使用 docker logs 命令实现。

```bash
[root@docker ~]# docker logs -f nginx
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2021/12/16 07:00:00 [notice] 1#1: using the "epoll" event method
2021/12/16 07:00:00 [notice] 1#1: nginx/1.20.2
2021/12/16 07:00:00 [notice] 1#1: built by gcc 10.2.1 20210110 (Debian 10.2.1-6)
2021/12/16 07:00:00 [notice] 1#1: OS: Linux 5.4.0-91-generic
2021/12/16 07:00:00 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2021/12/16 07:00:00 [notice] 1#1: start worker processes
2021/12/16 07:00:00 [notice] 1#1: start worker process 31
2021/12/16 07:00:00 [notice] 1#1: start worker process 32
```

### 资源控制

我们在启动容器的时候，可以控制容器对资源的使用。例如限制容器最多使用 500M 物理内存，物理内存 + 交换分区使用的总大小限制在 800M，并且禁用 OOM Killer。

```bash
docker container run -d --name "nginx" --memory="500M" --memory-swap="800M" --oom-kill-disable nginx:1.20
```

> **[info] 说明**
>
> --memory-swap 是物理内存加交换分区的总使用量限制，并且 --memory-swap 必须比 --memory 设置的要大，--memory 允许的最小值为 6M。
>
> 如果 --memory 设置为500M，--memory-swap 不设置或者设置为 0，则容器可使用和 --memory 一样多的交换分区 ，那么容器的内存和交换分区一共可以使用 1G。
>
> 想要禁止容器使用交换分区，需要把 --memory 和 --memory-swap 设置为相同的值，因为 --memory-swap 是物理内存加交换分区的总使用量限制。

对于 CPU 资源的控制，例如主机有 2 个 CPU，限制容器最多使用 1.5 个 CPU。还可以使用 --cpus=".5" 参数让容器总是使用 50% 的 CPU。

```bash
docker container run -d --name "nginx" --cpus="1.5" nginx:1.20
```

我们还可以限制容器使用特定的 CPU 或特定的核，例如主机有多个 CPU，则容器可以使用 CPU 编号（从 0 开始）加逗号分隔符来描述容器具体使用那个 CPU。

```bash
[root@docker ~]# docker container run -d --name "nginx" --cpuset-cpus="0,1" nginx:1.20
a242e04bff0c10ed6388001119e0d08d4f85a8c075b6f0e0e1c81fa87b195944
[root@docker ~]# docker inspect nginx | grep CpusetCpus
            "CpusetCpus": "0,1",
[root@docker ~]#
```

