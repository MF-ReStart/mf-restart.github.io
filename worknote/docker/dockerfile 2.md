# dockerfile 简介

docker 可以通过读取 dockerfile 中的指令自动生成镜像。dockerfile 其实是一个文本，其中包含用户可以在命令行上调用所有命令来构建镜像，使用 docker 构建镜像是一个连续执行指令自动构建的过程。

## docker build 原理

docker build 命令根据 dockerfile 文件和上下文去构建一个镜像。构建的上下文位置可以是指定的 PATH 或者 URL 。PATH 是本地文件系统上的目录，URL 是 Git 存储库的链接。

构建上下文是递归处理的，PATH 包含所有的子目录，URL 包含存储库及其子模块。这个例子展示了使用工作目录的构建命令作为构建背景 。

```

```



## dockerfile 常用指令



# dockerfile 最佳实践

