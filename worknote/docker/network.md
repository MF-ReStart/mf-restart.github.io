# 网络概述

Docker 容器和服务如此强大的原因之一是可以将它们连接到一起，或将它们连接到其他的非 Docker 工作负载上。Docker 容器甚至不需要知道它们部署在 Docker 上，或者它们的对端是否也是 Docker 工作负载。无论你的 Docker 主机是运行在 Linux 还是 Windows 又或者两者都有，你都可以使用 Docker 以平台无关的方式管理它们。

Docker 的网络子系统是使用驱动程序插入的。默认情况下存在多个驱动程序，它们一起提供核心网络功能，可以使用 docker network ls 命令查看默认存在的驱动程序。

```bash
[root@docker ~]# docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
ef0a155fdde4   bridge    bridge    local
c4fa50b15f43   host      host      local
6a2c541b2e82   none      null      local
[root@docker ~]#
```

## Docker 常用的网络类型

### Bridge

默认的网络驱动程序，如果你创建容器时不指定网络驱动程序，这就是你正在创建容器的网络类型。当你的应用程序在需要通信的独立容器中运行时，通常会使用桥接网络。当启动 docker.service 服务之后，Docker 会默认创建一个名为 docker0 的虚拟网桥，所有没有指定网络驱动程序的容器都会被加入到这个网桥中。虚拟网桥就像一个物理交换机，这样网桥内的容器都连接到了一个二层网络中。Docker 会在宿主机上创建一对 veth pair 虚拟网卡设备，这一对 veth pair 虚拟网卡设备的两端分别对应容器内部的 eth0 网卡和宿主机上类似 vethxxxxxx 的虚拟网卡，可以使用 brctl show 命令查看宿主机上已经加入到 docker0 网桥下的虚拟网卡设备。虚拟网卡设备连接到 docker0 网桥后， docker0 网桥会从子网分配一个 ip 给容器，并且设置 docker0 网桥的 ip 地址为容器的默认网关。 

查看 docker0 网桥上的接口信息。

```bash
[root@docker ~]# brctl show
bridge name	bridge id		STP enabled	interfaces
docker0		8000.02429451522b	no		veth00b57b0
							veth0bf3f4c
							veth59d431c
[root@docker ~]#
```

创建容器时不指定网络驱动程序，默认就是 bridge 网络类型，但是我们还可以创建自定义的 bridge 网络类型。

```bash
[root@docker ~]# docker network create app
0a4fd2947aa9dcf12786709bcce856421b33c7b2fdcc6175691be4d42cec0d07
[root@docker ~]# docker network ls
NETWORK ID     NAME      DRIVER    SCOPE
0a4fd2947aa9   app       bridge    local
ef0a155fdde4   bridge    bridge    local
c4fa50b15f43   host      host      local
6a2c541b2e82   none      null      local
```

创建两个容器并把它们加入到自定义的 app 网络，-d 参数可以指定创建 bridge 或者 overlay 网络类型。

```bash
[root@docker ~]# docker container run -itd --name "app1" --network app busybox
f46be3d1f5ead467e2f7e8df05f72d73e6d3a3b3aaa2d34a49a5879a99fa53d1
[root@docker ~]# docker container run -itd --name "app2" --network app busybox
7c2b79e36244d79ad8e184d916ddba23fbb026b1bdc6e3c333d7110f705695de
[root@docker ~]#
```

随着 Docker 网络的完善，建议大家将容器加入自定义的网络来进行连接。通过在容器内使用 ping 命令来证明容器网络的互通。

```bash
[root@docker ~]# docker ps -a
CONTAINER ID   IMAGE     COMMAND   CREATED         STATUS         PORTS     NAMES
7c2b79e36244   busybox   "sh"      4 minutes ago   Up 4 minutes             app2
f46be3d1f5ea   busybox   "sh"      5 minutes ago   Up 5 minutes             app1
[root@docker ~]# docker exec -it app1 sh
/ # ping -c 3 app2
PING app2 (172.19.0.3): 56 data bytes
64 bytes from 172.19.0.3: seq=0 ttl=64 time=0.071 ms
64 bytes from 172.19.0.3: seq=1 ttl=64 time=0.111 ms
64 bytes from 172.19.0.3: seq=2 ttl=64 time=0.107 ms

--- app2 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.071/0.096/0.111 ms
/ #
```

### Host

如果容器使用 host 网络类型，则容器的网络堆栈不会与 Docker 主机隔离（容器共享主机的网络命名空间）。并且容器不会分配自己的 ip 地址，而是使用宿主机的 ip 和端口，容器的文件系统和进程等还是和宿主机隔离的。

> **[info] 说明**
>
> 由于容器使用 host 网络模式没有主机的 ip 地址，端口映射不会生效，-p 和 -P 参数都会被忽略并且产生一个错误警告：WARNING: Published ports are discarded when using host network mode

创建一个 nginx 容器，可以看到宿主机上的 80 端口被占用了。

```bash
[root@docker ~]# docker container run -itd --name "nginx" --network=host nginx:1.20
1a13399898af4d66758a0ec10f4f8e3d89cd21b15186c6cea9c161cca0d82b87
[root@docker ~]# ps -ef | grep nginx
root      260249  260228  1 14:38 pts/0    00:00:00 nginx: master process nginx -g daemon off;
systemd+  260308  260249  0 14:38 pts/0    00:00:00 nginx: worker process
systemd+  260309  260249  0 14:38 pts/0    00:00:00 nginx: worker process
root      260313  112281  0 14:38 pts/1    00:00:00 grep --color=auto nginx
[root@docker ~]# netstat -lntup | grep 80
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      260249/nginx: maste
tcp6       0      0 :::80                   :::*                    LISTEN      260249/nginx: maste
[root@docker ~]#
```

使用 ps 命令可以看到 nginx 进程的父进程是 containerd-shim，这也证实了 nginx 进程是容器内的。

```bash
[root@docker ~]# ps -axf | grep containerd-shim -A 1
 260701 pts/1    S+     0:00      \_ grep --color=auto containerd-shim -A 1
 260228 ?        Sl     0:00 /usr/bin/containerd-shim-runc-v2 -namespace moby -id 1a13399898af4d66758a0ec10f4f8e3d89cd21b15186c6cea9c161cca0d82b87 -address /run/containerd/containerd.sock
 260249 pts/0    Ss+    0:00  \_ nginx: master process nginx -g daemon off;
[root@docker ~]#
```

进入容器内部查看网卡信息会看到宿主机的网卡，这是因为容器共享了宿主机网络堆栈。

```bash
[root@docker ~]# docker container run -itd --name "busybox" --network=host busybox
ad4634aa3d4d52b7ccd086359fe20e0fe5abae5527ac6a78064a0c308dde8f09
[root@docker ~]# docker exec -it busybox /bin/sh
/ # ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel qlen 1000
    link/ether 00:0c:29:f9:6d:2f brd ff:ff:ff:ff:ff:ff
    inet 10.10.110.31/24 brd 10.10.110.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::20c:29ff:fef9:6d2f/64 scope link
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue
    link/ether 02:42:94:51:52:2b brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:94ff:fe51:522b/64 scope link
       valid_lft forever preferred_lft forever
15: br-0a4fd2947aa9: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue
    link/ether 02:42:f8:6b:79:d0 brd ff:ff:ff:ff:ff:ff
    inet 172.19.0.1/16 brd 172.19.255.255 scope global br-0a4fd2947aa9
       valid_lft forever preferred_lft forever
    inet6 fe80::42:f8ff:fe6b:79d0/64 scope link
       valid_lft forever preferred_lft forever
/ #
```

### Container

创建新容器时指定和一个已存在的容器共享一个网络命名空间，这与宿主机的网络命名空间无关。新容器不会创建自己的网卡和 ip 地址，而是共享已存在容器的网卡、ip、端口等。但是除了网络环境之外，其他的资源例如文件系统和进程等还是隔离的，这就是 container 网络类型。

创建一个 busybox 容器，用于给其他容器共享网络命名空间。

```bash
[root@docker ~]# docker container run -itd --name 'busybox' busybox
471accba2c3fef25da6a617417b8c84fb38c860aa49a4e9287dcbacd111b73f2
[root@docker ~]#
```

创建新的容器，指定新的容器共享前面创建的 busybox 容器的网络命名空间。

```bash
[root@docker ~]# docker container run -itd --network=container:busybox --name 'busybox-1' busybox
a1e6999c17e35a7ea32c9886f3f708985a50a8c1b8b1bc36b790b10a9db98d59
[root@docker ~]# docker container run -itd --network=container:busybox --name 'busybox-2' busybox
867915a468489dd356efbe0c1ea22430df3dd026b74267caa7576b3eec298f67
[root@docker ~]#
```

共享 busybox 容器网络命名空间的 busybox-1 和 busybox-2 容器，ip 的值为 \<no value>，其实容器内的 ip 地址是和 busybox 容器一样的。

```bash
[root@docker ~]# docker inspect --format='{{.NetworkSettings.Networks.bridge.IPAddress}}' busybox
172.17.0.2
[root@docker ~]# docker inspect --format='{{.NetworkSettings.Networks.bridge.IPAddress}}' busybox-1
<no value>
[root@docker ~]# docker inspect --format='{{.NetworkSettings.Networks.bridge.IPAddress}}' busybox-2
<no value>
[root@docker ~]#

[root@docker ~]# docker container exec -it busybox ifconfig eth0
eth0      Link encap:Ethernet  HWaddr 02:42:AC:11:00:02
          inet addr:172.17.0.2  Bcast:172.17.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:120 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:8672 (8.4 KiB)  TX bytes:0 (0.0 B)

[root@docker ~]# docker container exec -it busybox-1 ifconfig eth0
eth0      Link encap:Ethernet  HWaddr 02:42:AC:11:00:02
          inet addr:172.17.0.2  Bcast:172.17.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:120 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:8672 (8.4 KiB)  TX bytes:0 (0.0 B)

[root@docker ~]# docker container exec -it busybox-2 ifconfig eth0
eth0      Link encap:Ethernet  HWaddr 02:42:AC:11:00:02
          inet addr:172.17.0.2  Bcast:172.17.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:120 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:8672 (8.4 KiB)  TX bytes:0 (0.0 B)
[root@docker ~]#
```

### None

none 模式会使容器拥有独立的 network namespace，就是不为 Docker 容器进行任何网络配置。容器内部只有 loopback 网络设备，这将网络创建的责任完全交给用户。Docker 开发者可以在这基础上做出更多的网络定制，这种方式可以实现更加灵活复杂的网络。

```bash
[root@docker ~]# docker container run -it --network=none --name 'busybox-3' busybox
/ # ifconfig -a
lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

/ #
```

## Flannel 实现 Docker 跨主机通信

flannel 是一种基于 overlay 网络的跨主机容器网络解决方案。就是将 TCP 数据包封装在另一种网络包里面进行路由转发和通信，flannel 是 CoreOS 团队针对 Kubernetes 设计的一个网络规划服务，让集群中的不同节点主机创建的容器都具有全集群唯一的虚拟 ip 地址，flannel 使用 go 语言编写。

flannel 为每个 host 分配一个 subnet，容器从这个 subnet 中分配 ip，这些 ip 可以在 host 间路由，容器间无需使用 nat 和端口映射即可实现跨主机通信。每个 subnet 都是从一个更大的 ip 池中划分的，flannel 会在每个主机上运行一个叫 flanneld 的 agent，其职责就是从 ip 池中分配 subnet。etcd 相当于一个数据库，flannel 使用 etcd 存放网络配置和已分配的 subnet、host、ip 等信息。这就是 flannel 的原理。

| node                 | software              | Operating System   | docker version |
| -------------------- | --------------------- | ------------------ | -------------- |
| 10.10.110.31(master) | etcd、flannel、docker | Ubuntu 20.04.3 LTS | 19.03.12       |
| 10.10.110.32(slave)  | flannel、docker       | Ubuntu 20.04.3 LTS | 19.03.12       |

master 节点安装 etcd

```bash
root@docker1:~# apt install -y etcd

root@docker1:~# vim /etc/default/etcd # 修改 master 默认的 127.0.0.1 地址以供 slave 节点访问 etcd
ETCD_LISTEN_CLIENT_URLS="http://10.10.110.8:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://10.10.110.8:2379"

root@docker1:~# systemctl restart etcd
root@docker1:~# netstat -lntup | grep 2379
tcp        0      0 10.10.110.8:2379        0.0.0.0:*               LISTEN      95984/etcd

# 配置 etcd 的子网必须指定使用 V2 版本因为 flannel 目前不支持 etcd V3 版本
ETCDCTL_API=2 etcdctl --endpoints="http://10.10.110.8:2379" set /atomic.io/network/config '{ "Network":"172.17.0.0/16", "Backend": {"Type": "vxlan"}} '
```

master 节点安装 flannel

```bash
root@docker1:~# apt install -y flannel

root@docker1:~# cat > /etc/systemd/system/flanneld.service << EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
ExecStart=/usr/bin/flannel --etcd-endpoints=http://10.10.110.8:2379 --etcd-prefix=/atomic.io/network/ --iface=ens33
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF

root@docker1:~# systemctl start flanneld.service
```

slave 节点安装 flannel

```bash
root@docker1:~# apt install -y flannel

root@docker1:~# cat > /etc/systemd/system/flanneld.service << EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
ExecStart=/usr/bin/flannel --etcd-endpoints=http://10.10.110.8:2379 --etcd-prefix=/atomic.io/network/ --iface=ens33 # slave 也是连接到 master 的 etcd
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF

root@docker1:~# systemctl start flanneld.service
```

配置 docker 使用 flannel 网络，master 和 slave 都需要进行配置让 flannel 管理 docker 的网络

```bash
vim /lib/systemd/system/docker.service
EnvironmentFile=/run/flannel/docker # 加载这个文件里面的变量,这个文件记录了 flannel 分配的子网信息
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock $DOCKER_NETWORK_OPTIONS # 使用上面文件的变量,启动容器时指定使用 flannel 分配的子网去配置容器的网络

iptables -P FORWARD ACCEPT
systemctl daemon-reload
systemctl restart flanneld.service
systemctl restart docker.service
```

如果没有 /run/flannel/docker 这个文件，可以使用 [mk-docker-opts.sh](https://github.com/flannel-io/flannel/blob/master/dist/mk-docker-opts.sh) -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker 命令生成。

```bash
# docker0 网卡的网段变成了 flannel.1 网卡的子网时，就说明配置成功

root@docker1:~# ip a s docker0
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:42:6d:41:48:2a brd ff:ff:ff:ff:ff:ff
    inet 172.17.19.1/24 brd 172.17.19.255 scope global docker0
       valid_lft forever preferred_lft forever
root@docker1:~# ip a s flannel.1
4: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default
    link/ether 3e:f4:3d:f3:0d:4d brd ff:ff:ff:ff:ff:ff
    inet 172.17.19.0/32 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::3cf4:3dff:fef3:d4d/64 scope link
       valid_lft forever preferred_lft forever
root@docker1:~#

root@docker2:~# ip a s docker0
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default
    link/ether 02:42:4c:d8:64:b0 brd ff:ff:ff:ff:ff:ff
    inet 172.17.71.1/24 brd 172.17.71.255 scope global docker0
       valid_lft forever preferred_lft forever
root@docker2:~# ip a s flannel.1
4: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default
    link/ether 12:0e:69:a9:8d:09 brd ff:ff:ff:ff:ff:ff
    inet 172.17.71.0/32 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::100e:69ff:fea9:8d09/64 scope link
       valid_lft forever preferred_lft forever
root@docker2:~#
```

分别在 master 节点和 slave 节点创建容器进行验证。

```bash
root@docker1:~# docker run -it busybox sh
/ # ifconfig
eth0      Link encap:Ethernet  HWaddr 02:42:AC:11:13:02
          inet addr:172.17.19.2  Bcast:172.17.19.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1450  Metric:1
          RX packets:8 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:736 (736.0 B)  TX bytes:0 (0.0 B)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

/ # ping -c3 172.17.71.2
PING 172.17.71.2 (172.17.71.2): 56 data bytes
64 bytes from 172.17.71.2: seq=0 ttl=62 time=0.720 ms
64 bytes from 172.17.71.2: seq=1 ttl=62 time=0.810 ms
64 bytes from 172.17.71.2: seq=2 ttl=62 time=0.731 ms

--- 172.17.71.2 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.720/0.753/0.810 ms
/ #

root@docker2:~# docker run -it busybox sh
/ # ifconfig
eth0      Link encap:Ethernet  HWaddr 02:42:AC:11:47:02
          inet addr:172.17.71.2  Bcast:172.17.71.255  Mask:255.255.255.0
          UP BROADCAST RUNNING MULTICAST  MTU:1450  Metric:1
          RX packets:9 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:806 (806.0 B)  TX bytes:0 (0.0 B)

lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

/ # ping -c3 172.17.19.2
PING 172.17.19.2 (172.17.19.2): 56 data bytes
64 bytes from 172.17.19.2: seq=0 ttl=62 time=4.305 ms
64 bytes from 172.17.19.2: seq=1 ttl=62 time=0.858 ms
64 bytes from 172.17.19.2: seq=2 ttl=62 time=0.798 ms

--- 172.17.19.2 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.798/1.987/4.305 ms
/ #
```

