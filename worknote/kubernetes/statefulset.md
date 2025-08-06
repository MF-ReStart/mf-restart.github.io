# StatefulSet

StatefulSet 是用来管理有状态应用的工作负载 API 对象。

StatefulSet 用来管理某 [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) 集合的部署和扩缩， 并为这些 Pod 提供持久存储和持久标识符。

和 [Deployment](https://kubernetes.io/zh/docs/concepts/workloads/controllers/deployment/) 类似， StatefulSet 管理基于相同容器规约的一组 Pod。但和 Deployment 不同的是， StatefulSet 为它们的每个 Pod 维护了一个有粘性的 ID。这些 Pod 是基于相同的规约来创建的， 但是不能相互替换：无论怎么调度，每个 Pod 都有一个永久不变的 ID。

StatefulSets 对于需要满足以下一个或多个需求的应用程序很有价值：

- 稳定的、唯一的网络标识符。
- 稳定的、持久的存储。
- 有序的、优雅的部署和缩放。
- 有序的、自动的滚动更新。

在上面描述中，“稳定的”意味着 Pod 调度或重调度的整个过程是有持久性的。 如果应用程序不需要任何稳定的标识符或有序的部署、删除或伸缩，则应该使用由一组无状态的副本控制器提供的工作负载来部署应用程序，比如 [Deployment](https://kubernetes.io/zh/docs/concepts/workloads/controllers/deployment/) 或者 [ReplicaSet](https://kubernetes.io/zh/docs/concepts/workloads/controllers/replicaset/) 可能更适用于你的无状态应用部署需要。

## 创建 StatefulSet

作为开始，使用如下示例创建一个 StatefulSet。它和 [StatefulSets](https://kubernetes.io/zh/docs/concepts/workloads/controllers/statefulset/) 概念中的示例相似。 它创建了一个 [Headless Service](https://kubernetes.io/zh/docs/concepts/services-networking/service/#headless-services) `statefulset-service` 用来发布 StatefulSet `web` 中的 Pod 的 IP 地址。

```yaml
apiVersion: v1
kind: Service
metadata:
  name: statefulset-service
  namespace: default
  labels:
    app: statefulset
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "statefulset-service"
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      storageClassName: "managed-nfs-storage"
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 2Gi
```

### 顺序创建 Pod

对于一个拥有 N 个副本的 StatefulSet，Pod 被部署时是按照 {0 …… N-1} 的序号顺序创建的。 在第一个终端中使用 `kubectl get` 检查输出。这个输出最终将看起来像下面的样子。

```bash
kubectl get pod -w -l app=nginx
NAME    READY   STATUS    RESTARTS   AGE
web-0   0/1     Pending   0          0s
web-0   0/1     Pending   0          0s
web-0   0/1     ContainerCreating   0          0s
web-0   0/1     ContainerCreating   0          2s
web-0   1/1     Running             0          18s
web-1   0/1     Pending             0          0s
web-1   0/1     Pending             0          0s
web-1   0/1     ContainerCreating   0          0s
web-1   0/1     ContainerCreating   0          1s
web-1   1/1     Running             0          17s
web-2   0/1     Pending             0          0s
web-2   0/1     Pending             0          0s
web-2   0/1     ContainerCreating   0          0s
web-2   0/1     ContainerCreating   0          1s
web-2   1/1     Running             0          17s
```

请注意在 `web-0` Pod 处于 [Running和Ready](https://kubernetes.io/zh/docs/user-guide/pod-states) 状态后 `web-1` Pod 才会被启动。

## StatefulSet 中的 Pod

StatefulSet 中的 Pod 拥有一个唯一的顺序索引和稳定的网络身份标识。

### 检查 Pod 的顺序索引

获取 StatefulSet 的 Pod。

```bash
kubectl get pods -l app=nginx
NAME    READY   STATUS    RESTARTS   AGE
web-0   1/1     Running   0          5m11s
web-1   1/1     Running   0          4m53s
web-2   1/1     Running   0          4m36s
```

如同 [StatefulSets](https://kubernetes.io/zh/docs/concepts/workloads/controllers/statefulset/) 概念中所提到的， StatefulSet 中的 Pod 拥有一个具有黏性的、独一无二的身份标志。 这个标志基于 StatefulSet 控制器分配给每个 Pod 的唯一顺序索引。 Pod 的名称的形式为`<statefulset name>-<ordinal index>`。 `web`StatefulSet 拥有两个副本，所以它创建了三个 Pod: `web-0`，`web-1` 和 `web-2`。

### 使用稳定的网络身份标识

每个 Pod 都拥有一个基于其顺序索引的稳定的主机名。使用[`kubectl exec`](https://kubernetes.io/zh/docs/reference/generated/kubectl/kubectl-commands/#exec)在每个 Pod 中执行`hostname`。

```bash
for i in 0 1; do kubectl exec "web-$i" -- sh -c 'hostname'; done
web-0
web-1
web-2
```

使用 [`kubectl run`](https://kubernetes.io/zh/docs/reference/generated/kubectl/kubectl-commands/#run) 运行一个提供 `nslookup` 命令的容器，该命令来自于 `dnsutils` 包。 通过对 Pod 的主机名执行 `nslookup`，你可以检查他们在集群内部的 DNS 地址。

```bash
kubectl run -i --tty --image busybox:1.28 dns-test --restart=Never --rm
```

这将启动一个新的 shell。在新 shell 中，运行：

```bash
# Run this in the dns-test container shell
nslookup statefulset-service
```

输出类似于：

```bash
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      statefulset-service
Address 1: 10.244.169.165 web-0.statefulset-service.default.svc.cluster.local
Address 2: 10.244.36.98 web-1.statefulset-service.default.svc.cluster.local
Address 3: 10.244.169.166 web-2.statefulset-service.default.svc.cluster.local
```

即使 Pod 重建之后 IP 发生改变，Headless Service 还是能够根据 web-{0-1}.statefulset-service.default.svc.cluster.local 这个 DNS A 记录来找到每个 pod 的 IP 地址。

### 标准 Service 和 Headless Service 的区别

这里要提到 `无状态应用控制器` 和 `有状态应用控制器` 的设计理念，无状态的 Pod 是完全相等的，提供相同的服务，可以飘移在任意节点，例如三个 NGINX Pod 所提供的 Web 服务。而像一些分布式应用程序，例如 zookeeper 集群、etcd 集群、mysql 主从等服务，每个实例都会维护着一种状态，每个实例都有自己的数据，并且每个实例之间必须有固定的访问地址（组建集群），这就是有状态应用。由于标准 Service 是通过访问 ClusterIP 负载均衡到一组 Pod 上，这是没有办法指定访问到某个 Pod 的（由 iptables 决定）。所以这里就出现了 Headless Service ，而且 Headless Service 不需要 ClusterIP ，它是通过访问 Pod DNS 名称解析到对应的 Pod IP，为每一个 Pod 都固定一个 DNS 名称，即使 Pod 的 IP 发生改变，Pod 的 DNS 名称还是指向对应的 Pod IP 地址。

### 写入稳定的存储

Kubernetes 为每个 VolumeClaimTemplate 创建一个 [PersistentVolume](https://kubernetes.io/zh/docs/concepts/storage/persistent-volumes/)。 在上面的 nginx 示例中，每个 Pod 将会得到基于 StorageClass `managed-nfs-storage` 提供的 2 Gib 的 PersistentVolume。如果没有声明 StorageClass，就会使用默认的 StorageClass。 当一个 Pod 被调度（重新调度）到节点上时，它的 `volumeMounts` 会挂载与其 PersistentVolumeClaims 相关联的 PersistentVolume。 请注意，当 Pod 或者 StatefulSet 被删除时，与 PersistentVolumeClaims 相关联的 PersistentVolume 并不会被删除。要删除它必须通过手动方式来完成。

获取 StatefulSet 创建的 PersistentVolumeClaims。

```bash
kubectl get pvc -l app=nginx
```

输出类似于：

```bash
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS          AGE
www-web-0   Bound    pvc-83489225-7d08-4506-9f75-1fefd3aee287   2Gi        RWO            managed-nfs-storage   23h
www-web-1   Bound    pvc-e5afdbfa-952e-4120-8885-00cf5a524eb0   2Gi        RWO            managed-nfs-storage   23h
www-web-2   Bound    pvc-21e9a5b1-a040-41c6-9b94-6bcf7a8a8966   2Gi        RWO            managed-nfs-storage   23h
```

StatefulSet 控制器创建了三个 PersistentVolumeClaims，绑定到三个 [PersistentVolumes](https://kubernetes.io/zh/docs/concepts/storage/volumes/)。由于本教程使用的集群配置为动态提供 PersistentVolume，所有的 PersistentVolume 都是自动创建和绑定的，对于动态配置的 PersistentVolumes 来说，默认回收策略为 "Delete"。

NGINX web 服务器默认会加载位于 `/usr/share/nginx/html/index.html` 的 index 文件。 StatefulSets `spec` 中的 `volumeMounts` 字段保证了 `/usr/share/nginx/html` 文件夹由一个 PersistentVolume 支持。

将 Pod 的主机名写入它们的`index.html`文件并验证 NGINX web 服务器使用该主机名提供服务。

```bash
for i in 0 1 2; do kubectl exec "web-$i" -- sh -c 'echo $(hostname) > /usr/share/nginx/html/index.html'; done

for i in 0 1 2; do kubectl exec -i -t "web-$i" -- curl http://localhost/; done
```

在另一个终端删除 StatefulSet 所有的 Pod。

```bash
kubectl delete pod -l app=nginx
```

验证所有 web 服务器在继续使用它们的主机名提供服务。

```bash
for i in 0 1 2; do kubectl exec -i -t "web-$i" -- curl http://localhost/; done
```

虽然 Pod`web-{0-2}` 被重新调度了，但它们仍然继续监听各自的主机名，因为和它们的 PersistentVolumeClaim 相关联的 PersistentVolume 被重新挂载到了各自的 `volumeMount` 上。 不管 Pod 被调度到了哪个节点上，它们的 PersistentVolumes 将会被挂载到合适的挂载点上。
