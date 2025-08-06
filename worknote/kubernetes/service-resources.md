# Service 资源

创建和销毁 Kubernetes Pod 以匹配集群状态。 Pod 是非永久性资源。 如果你使用 Deployment 来运行你的应用程序，则它可以动态创建和销毁 Pod。

每个 Pod 都有自己的 IP 地址，但是在 Deployment 中，在同一时刻运行的 Pod 集合可能与稍后运行该应用程序的 Pod 集合不同。

这导致了一个问题： 如果一组 Pod（称为“后端”）为集群内的其他 Pod（称为“前端”）提供功能， 那么前端如何找出并跟踪要连接的 IP 地址，以便前端可以使用提供工作负载的后端部分？

于是就有了 Services。

## 定义 Service

例如，假定有一组 Pod，它们对外暴露了 6379 端口，同时还被打上 `app=redis` 标签：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-deployment
  labels:
    app: redis-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis
        ports:
        - containerPort: 6379
```

我们创建名称为 "my-service" 的 Service 对象，它会将请求代理到使用 TCP 端口 6379，并且具有标签 `app=redis` 的 Pod 上：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: redis
  ports:
    - protocol: TCP
      port: 80
      targetPort: 6379
```

通过执行 `kubectl get endpoints my-service` 命令可以看到 Service 后端所代理的 Pod：

```bash
NAME         ENDPOINTS                                                   AGE
my-service   10.244.169.179:6379,10.244.169.180:6379,10.244.36.82:6379   6m3s
```

## Service 虚拟 IP 和服务代理

在 Kubernetes 集群中，每个 Node 运行一个 kube-proxy 进程。 kube-proxy 负责为 Service 实现了一种 VIP（虚拟 IP）的形式，而不是 ExternalName 的形式。简单来讲，一个 Service 对象就是工作节点上的一些 iptables 或 ipvs 规则，用于将到达 Service 对象 IP 地址的流量调度转发至相应的 Endpoint 对象指向的 IP 地址和端口之上。

### userspace 代理模型

![](https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/Service-userspace.png)

这种模式，kube-proxy 会监视 Kubernetes 控制平面对 Service 对象和 Endpoints 对象的添加和移除操作。 对每个 Service，它会在本地 Node 上打开一个端口（随机选择）。 任何连接到“代理端口”的请求，都会被代理到 Service 的后端 `Pods` 中的某个上面（如 `Endpoints` 所报告的一样）。 使用哪个后端 Pod，是 kube-proxy 基于 `SessionAffinity` 来确定的。

最后，它配置 iptables 规则，捕获到达该 Service 的 `clusterIP`（是虚拟 IP） 和 `Port` 的请求，并重定向到代理端口，代理端口再代理请求到后端Pod。

默认情况下，用户空间模式下的 kube-proxy 通过轮转算法选择后端。

### iptables 代理模型

![](https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/Service-iptables.png)

这种模式，kube-proxy 会监视 Kubernetes 控制节点对 Service 对象和 Endpoints 对象的添加和移除。 对每个 Service，它会配置 iptables 规则，从而捕获到达该 Service 的 clusterIP 和端口的请求，进而将请求重定向到 Service 的一组后端中的某个 Pod 上面。 对于每个 Endpoints 对象，它也会配置 iptables 规则，这个规则会选择一个后端组合。

默认的策略是，kube-proxy 在 iptables 模式下随机选择一个后端。

使用 iptables 处理流量具有较低的系统开销，因为流量由 Linux netfilter 处理， 而无需在用户空间和内核空间之间切换。 这种方法也可能更可靠。

如果 kube-proxy 在 iptables 模式下运行，并且所选的第一个 Pod 没有响应， 则连接失败。 这与用户空间模式不同：在这种情况下，kube-proxy 将检测到与第一个 Pod 的连接已失败， 并会自动使用其他后端 Pod 重试。

你可以使用 Pod 就绪探测器 验证后端 Pod 可以正常工作，以便 iptables 模式下的 kube-proxy 仅看到测试正常的后端。 这样做意味着你避免将流量通过 kube-proxy 发送到已知已失败的 Pod。

### ipvs 代理模型

![](https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/Service-ipvs.png)

在 `ipvs` 模式下，kube-proxy 监视 Kubernetes 服务和端点，调用 `netlink` 接口相应地创建 IPVS 规则， 并定期将 IPVS 规则与 Kubernetes 服务和端点同步。 该控制循环可确保IPVS 状态与所需状态匹配。访问服务时，IPVS 将流量定向到后端 Pod 之一。

IPVS代理模式基于类似于 iptables 模式的 netfilter 挂钩函数， 但是使用哈希表作为基础数据结构，并且在内核空间中工作。 这意味着，与 iptables 模式下的 kube-proxy 相比，IPVS 模式下的 kube-proxy 重定向通信的延迟要短，并且在同步代理规则时具有更好的性能。 与其他代理模式相比，IPVS 模式还支持更高的网络流量吞吐量。

IPVS 提供了更多选项来平衡后端 Pod 的流量。 这些是：

- `rr`: 轮替（Round-Robin）。
- `lc`: 最少链接（Least Connection），即打开链接数量最少者优先。
- `dh`: 目标地址哈希（Destination Hashing）。
- `sh`: 源地址哈希（Source Hashing）。
- `sed`: 最短预期延迟（Shortest Expected Delay）。
- `nq`: 从不排队（Never Queue）。

## Service 类型

对于一些应用的某些部分（如前端），可能希望将其暴露给 Kubernetes 集群外部的 IP 地址。

Kubernetes `ServiceTypes` 允许指定你所需要的 Service 类型，默认是 `ClusterIP`。

`Type` 的取值以及行为如下：

- `ClusterIP`: 通过集群的内部 IP 暴露服务，选择该值时服务只能够在集群内部访问。 这也是默认的 `ServiceType`。
- `NodePort`: 通过每个节点上的 IP 和静态端口（`NodePort`）暴露服务。 `NodePort` 服务会路由到自动创建的 `ClusterIP` 服务。 通过请求 `<节点 IP>:<节点端口>`，你可以从集群的外部访问一个 `NodePort` 服务。
- `LoadBalancer`: 使用云提供商的负载均衡器向外部暴露服务。 外部负载均衡器可以将流量路由到自动创建的 `NodePort` 服务和 `ClusterIP` 服务上。
- `ExternalName`: 通过返回 `CNAME` 和对应值，可以将服务映射到 `externalName` 字段的内容（例如，`foo.bar.example.com`）。 无需创建任何类型代理。

你也可以使用 [Ingress](https://kubernetes.io/zh/docs/concepts/services-networking/ingress/) 来暴露自己的服务。 Ingress 不是一种服务类型，但它充当集群的入口点。 它可以将路由规则整合到一个资源中，因为它可以在同一IP地址下公开多个服务。

### NodePort 类型

如果你将 `type` 字段设置为 `NodePort`，则 Kubernetes 控制平面将在 `--service-node-port-range` 标志指定的范围内分配端口（默认值：30000-32767）。 每个节点将那个端口（每个节点上的相同端口号）代理到你的服务中。 你的服务在其 `.spec.ports[*].nodePort` 字段中要求分配的端口。

如果需要特定的端口号，你可以在 `nodePort` 字段中指定一个值。 控制平面将为你分配该端口或报告 API 事务失败。 这意味着你需要自己注意可能发生的端口冲突。 你还必须使用有效的端口号，该端口号在配置用于 NodePort 的范围内。 

使用 NodePort 可以让你自由设置自己的负载均衡解决方案， 配置 Kubernetes 不完全支持的环境， 甚至直接暴露一个或多个节点的 IP。

例如：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: NodePort
  selector:
    app: MyApp
  ports:
      # 默认情况下,为了方便起见,`targetPort` 被设置为与 `port` 字段相同的值
    - port: 80
      targetPort: 80
      # 可选字段
      # 默认情况下,为了方便起见,Kubernetes 控制平面会从某个范围内分配一个端口号(默认:30000-32767)
      nodePort: 30007
```

## Service 启用 ipvs 代理模型

Kubernetes 的 `1.11` 版本后，默认使用 ipvs，如果节点的内核不支持或没有开启 ipvs 则 kubernetes 会自动降级为使用 iptables 规则。

查看 kube-proxy 的启动日志，这里默认使用的是 iptables 代理模型。

```bash
[root@k8s-master ~]$ kubectl logs -f kube-proxy-hjxcq -n kube-system 
...
I0323 03:36:31.452070       1 node.go:172] Successfully retrieved node IP: 10.10.110.192
I0323 03:36:31.452837       1 server_others.go:142] kube-proxy node IP is an IPv4 address (10.10.110.192), assume IPv4 operation
W0323 03:36:31.577520       1 server_others.go:578] Unknown proxy mode "", assuming iptables proxy
I0323 03:36:31.579263       1 server_others.go:185] Using iptables Proxier.
I0323 03:36:31.580249       1 server.go:650] Version: v1.20.0
...
```

在所有 Kubernetes 节点开启 ipvs 支持。

```bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
```

查看内核模块是否加载。

```bash
lsmod | grep ip_vs
```

修改 ConfigMap 的 kube-system/kube-proxy 的配置文件为 ipvs。

```bash
kubectl edit configmaps kube-proxy -n kube-system
...
ipvs:      
      excludeCIDRs: null
      minSyncPeriod: 0s
      scheduler: ""
      strictARP: false
      syncPeriod: 0s
      tcpFinTimeout: 0s
      tcpTimeout: 0s
      udpTimeout: 0s
    kind: KubeProxyConfiguration
    metricsBindAddress: ""
    mode: "ipvs" # 修改此处为ipvs
...
```

删除所有 kube-proxy 的 pod。

```bash
kubectl get pod -n kube-system | grep 'kube-proxy' | awk '{print $1}' | xargs -I {} kubectl delete pod {} -n kube-system
```

再次查看 kube-proxy 的日志。

```bash
[root@k8s-master ~]$ kubectl logs -f kube-proxy-pnglg -n kube-system 
...
I0410 09:05:52.455879       1 node.go:172] Successfully retrieved node IP: 10.10.110.192
I0410 09:05:52.459403       1 server_others.go:142] kube-proxy node IP is an IPv4 address (10.10.110.192), assume IPv4 operation
I0410 09:05:52.599981       1 server_others.go:258] Using ipvs Proxier.
W0410 09:05:52.606702       1 proxier.go:445] IPVS scheduler not specified, use rr by default
I0410 09:05:52.608073       1 server.go:650] Version: v1.20.0
...
```

查看 ipvs 相关规则。

```bash
apt install -y ipvsadm 

[root@k8s-master ~]$ ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  172.17.0.1:30023 rr
  -> 10.244.36.72:8443            Masq    1      0          0         
TCP  10.10.110.190:30023 rr
  -> 10.244.36.72:8443            Masq    1      0          0         
TCP  10.96.0.1:443 rr
  -> 10.10.110.190:6443           Masq    1      0          0         
TCP  10.96.0.10:53 rr
  -> 10.244.36.73:53              Masq    1      0          0         
  -> 10.244.169.160:53            Masq    1      0          0         
TCP  10.96.0.10:9153 rr
  -> 10.244.36.73:9153            Masq    1      0          0         
  -> 10.244.169.160:9153          Masq    1      0          0         
TCP  10.97.105.36:80 rr
TCP  10.98.47.133:443 rr
  -> 10.244.36.72:8443            Masq    1      0          0         
TCP  10.110.221.168:8000 rr
  -> 10.244.169.159:8000          Masq    1      0          0         
TCP  10.244.235.192:30023 rr
  -> 10.244.36.72:8443            Masq    1      0          0         
TCP  127.0.0.1:30023 rr
  -> 10.244.36.72:8443            Masq    1      0          0         
UDP  10.96.0.10:53 rr
  -> 10.244.36.73:53              Masq    1      0          0         
  -> 10.244.169.160:53            Masq    1      0          0
```
