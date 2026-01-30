# 数据持久化

由于容器的镜像分层机制，我们在容器里面创建文件或者修改文件，结果都会保存在容器的可读写层中，一旦容器被销毁，那么这个可读写层也会随着容器销毁而消失。而且当一个容器需要和其他容器的读写层进行数据交互时，也会显得非常困难。于是在容器数据持久化方面，Docker 为我们提供了三种持久化的方式。

## bind mount 持久化方式

bind mount 本质上是将宿主机上的文件或目录挂载到容器中供容器使用，文件或目录由其主机上的绝对路径或者相对路径引用，这跟 volume 持久化方式由 Docker 统一管理存储目录不一样。如果宿主机上目录不存在则会自动创建，但不能创建文件。如果容器目录非空，则容器目录现有内容会被宿主机目录内容所隐藏，容器内的数据要卸除挂载后才会恢复。

将宿主机上的 /data/nginx 目录挂载到容器中的 /usr/share/nginx/html 目录，容器内的 nginx 默认页面会被隐藏，即使宿主机的目录为空。

```bash
docker container run -itd --name "nginx" --volume /data/nginx:/usr/share/nginx/html nginx:1.20

docker container run -itd --name "nginx" --mount type=bind,source=/data/nginx,target=/usr/share/nginx/html nginx:1.20
```

> **[info] 说明**
>
> 关于 --volume（-v） 参数和 --mount 参数的区别，最初 --volume 和 -v 参数用于独立容器，--mount 用于集群服务。--volume 和 -v 参数如果源路径不存在则会自动创建，--mount 源路径不存在则会报错。但是在 Docker 17.06 开始，官方推荐使用 --mount 去进行挂载，因为只有 --mount 支持指定卷驱动类型，同时语法更明确和易于理解，新用户都应使用 --mount 参数。

bind mount 无法使用 docker cli 命令直接管理，我们可以在容器的详细信息里看到挂载的内容。

```bash
[root@docker ~]# docker container inspect nginx | grep Mounts
"Mounts": [
            {
                "Type": "bind",
                "Source": "/data/nginx",
                "Destination": "/usr/share/nginx/html",
                "Mode": "",
                "RW": true,
                "Propagation": "rprivate"
            }
        ]
```

bind mount 默认挂载开启了 rw 模式，如果容器只需要读访问权限，我们也可以将目录挂载为只读。

```bash
[root@docker ~]# docker container run -itd --name "nginx" --mount type=bind,source=/data/nginx,target=/usr/share/nginx/html,readonly nginx:1.20
a5c5f217e2557f58e83276ba9be9fd75e6127b34e918199d379b7734dac5806f
[root@docker ~]# docker exec -it nginx /bin/bash
root@a5c5f217e255:/# echo 'test' > /usr/share/nginx/html/index.html
bash: /usr/share/nginx/html/index.html: Read-only file system
root@a5c5f217e255:/#
```

## volume 持久化方式

volume 由 Docker 负责管理，可以使用 docker volume create 命令创建 volume。Docker 创建的 volume 本质上还是宿主机文件系统中的一个目录（可以使用 docker volume inspect 命令查看目录路径），一个 volume 可以供一个或多个容器一同使用，即使没有容器使用此 volume 它也不会自动删除，除非用户明确删除它。如果是用户使用命令创建的则需要指定名称，如果是 container 和 service 启动的隐式创建，Docker 则会为它分配一个宿主机范围内唯一的名字。通过使用第三方提供的 volume driver，用户可以将数据持久化到远程主机或者云存储中，也就是说存储空间可以不由宿主机提供。

管理 volume 资源使用 docker volume 命令。

```bash
# 创建 volume
docker volume create nginx_volumes

# 查看 volume
docker volume ls

# 查看 volume 信息
docker volume inspect nginx_volumes

# 删除 volumes
docker volume rm nginx_volumes
```

可以先创建好 volume，启动容器时再指定 volume，也可以在启动容器时直接指定 volume，如果不存在则自动创建 volume。

```bash
docker container run -itd --name "nginx" -p 80:80 --volume nginx_volumes:/usr/share/nginx/html nginx:1.20

docker container run -itd --name "nginx" -p 80:80 --mount source=nginx_volumes,target=/usr/share/nginx/html nginx:1.20 
```

> **[info] 说明**
>
> 关于 --volume（-v） 参数和 --mount 参数的区别，最初 --volume 和 -v 参数用于独立容器，--mount 用于集群服务。--volume 和 -v 参数如果源路径不存在则会自动创建，--mount 源路径不存在则会报错。但是在 Docker 17.06 开始，官方推荐使用 --mount 去进行挂载，因为只有 --mount 支持指定卷驱动类型，同时语法更明确和易于理解，新用户都应使用 --mount 参数。

我们能够看到容器内的文件已经被映射到宿主机的 volume 目录上了。

```bash
[root@docker ~]# docker volume inspect nginx_volumes
[
    {
        "CreatedAt": "2021-12-21T11:12:19+08:00",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/nginx_volumes/_data",
        "Name": "nginx_volumes",
        "Options": null,
        "Scope": "local"
    }
]
[root@docker ~]# ll /var/lib/docker/volumes/nginx_volumes/_data
total 16
drwxr-xr-x 2 root root 4096 Dec 21 11:12 ./
drwx-----x 3 root root 4096 Dec 21 11:12 ../
-rw-r--r-- 1 root root  494 Nov 16 22:44 50x.html
-rw-r--r-- 1 root root  612 Nov 16 22:44 index.html
[root@docker ~]#
```

volume 持久化方式宿主机和容器的文件映射，当宿主机 volume 目录非空时以宿主机的文件为准，当宿主机 volume 目录为空时将会把容器内的数据复制到宿主机后再以宿主机为准。

## tmpfs 持久化方式

tmpfs 挂载是临时的，并且仅保留在宿主机的内存中。当容器停止时，tmpfs 挂载将被删除，而且 tmpfs 挂载不能在多个容器之间共享。我们可以使用 --tmpfs 或者 --mount 参数创建 tmpfs 挂载。

```bash
docker container run -itd --name "nginx" -p 80:80 --tmpfs /usr/share/nginx/html nginx:1.20

docker container run -itd --name "nginx" -p 80:80 --mount type=tmpfs,destination=/usr/share/nginx/html nginx:1.20
```

> **[info] 说明**
>
> 关于 --tmpfs 和 --mount 参数，--tmpfs 参数不允许指定任何可配置选项，需要可配置选项必须使用 --mount。同时 --mount 参数的语法更明确和易于理解，推荐使用 --mount 参数。

通过 tmpfs 挂载还有两个可选参数，但是在指定可选参数时，必须使用 --mount 标志，因为 --tmpfs 不支持。

| 可选参数   | 作用                                              |
| ---------- | ------------------------------------------------- |
| tmpfs-size | 指定 tmpfs 挂载的大小，以字节为单位，默认无限制。 |
| tmpfs-mode | 八进制中 tmpfs 的文件模式，默认为 1777。          |





