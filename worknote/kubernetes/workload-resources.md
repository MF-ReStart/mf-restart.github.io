# 工作负载资源使用

## Deployment

一个 Deployment 为 [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) 和 [ReplicaSets](https://kubernetes.io/zh/docs/concepts/workloads/controllers/replicaset/) 提供声明式的更新能力。

下面是 Deployment 示例。其中创建了一个 ReplicaSet，负责启动三个 `nginx` Pods:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
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
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

开始之前，请确保的 Kubernetes 集群已启动并运行。 按照以下步骤创建上述 Deployment:

通过运行以下命令创建 Deployment:

```bash
kubectl apply -f nginx-deployment.yaml
```

运行 `kubectl get deployments.apps -o wide` 检查 Deployment 是否已创建：

```bash
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS    IMAGES                 SELECTOR
nginx-deployment         3/3     3            3           34s   nginx         nginx:1.14.2           app=nginx
```

在检查集群中的 Deployment 时，所显示的字段有：

- `NAME` 列出了集群中 Deployment 的名称。
- `READY` 显示应用程序的可用的副本数，显示的模式是“就绪个数/期望个数”。
- `UP-TO-DATE` 显示为了达到期望状态已经更新的副本数。
- `AVAILABLE` 显示应用可供用户使用的副本数。
- `AGE` 显示应用程序运行的时间。

请注意期望副本数是根据 `.spec.replicas` 字段设置 3。

运行 `kubectl rollout status deployment nginx-deployment` 查看 Deployment 上线状态：

```bash
deployment "nginx-deployment" successfully rolled out
```

要查看 Deployment 创建的 ReplicaSet（`rs`），运行 `kubectl get rs`。 输出类似于：

```bash
NAME                                DESIRED   CURRENT   READY   AGE
nginx-deployment-66b6c48dd5         3         3         3       5m5s
```

要查看每个资源自动生成的标签，运行 `kubectl get pods --show-labels`。返回以下输出：

```bash
NAME                                      READY   STATUS    RESTARTS   AGE     LABELS
nginx-deployment-66b6c48dd5-5jd4w         1/1     Running   0          7m20s   app=nginx,pod-template-hash=66b6c48dd5
nginx-deployment-66b6c48dd5-js2bx         1/1     Running   0          7m20s   app=nginx,pod-template-hash=66b6c48dd5
nginx-deployment-66b6c48dd5-mqsnj         1/1     Running   0          7m20s   app=nginx,pod-template-hash=66b6c48dd5
```

所创建的 ReplicaSet 确保总是存在三个 `nginx` Pod。

## ReplicaSet

ReplicaSet 的目的是维护一组在任何时候都处于运行状态的 Pod 副本的稳定集合。 因此，它通常用来保证给定数量的、完全相同的 Pod 的可用性。

ReplicaSet 确保任何时间都有指定数量的 Pod 副本在运行。 然而，Deployment 是一个更高级的概念，它管理 ReplicaSet，并向 Pod 提供声明式的更新以及许多其他有用的功能。 因此，我们建议使用 Deployment 而不是直接使用 ReplicaSet ，除非你需要自定义更新业务流程或根本不需要更新。

这实际上意味着，你可能永远不需要操作 ReplicaSet 对象：而是使用 Deployment，并在 spec 部分定义 ReplicaSet 管理你的应用。

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      ti: fr
  template:
    metadata:
      labels:
        ti: fr
    spec:
      containers:
      - name: nginx
        image: nginx
```

你可以看到当前被部署的 ReplicaSet:

```bash
kubectl get rs nginx
```

并看到你所创建的前端：

```bash
NAME    DESIRED   CURRENT   READY   AGE
nginx   3         3         2       11s
```

你也可以查看 ReplicaSet 的状态：

```bash
kubectl describe rs nginx
```

你会看到类似如下的输出：

```bash
Name:         nginx
Namespace:    default
Selector:     ti=fr
Labels:       app=nginx
Annotations:  <none>
Replicas:     3 current / 3 desired
Pods Status:  3 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  ti=fr
  Containers:
   nginx:
    Image:        nginx
    Port:         <none>
    Host Port:    <none>
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Events:
  Type    Reason            Age   From                   Message
  ----    ------            ----  ----                   -------
  Normal  SuccessfulCreate  113s  replicaset-controller  Created pod: nginx-7hxhm
  Normal  SuccessfulCreate  113s  replicaset-controller  Created pod: nginx-mnq9v
  Normal  SuccessfulCreate  113s  replicaset-controller  Created pod: nginx-w9cfq
```

最后可以查看启动了的 Pods:

```bash
kubectl get pods
```

你会看到类似如下的 Pod 信息：

```bash
NAME          READY   STATUS    RESTARTS   AGE
nginx-7hxhm   1/1     Running   0          3m2s
nginx-mnq9v   1/1     Running   0          3m2s
nginx-w9cfq   1/1     Running   0          3m2s
```

## StatefulSets



## DaemonSet

DaemonSet 确保全部（或者某些）节点上运行一个 Pod 的副本。 当有节点加入集群时， 也会为他们新增一个 Pod 。 当有节点从集群移除时，这些 Pod 也会被回收。删除 DaemonSet 将会删除它创建的所有 Pod。

你可以在 YAML 文件中描述 DaemonSet。

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: default
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
      nodeSelector:
        type: ssd
```

如果指定了 `.spec.template.spec.nodeSelector`，DaemonSet 控制器将在能够与 Node 选择算符匹配的节点上创建 Pod。类似这种情况，可以指定 `.spec.template.spec.affinity`，之后 DaemonSet 控制器将在能够与节点亲和性匹配的节点上创建 Pod。 如果根本就没有指定，则 DaemonSet Controller 将在所有节点上创建 Pod。

## Jobs

下面是一个 Job 配置示例。它负责计算 π 到小数点后 2000 位，并将结果打印出来。 此计算大约需要 10 秒钟完成。

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: perl
        command: ["perl",  "-Mbignum=bpi", "-wle", "print bpi(2000)"]
      restartPolicy: Never
  backoffLimit: 4
```

要查看 Job 对应的已完成的 Pods，可以执行 `kubectl get pods`。

要以机器可读的方式列举隶属于某 Job 的全部 Pods，你可以使用类似下面这条命令：

```bash
pods=$(kubectl get pods --selector=job-name=pi --output=jsonpath='{.items[*].metadata.name}')
echo $pods
```

输出类似于：

```bash
pi-ntb4l
```

这里，选择算符与 Job 的选择算符相同。`--output=jsonpath` 选项给出了一个表达式， 用来从返回的列表中提取每个 Pod 的 name 字段。

查看其中一个 Pod 的标准输出：

```bash
kubectl logs $pods
```

类似于：

```bash
3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679821480865132823066470938446095505822317253594081284811174502841027019385211055596446229489549303819644288109756659334461284756482337867831652712019091456485669234603486104543266482133936072602491412737245870066063155881748815209209628292540917153643678925903600113305305488204665213841469519415116094330572703657595919530921861173819326117931051185480744623799627495673518857527248912279381830119491298336733624406566430860213949463952247371907021798609437027705392171762931767523846748184676694051320005681271452635608277857713427577896091736371787214684409012249534301465495853710507922796892589235420199561121290219608640344181598136297747713099605187072113499999983729780499510597317328160963185950244594553469083026425223082533446850352619311881710100031378387528865875332083814206171776691473035982534904287554687311595628638823537875937519577818577805321712268066130019278766111959092164201989380952572010654858632788659361533818279682303019520353018529689957736225994138912497217752834791315155748572424541506959508295331168617278558890750983817546374649393192550604009277016711390098488240128583616035637076601047101819429555961989467678374494482553797747268471040475346462080466842590694912933136770289891521047521620569660240580381501935112533824300355876402474964732639141992726042699227967823547816360093417216412199245863150302861829745557067498385054945885869269956909272107975093029553211653449872027559602364806654991198818347977535663698074265425278625518184175746728909777727938000816470600161452491921732172147723501414419735685481613611573525521334757418494684385233239073941433345477624168625189835694855620992192221842725502542568876717904946016534668049886272327917860857843838279679766814541009538837863609506800642251252051173929848960841284886269456042419652850222106611863067442786220391949450471237137869609563643719172874677646575739624138908658326459958133904780275901
```
