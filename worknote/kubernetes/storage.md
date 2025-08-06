# 存储

Kubernetes 的存储方式有很多，具体可以到[官网](https://kubernetes.io/zh/docs/concepts/storage/)了解。

## 卷

Container 中的文件在磁盘上是临时存放的，这给 Container 中运行的较重要的应用程序带来一些问题。问题之一是当容器崩溃时文件丢失。kubelet 会重新启动容器， 但容器会以干净的状态重启。 第二个问题会在同一 `Pod` 中运行多个容器并共享文件时出现。 Kubernetes [卷（Volume）](https://kubernetes.io/zh/docs/concepts/storage/volumes/)这一抽象概念能够解决这两个问题。

### 背景

Docker 也有 [卷（Volume）](https://docs.docker.com/storage/) 的概念，但对它只有少量且松散的管理。 Docker 卷是磁盘上或者另外一个容器内的一个目录。 Docker 提供卷驱动程序，但是其功能非常有限。

Kubernetes 支持很多类型的卷。 [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) 可以同时使用任意数目的卷类型。 临时卷类型的生命周期与 Pod 相同，但持久卷可以比 Pod 的存活期长。 因此，卷的存在时间会超出 Pod 中运行的所有容器，并且在容器重新启动时数据也会得到保留。 当 Pod 不再存在时，临时卷也将不再存在。但是持久卷会继续存在。

卷的核心是包含一些数据的一个目录，Pod 中的容器可以访问该目录。 所采用的特定的卷类型将决定该目录如何形成的、使用何种介质保存数据以及目录中存放的内容。

使用卷时, 在 `.spec.volumes` 字段中设置为 Pod 提供的卷，并在 `.spec.containers[*].volumeMounts` 字段中声明卷在容器中的挂载位置。 容器中的进程看到的是由它们的 Docker 镜像和卷组成的文件系统视图。 [Docker 镜像](https://docs.docker.com/userguide/dockerimages/) 位于文件系统层次结构的根部。各个卷则挂载在镜像内的指定路径上。 卷不能挂载到其他卷之上，也不能与其他卷有硬链接。 Pod 配置中的每个容器必须独立指定各个卷的挂载位置。

### 卷类型

Kubernetes 支持很多类型的卷，下面主要列举一些常用的卷。

#### emptyDir

当 Pod 分派到某个 Node 上时，`emptyDir` 卷会被创建，并且在 Pod 在该节点上运行期间，卷一直存在。 就像其名称表示的那样，卷最初是空的。 尽管 Pod 中的容器挂载 `emptyDir` 卷的路径可能相同也可能不同，这些容器都可以读写 `emptyDir` 卷中相同的文件。 当 Pod 因为某些原因被从节点上删除时，`emptyDir` 卷中的数据也会被永久删除。

说明： 容器崩溃并不会导致 Pod 被从节点上移除，因此容器崩溃期间 emptyDir 卷中的数据是安全的。

取决于你的环境，`emptyDir` 卷存储在该节点所使用的介质上；这里的介质可以是磁盘或 SSD 或网络存储。但是，你可以将 `emptyDir.medium` 字段设置为 `"Memory"`，以告诉 Kubernetes 为你挂载 tmpfs（基于 RAM 的文件系统）。 虽然 tmpfs 速度非常快，但是要注意它与磁盘不同。 tmpfs 在节点重启时会被清除，并且你所写入的所有文件都会计入容器的内存消耗，受容器内存限制约束。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test-containers
    image: ikubernetes/myapp:v1
    volumeMounts: # 容器的/usr/share/nginx/html目录挂载到emptyDir卷
    - mountPath: /usr/share/nginx/html
      name: html
  - name: busybox
    image: busybox
    volumeMounts: # 容器的/data目录挂载到emptyDir卷
    - mountPath: /data
      name: html
    command: ["/bin/sh", "-c", "while true; do echo $(date) >> /data/index.html; sleep 2;done"]
  volumes: # 在pod所在节点定义emptyDir卷
  - name: html
    emptyDir: {}
# 同一pod的两个不同的容器挂载到同一个emptyDir卷,实现数据共享和数据交互
```

#### hostPath

`hostPath` 卷能将主机节点文件系统上的文件或目录挂载到你的 Pod 中。 虽然这不是大多数 Pod 需要的，但是它为一些应用程序提供了强大的逃生舱。

除了必需的 `path` 属性之外，用户可以选择性地为 `hostPath` 卷指定 `type`。

支持的 `type` 值如下：

| 取值                | 行为                                                         |
| :------------------ | :----------------------------------------------------------- |
|                     | 空字符串（默认）用于向后兼容，这意味着在安装 hostPath 卷之前不会执行任何检查。 |
| `DirectoryOrCreate` | 如果在给定路径上什么都不存在，那么将根据需要创建空目录，权限设置为 0755，具有与 kubelet 相同的组和属主信息。 |
| `Directory`         | 在给定路径上必须存在的目录。                                 |
| `FileOrCreate`      | 如果在给定路径上什么都不存在，那么将在那里根据需要创建空文件，权限设置为 0644，具有与 kubelet 相同的组和所有权。 |
| `File`              | 在给定路径上必须存在的文件。                                 |
| `Socket`            | 在给定路径上必须存在的 UNIX 套接字。                         |
| `CharDevice`        | 在给定路径上必须存在的字符设备。                             |
| `BlockDevice`       | 在给定路径上必须存在的块设备。                               |

当使用这种类型的卷时要小心，因为：

- 具有相同配置（例如基于同一 PodTemplate 创建）的多个 Pod 会由于节点上文件的不同而在不同节点上有不同的行为。
- 下层主机上创建的文件或目录只能由 root 用户写入。你需要在 [特权容器](https://kubernetes.io/zh/docs/tasks/configure-pod-container/security-context/) 中以 root 身份运行进程，或者修改主机上的文件权限以便容器能够写入 `hostPath` 卷。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - mountPath: /usr/share/nginx/html # 容器里目录位置
      name: html
  volumes:
  - name: html
    hostPath:
      path: /data # 宿主上目录位置
      type: DirectoryOrCreate
```

#### nfs

`nfs` 卷能将 NFS (网络文件系统) 挂载到你的 Pod 中。 不像 `emptyDir` 那样会在删除 Pod 的同时也会被删除，`nfs` 卷的内容在删除 Pod 时会被保存，卷只是被卸载。 这意味着 `nfs` 卷可以被预先填充数据，并且这些数据可以在 Pod 之间共享。

注意： 在使用 NFS 卷之前，你必须运行自己的 NFS 服务器并将目标 share 导出备用。

部署 NFS 服务端：

```bash
apt-get update

apt-get install nfs-kernel-server -y

mkdir /mnt/nfs/

vim /etc/exports
/mnt/nfs 10.10.110.0/24(rw,no_root_squash,no_subtree_check) # 将NFS服务端的/mnt/nfs目录share出去

systemctl restart nfs-server.service
```

注意： NFS 服务端和客户端之间需要关闭防火墙，Kubernetes 节点必须支持驱动 NFS 存储设备。

客户端（Kubernetes 所有工作节点）：

```bash
apt-get update

apt-get install nfs-common -y # 客户端连接NFS服务器所需的包

mount -t nfs nfs:/mnt/nfs /mnt/nfs # 将nfs节点的/mnt/nfs目录挂载到本地节点的/mnt/nfs目录,创建文件测试两个节点的目录是否共享
```

创建 NFS 存储类的资源配置清单：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: html
  volumes:
  - name: html
    nfs:
      path: /mnt/nfs
      server: www.nfs.com
```

注意：我们的 Kubernetes 工作节点不需要提前挂载 NFS 卷，创建 pod 时会自动挂载，pod 销毁之后 NFS 卷也会自动卸载。

运行 pod 之后，我们可以在 pod 所在节点查看 NFS 挂载情况：

```bash
df -h | grep nfs
nfs:/mnt/nfs       19G  4.5G   14G  26% /var/lib/kubelet/pods/0a87a303-9e44-4388-9e89-4bf848d159cf/volumes/kubernetes.io~nfs/html
# nfs:/mnt/nfs 这是pod所在节点挂载NFS服务的目录
# /var/lib/kubelet/pods/0a87a303-9e44-4388-9e89-4bf848d159cf/volumes/kubernetes.io~nfs/html 是pod内/usr/share/nginx/html目录在宿主机上的映射
```

这时候我们在 NFS 服务器修改 NFS 共享目录 `/mnt/nfs` ，数据会同步到 pod 内的 `/usr/share/nginx/html` 目录。

#### persistentVolumeClaim

`persistentVolumeClaim` 卷用来将[持久卷](https://kubernetes.io/zh/docs/concepts/storage/persistent-volumes/)（PersistentVolume） 挂载到 Pod 中。 持久卷申领（PersistentVolumeClaim）是用户在不知道特定云环境细节的情况下"申领"持久存储 （例如 GCE PersistentDisk 或者 iSCSI 卷）的一种方法。

![](https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/persistentVolumeClaim.png)

持久卷（PersistentVolume，PV）是集群中的一块存储，可以由管理员事先供应，或者使用[存储类（Storage Class）](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/)来动态供应。 持久卷是集群资源，就像节点也是集群资源一样。PV 持久卷和普通的 Volume 一样，也是使用卷插件来实现的，只是它们拥有独立于任何使用 PV 的 Pod 的生命周期。 此 API 对象中记述了存储的实现细节，无论其背后是 NFS、iSCSI 还是特定于云平台的存储系统。

持久卷申领（PersistentVolumeClaim，PVC）表达的是用户对存储的请求。概念上与 Pod 类似。 Pod 会耗用节点资源，而 PVC 申领会耗用 PV 资源。Pod 可以请求特定数量的资源（CPU 和内存）；同样 PVC 申领也可以请求特定的大小和访问模式 （例如，可以要求 PV 卷能够以 ReadWriteOnce、ReadOnlyMany 或 ReadWriteMany 模式之一来挂载）。

每个 PV 对象都包含 `spec` 部分和 `status` 部分，分别对应卷的规约和状态：

```yaml
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv1
spec:
  capacity:
    storage: 1Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /mnt/pv1
    server: www.nfs.com
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv2
spec:
  capacity:
    storage: 2Gi
  volumeMode: Filesystem
  accessModes:
    - ReadOnlyMany
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /mnt/pv2
    server: www.nfs.com
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv3
spec:
  capacity:
    storage: 3Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteMany
    - ReadWriteOnce
    - ReadOnlyMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /mnt/pv3
    server: www.nfs.com
```

一般而言，每个 PV 卷都有确定的存储容量。 容量属性是使用 PV 对象的 `capacity` 属性来设置的。

目前，存储大小是可以设置和请求的唯一资源。 未来可能会包含 IOPS、吞吐量等属性。

针对 PV 持久卷，Kuberneretes 支持两种卷模式（`volumeModes`）：`Filesystem（文件系统）` 和 `Block（块）`。 `volumeMode` 是一个可选的 API 参数。 如果该参数被省略，默认的卷模式是 `Filesystem`。

`volumeMode` 属性设置为 `Filesystem` 的卷会被 Pod 挂载（Mount）到某个目录。 如果卷的存储来自某块设备而该设备目前为空，Kuberneretes 会在第一次挂载卷之前在设备上创建文件系统。

你可以将 `volumeMode` 设置为 `Block`，以便将卷作为原始块设备来使用。 这类卷以块设备的方式交给 Pod 使用，其上没有任何文件系统。 这种模式对于为 Pod 提供一种使用最快可能方式来访问卷而言很有帮助，Pod 和卷之间不存在文件系统层。另外，Pod 中运行的应用必须知道如何处理原始块设备。 关于如何在 Pod 中使用 `volumeMode: Block` 的卷，可参阅 [原始块卷支持](https://kubernetes.io/zh/docs/concepts/storage/persistent-volumes/#raw-block-volume-support)。

PersistentVolume 卷可以用资源提供者所支持的任何方式挂载到宿主系统上。 如下表所示，提供者（驱动）的能力不同，每个 PV 卷的访问模式都会设置为对应卷所支持的模式值。 例如，NFS 可以支持多个读写客户，但是某个特定的 NFS PV 卷可能在服务器上以只读的方式导出。每个 PV 卷都会获得自身的访问模式集合，描述的是特定 PV 卷的能力。

访问模式有：

- ReadWriteOnce -- 卷可以被一个节点以读写方式挂载。
- ReadOnlyMany -- 卷可以被多个节点以只读方式挂载。
- ReadWriteMany -- 卷可以被多个节点以读写方式挂载。

在命令行接口（CLI）中，访问模式也使用以下缩写形式：

- RWO - ReadWriteOnce。
- ROX - ReadOnlyMany。
- RWX - ReadWriteMany。

目前的回收策略有：

- Retain -- 手动回收（pvc 被删除后，pv 还保留着数据，只是 pv 的状态变为 Released ，并且 pv 不能再次被 pvc 绑定）。
- Recycle -- 基本擦除 (pvc 被删除后，pv 不保留数据，pv 可以再次被 pvc 绑定， `rm -rf /thevolume/*`)。
- Delete -- 诸如 AWS EBS、GCE PD、Azure Disk 或 OpenStack Cinder 卷这类关联存储资产也被删除。

目前，仅 NFS 和 HostPath 支持回收（Recycle）。 AWS EBS、GCE PD、Azure Disk 和 Cinder 卷都支持删除（Delete）。

每个 PVC 对象都有 `spec` 和 `status` 部分，分别对应申领的规约和状态：

```yaml
---
apiVersion: v1      
kind: PersistentVolumeClaim
metadata:           
  name: pvc1        
  namespace: default
spec: 
  accessModes:      
    - ReadWriteOnce 
  volumeMode: Filesystem
  resources:        
    requests:       
      storage: 800Mi
```

申领在请求具有特定访问模式的存储时，使用与卷相同的访问模式约定。

申领使用与卷相同的约定来表明是将卷作为文件系统还是块设备来使用。

申领和 Pod 一样，也可以请求特定数量的资源。在这个上下文中，请求的资源是存储。 卷和申领都使用相同的 [资源模型](https://git.k8s.io/community/contributors/design-proposals/scheduling/resources.md)。

申领可以设置[标签选择算符](https://kubernetes.io/zh/docs/concepts/overview/working-with-objects/labels/#label-selectors)来进一步过滤卷集合。只有标签与选择算符相匹配的卷能够绑定到申领上。 选择算符包含两个字段：

- `matchLabels` - 卷必须包含带有此值的标签。
- `matchExpressions` - 通过设定键（key）、值列表和操作符（operator） 来构造的需求。合法的操作符有 In、NotIn、Exists 和 DoesNotExist。

定义 PersistentVolume 的标签：

```bash
kubectl get persistentvolume --show-labels 
NAME   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM          STORAGECLASS   REASON   AGE   LABELS
pv1    1Gi        RWO,RWX        Retain           Available   default/pvc1                           43m   release=stable
pv2    2Gi        RWO,ROX        Retain           Available                                          43m   <none>
pv3    3Gi        RWO,ROX,RWX    Retain           Available                                          43m   <none>
```

PersistentVolumeClaim 通过 PersistentVolume 的标签去进行绑定：

```yaml
---
apiVersion: v1      
kind: PersistentVolumeClaim
metadata:           
  name: pvc1        
  namespace: default
spec: 
  accessModes:      
    - ReadWriteOnce 
  volumeMode: Filesystem
  resources:        
    requests:       
      storage: 800Mi
  selector:
    matchLabels:
      release: "stable"
    matchExpressions:
      - {key: release, operator: In, values: [stable]}
```

## 存储类

StorageClass 为管理员提供了描述存储 "类" 的方法。 不同的类型可能会映射到不同的服务质量等级或备份策略，或是由集群管理员制定的任意策略。 Kubernetes 本身并不清楚各种类代表的什么。这个类的概念在其他存储系统中有时被称为 "配置文件"。

### StorageClass 资源

每个 StorageClass 都包含 `provisioner`、`parameters` 和 `reclaimPolicy` 字段， 这些字段会在 StorageClass 需要动态分配 PersistentVolume 时会使用到。

StorageClass 对象的命名很重要，用户使用这个命名来请求生成一个特定的类。 当创建 StorageClass 对象时，管理员设置 StorageClass 对象的命名和其他参数，一旦创建了对象就不能再对其更新。

### 存储制备器

每个 StorageClass 都有一个制备器（Provisioner），用来决定使用哪个卷插件制备 PV。 该字段必须指定。

| 卷插件               | 内置制备器 |                           配置例子                           |
| :------------------- | :--------: | :----------------------------------------------------------: |
| AWSElasticBlockStore |     ✓      | [AWS EBS](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#aws-ebs) |
| AzureFile            |     ✓      | [Azure File](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#azure-file) |
| AzureDisk            |     ✓      | [Azure Disk](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#azure-disk) |
| CephFS               |     -      |                              -                               |
| Cinder               |     ✓      | [OpenStack Cinder](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#openstack-cinder) |
| FC                   |     -      |                              -                               |
| FlexVolume           |     -      |                              -                               |
| Flocker              |     ✓      |                              -                               |
| GCEPersistentDisk    |     ✓      | [GCE PD](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#gce-pd) |
| Glusterfs            |     ✓      | [Glusterfs](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#glusterfs) |
| iSCSI                |     -      |                              -                               |
| Quobyte              |     ✓      | [Quobyte](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#quobyte) |
| NFS                  |     -      |                              -                               |
| RBD                  |     ✓      | [Ceph RBD](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#ceph-rbd) |
| VsphereVolume        |     ✓      | [vSphere](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#vsphere) |
| PortworxVolume       |     ✓      | [Portworx Volume](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#portworx-volume) |
| ScaleIO              |     ✓      | [ScaleIO](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#scaleio) |
| StorageOS            |     ✓      | [StorageOS](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#storageos) |
| Local                |     -      | [Local](https://kubernetes.io/zh/docs/concepts/storage/storage-classes/#local) |

## 动态卷供应

动态卷供应允许按需创建存储卷。 如果没有动态供应，集群管理员必须手动地联系他们的云或存储提供商来创建新的存储卷， 然后在 Kubernetes 集群创建[`PersistentVolume` 对象](https://kubernetes.io/zh/docs/concepts/storage/persistent-volumes/)来表示这些卷。 动态供应功能消除了集群管理员预先配置存储的需要。 相反，它在用户请求时自动供应存储。

由于 NFS 卷插件并不支持内置制备器，所以我们用 NFS 作为底层存储去配置动态卷供应时，需要使用第三方的 NFS 插件 [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)。

部署 NFS 插件：

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nfs-subdir-external-provisioner
  labels:
    name: nfs-subdir-external-provisioner
---    
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: nfs-subdir-external-provisioner
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: nfs-subdir-external-provisioner
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: nfs-subdir-external-provisioner
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: nfs-subdir-external-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: nfs-subdir-external-provisioner
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
  
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner # or choose another name, must match deployment's env PROVISIONER_NAME'
parameters:
  archiveOnDelete: "false" # "false": 删除pvc之后NFS存储后端不会保留数据目录,"true": 删除pvc之后NFS存储后端会保留数据目录
  
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: nfs-subdir-external-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: k8s.gcr.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: 10.10.110.23 # NFS的服务地址
            - name: NFS_PATH
              value: /data/kubernetes # NFS的Export路径
      volumes:
        - name: nfs-client-root
          nfs:
            server: 10.10.110.23
            path: /data/kubernetes
```

创建 PersistentVolumeClaim 测试动态卷供应：

```yaml
# 指定storageClassName
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc1
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 800Mi
  storageClassName: "managed-nfs-storage"

# 使用annotations
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc1
  annotations:
    volume.beta.kubernetes.io/storage-class: "managed-nfs-storage"
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 800Mi
      
# 指定sc作为默认存储后端
kubectl patch storageclass managed-nfs-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc1
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 800Mi
```

说明：[关于 kubernetes 1.20 版本使用 NFS 插件出现 unexpected error getting claim reference: selfLink was empty, can't make reference 的报错。](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/issues/25)这是因为 kubernetes 1.20 版本禁用了 selfLink 。解决方法：

```yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
...
spec:
  containers:
  - command:
    - kube-apiserver
    - --feature-gates=RemoveSelfLink=false # 添加这一行
...
```

