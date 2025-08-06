# Dockerfile 简介

Docker 可以通过读取 Dockerfile 中的指令自动生成镜像。Dockerfile 其实是一个文本，其中包含用户可以在命令行上调用所有命令来构建镜像，使用 Docker 构建镜像是一个连续执行指令自动构建的过程。

## docker build 原理

docker build 命令根据 Dockerfile 文件和上下文去构建一个镜像。构建的上下文位置可以是指定的 PATH 或者 URL 。PATH 是本地文件系统上的目录，URL 是 Git 存储库的链接。

构建上下文是递归处理的，PATH 包含所有的子目录，URL 包含存储库及其子模块。这个例子展示了使用工作目录作为构建背景的构建命令 。

```bash
[root@docker ~]# docker build .
Sending build context to Docker daemon   2.56kB
```

该构建由 Docker 守护进程去运行，构建过程首先把整个 PATH 的上下文（递归）发送给 Docker 守护进程。一般构建镜像都从一个空目录开始，并且添加 Dockerfile 和构建所需的文件。

> **[warning] 警告**
>
> 不要使用 / 目录作为构建上下文的 PATH，因为这会将整个根目录的内容传输到 Docker 的守护进程。

## Dockerfile 常用指令

Dockerfile 指令不区分大小写但通常约定为大写，Docker 顺序运行 Dockerfile 中的指令，Dockerfile 必须以 FROM 指令开头（FROM 之前只能有 ARG 指令），Docker 将以 # 开头的行视为注释。

**FROM **

指定一个基础镜像，在其基础上执行 Dockerfile 指令，得到我们需要的镜像。Dockerfile 必须要有 FROM 指令且以 FROM 指令开头。主机上没有指定的基础镜像时会去 Docker Hub 拉取，任何有效的镜像地址都是可以被指定为基础镜像的，只是使用公共存储库的镜像更为方便。

**LABEL**

以键值对的方式为镜像添加标签，指定镜像的元数据。一个镜像可以有多个标签，基础镜像或者父镜像的标签会被继承，如果已存在的标签具有不一样的值，则最新的值将会覆盖旧的值。

**RUN**

执行当前镜像顶层中的任何命令并提交结果。RUN 指令有两种格式：

- shell 格式：`RUN <command>` 命令在 shell 中运行，默认情况下是由 Linux 的 `/bin/sh -c` 和 Windows 的 `cmd /S /C` 执行。
- exec 格式：`RUN ["executable", "param1", "param2"]` exec 表单不会调用 shell 去执行，可以指定 shell 或者可执行文件，exec 表单被解析为一个 JSON 数组，必须使用双引号。

Dockerfile 中的每个指令都会新建一层镜像，遵循 Dockerfile 的最佳实践，我们应该减少镜像层数避免镜像过于臃肿，在使用 RUN 指令时我们可以使用反斜杠 \ 把多个命令写成一行：

```dockerfile
RUN /bin/bash -c 'source $HOME/.bashrc; \
echo $HOME'
```

**COPY**

复制本地文件或目录并添加到容器文件系统的路径中。可以指定多个 < src > 资源，但是文件或目录的路径是相对于构建上下文的 PATH 开始的，< src > 路径必须位于构建的上下文中，我们不能 `COPY ../something /something`，因为 Docker 构建的第一步就是把整个 PATH 的上下文（递归）发送给 Docker 守护进程。

**ADD**

 COPY 只支持简单的复制文件或目录，而 ADD 支持复制文件、目录或远程 URL 文件。ADD 不同于 COPY 的是还支持复制 tar 归档文件时自动解压缩。COPY 和 ADD 在复制目录时都不复制目录本身，只复制目录的内容。

**ENV**

以键值对的形式指定环境变量，该键值对会存在于构建阶段中所有后续指令的环境中，并在容器运行时保持。

**USER**

指定运行镜像时的用户名（UID）或用户组（GID），以及 Dockerfile 中跟随它的任何 RUN、 CMD 和 ENTRYPOINT 指令。

**WORKDIR**

为 Dockerfile 中的任何 CMD、 ENTRYPOINT、 COPY 和 ADD 指令设置工作目录。如果 WORKDIR 路径不存在则会自动创建，即使 Dockerfile 后续的指令没有使用它。

**EXPOSE**

指定容器运行时监听的网络端口，可以指定端口是监听 TCP 还是 UDP，如果未指定协议则默认是 TCP。

**VOLUME**

声明容器中的目录作为匿名卷，自动挂载到本地的 `/var/lib/docker/volumes/` 目录（根据 Docker 的版本会有所不同 ）

> **[info] 说明**
>
> VOLUME 只能挂载到本地的 `/var/lib/docker/volumes/` 目录，而 docker run -v 命令可以指定挂载到本地的具体目录，VOLUME 不能指定挂载到本地的目录是因为这样会破坏容器的可移植性，毕竟每个人映射的本地目录不同。VOLUME 的设计只是为了在启动容器时 docker run -v 没有指定也能成功启动，而且数据不会被写到容器中。如果 VOLUME 声明了容器中的目录作为匿名卷，但是 docker run -v 启动容器时指定了不一样的目录，这时以 docker run -v 为准。

**CMD**

CMD 指令有三种形式：

- `CMD ["executable","param1","param2"]` （exec 表单）
- `CMD ["param1","param2"]` （作为 ENTRYPOINT 的默认参数）
- `CMD command param1 param2` （shell 形式表单）

CMD 主要为容器启动提供默认值。默认值可以是可执行文件加参数，也可以忽略可执行文件而提供执行的参数，但是这时需要指定 ENTRYPOINT 指令。Dockerfile 中只能有一条 CMD 指令。如果有多个 CMD 指令，则只有最后一个 CMD 指令生效。如果启动容器时指定了 docker run 的参数，那么 CMD 中指定的默认参数则被覆盖。

**ENTRYPOINT**

ENTRYPOINT 指令有两种形式：

- `ENTRYPOINT ["executable", "param1", "param2"]` （exec 表单）
- `ENTRYPOINT command param1 param2` （shell 形式）

ENTRYPOINT 把容器作为一个可执行文件去运行。只有 Dockerfile 中的最后一条 ENTRYPOINT 指令才有效。同时定义了 CMD 和 ENTRYPOINT 则 CMD 将作为 ENTRYPOINT 的默认参数。

> **[info] 说明**
>
> 当 docker run 启动容器时没有指定参数，CMD 将作为 ENTRYPOINT 的默认参数。当 docker run 启动容器时指定参数 `'hello world'` 则 CMD 的参数会 `'hello world'` 被覆盖，而执行 ENTRYPOINT +  `'hello world'` ，ENTRYPOINT 指令比 CMD 指令优先级更高。在执行 docker run 命令时指定 --entrypoint 参数可以覆盖 dockerfile 中的 ENTRYPOINT 指令。

## 构建镜像

创建 Dockerfile 文件以及构建所需的脚本。

```dockerfile
FROM openjdk:18-jdk-oraclelinux8

RUN microdnf install findutils git

ARG MAVEN_VERSION=3.8.6
ARG USER_HOME_DIR="/root"
ARG SHA=f790857f3b1f90ae8d16281f902c689e4f136ebe584aba45e4b1fa66c80cba826d3e0e52fdd04ed44b4c66f6d3fe3584a057c26dfcac544a60b301e6d0f91c26
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

COPY mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
COPY settings-docker.xml /usr/share/maven/ref/

ENTRYPOINT ["/usr/local/bin/mvn-entrypoint.sh"]
CMD ["mvn"]
```

执行 docker build 命令去构建镜像

```bash
[root@docker ~/dockerfile]# docker build -t maven:3.8.6 .
Sending build context to Docker daemon  6.144kB
Step 1/13 : FROM openjdk:18-jdk-oraclelinux8
18-jdk-oraclelinux8: Pulling from library/openjdk
f42059649055: Downloading [=============>                                     ]  10.92MB/41.97MB
67a9c63ed3ba: Downloading [=========================================>         ]  11.27MB/13.49MB
3719e81f67b1: Downloading [==>                                                ]  11.02MB/188.1MB
18-jdk-oraclelinux8: Pulling from library/openjdk
5f160c0f6cac: Pull complete
fb499df0377a: Pull complete
373b9e2b6c72: Pull complete
Digest: sha256:f2c01a7c961c1f9147995b6415ced7d96d4c83ce01c4e49452303b9e6bce9b0f
Status: Downloaded newer image for openjdk:18-jdk-oraclelinux8
 ---> b83a192caadf
Step 2/13 : RUN microdnf install findutils git
 ---> Running in e47de8dc1968
Downloading metadata...
Downloading metadata...
```

查看并运行我们构建的镜像。

```bash
[root@docker ~/dockerfile]# docker image ls
REPOSITORY   TAG                   IMAGE ID       CREATED              SIZE
maven        3.8.6                 0ec71ea6d286   About a minute ago   793MB
openjdk      18-jdk-oraclelinux8   b83a192caadf   5 days ago           464MB
[root@docker ~/dockerfile]# docker run -it maven:3.8.6 /bin/bash
bash-4.4# mvn -v
Apache Maven 3.8.6 (84538c9988a25aec085021c365c560670ad80f63)
Maven home: /usr/share/maven
Java version: 18.0.1.1, vendor: Oracle Corporation, runtime: /usr/java/openjdk-18
Default locale: en, platform encoding: UTF-8
OS name: "linux", version: "5.4.0-110-generic", arch: "amd64", family: "unix"
```

# Dockerfile 最佳实践

Docker 通过从 Dockerfile 读取指令来自动构建镜像—— Dockerfile 是一个文本文件，其中包含构建给定图像所需的所有命令。Docker 镜像由只读层组成，每层代表一个 Dockerfile 指令，每一层都在前一层的基础上变化。当你运行一个镜像并生成一个容器时，你将在底层之上添加一个新的可写层（“容器层”）。对正在运行的容器所做的所有更改（如写入新文件、修改现有文件和删除文件）都写入到可写容器层。

**创建临时的容器**

Dockerfile 定义的镜像应该尽可能生成短暂的容器。所谓的“短暂”，就是可以被停止和销毁的容器，然后用极小的配置和工作量去替换。

**建立上下文**

当你执行 docker build 命令时，当前工作目录被称为构建上下文。Dockerfile 一般就在当前目录下，或者也可以使用 -f 指定具体位置，但无论 Dockerfile 位于何处，执行 docker build 命令的当前目录的所有文件和目录都会递归发送到 Docker 守护进程。因此我们在构建镜像时应该为构建上下文创建一个目录，并把构建镜像所需的文件放入其中。

**通过 stdin 管道读入**

Docker 构建上下文可以通过 stdin 管道发送 Dockerfile 来构建镜像。通过 stdin 管道传输 Dockerfile 对于执行一次性构建非常有用，无需将 Dockerfile 写入磁盘，而且使用来自 stdin 的 Dockerfile 构建映像时不发送构建上下文到  Docker 守护进程，这在构建镜像时不需要复制文件到镜像中的场景下可能很有用。

```bash
echo -e 'FROM busybox\nRUN echo "hello world"' | docker build -
```

**使用 .dockerignore 文件**

要排除与构建无关的文件，支持与 `.gitignore` 文件相似的语法。

**使用多阶段构建**

使用多阶段构建可以大幅减少镜像的大小，而不是在减少中间层和文件上做努力。将编译代码和运行代码分两个阶段去做，第一个阶段把源代码编译为可执行的代码文件，第二个阶段引用第一个阶段得到的可执行代码文件然后运行代码。使用多阶段构建，最终运行代码的容器就不需要考虑构建代码所需的文件和编译环境。

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.16-alpine AS build

# Install tools required for project
# Run `docker build --no-cache .` to update dependencies
RUN apk add --no-cache git
RUN go get github.com/golang/dep/cmd/dep

# List project dependencies with Gopkg.toml and Gopkg.lock
# These layers are only re-built when Gopkg files are updated
COPY Gopkg.lock Gopkg.toml /go/src/project/
WORKDIR /go/src/project/
# Install library dependencies
RUN dep ensure -vendor-only

# Copy the entire project and build it
# This layer is rebuilt when a file changes in the project directory
COPY . /go/src/project/
RUN go build -o /bin/project

# This results in a single layer image
FROM scratch
COPY --from=build /bin/project /bin/project
ENTRYPOINT ["/bin/project"]
CMD ["--help"]
```

**避免安装不必要的包**

为了减少复杂性、依赖关系、文件大小和构建时间，避免安装额外的或不必要的包。

**分离应用程序**

每个容器应该只有一个关注点。将应用程序解耦为多个容器可以更容易的水平拓展和重用容器，例如一个 web 应用程序可能由三个独立的容器组成：web 应用程序、数据库、缓存，每个容器有自己独立的镜像，以分离的方式管理。虽然一个容器只运行一个进程是很好的经验法则，但不是硬性规定。规划好容器的应用程序，尽量保持容器的干净和模块化。如果容器互相依赖，可以使用 Docker 容器网络来进行通信。

**最小化图层数**

在旧版本的 Docker 中，最小化镜像中的层数以确保性能是非常重要的。为了减少这个限制，现在的版本已经得到改善：

- 只有 `RUN`，`COPY`，`ADD` 会创建镜像层。其他指令创建临时中间镜像，并且不增加构建的大小。
- 尽可能的使用多阶段构建，并且只将构建得到的 `artifacts`  复制到最终的镜像。

**排序多行参数**

只要有可能，就对多行参数进行字母数字的排序（例如安装多个软件包时）。有助于避免包的重复，使安装列表更容易更新、阅读、审查。

```dockerfile
RUN apt-get update && apt-get install -y \
  bzr \
  cvs \
  git \
  mercurial \
  subversion \
  && rm -rf /var/lib/apt/lists/*
```

**利用构建缓存**

构建镜像时，Docker 按照指定的顺序逐步执行 Dockerfile 中的指令。在检查每条指令时，Docker 在其缓存中寻找可以重用的现有镜像，而不是创建新的(重复的)镜像。不想在构建过程中使用缓存可以指定 `--no-cache=true`选项。如果想在构建过程中使用缓存，那么了解到什么时候可以、什么时候不可以匹配到镜像就很重要了。Docker 遵循的基本规则如下：

- 从已经在缓存中的父镜像开始，下一条指令将与从该基础镜像派生的所有子镜像进行比较，以查看是否使用完全相同的指令构建了其中一个子镜像。否则，缓存将失效。
- 对于 ADD 和 COPY 指令，镜像中的文件也会被检查，每个文件计算出一个校验值。文件的修改时间和最后访问时间不会被纳入校验的范围。在缓存查找过程中，会将校验和现有镜像中的校验值进行比较。如果文件有任何改变，例如内容和元数据，则缓存失效。
