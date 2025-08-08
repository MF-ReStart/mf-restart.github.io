# MySQL 版本选择

MySQL 的发行版主要有 Oracle MySQL、Percona server for MySQL、MariaDB 三个版本，其中 Percona 的版本命名和 MySQL 官方的版本命名一致，MySQL 版本和 MariaDB 版本如下表：

| MariaDB 版本 | MySQL 版本 |
| ------------ | ---------- |
| MariaDB 10.3 | MySQL 8.0  |
| MariaDB 10.2 | MySQL 5.7  |
| MariaDB 10.1 | MySQL 5.6  |
| MariaDB 10.0 | MySQL 5.5  |
| MariaDB 5.5  | MySQL 5.5  |

在为企业安装生产级的 MySQL 版本时，先确定使用那个发行版的 MySQL，再确定具体的版本号（GA）。一般使用 20+ 并且版本号为双数的小版本。

| Software | Releases | GA_DATE  | Premier_end_date | End_of_Life_Date |
| -------- | -------- | -------- | ---------------- | ---------------- |
| MySQL    | 8.0      | 20180419 | 20230419         | 20260419         |
| MySQL    | 5.7      | 20151021 | 20201021         | 20231021         |
| MySQL    | 5.6      | 20130205 | 20180205         | 20210205         |
| Percona  | 5.7      | 20160203 | 20201001         | 20231001         |
| Percona  | 5.6      | 20131007 | 20180201         | 20210201         |
| MariaDB  | 10.3     | 20180525 | 20230525         |                  |
| MariaDB  | 10.2     | 20170523 | 20220523         |                  |
| MariaDB  | 10.1     | 20151017 | 20201017         |                  |



# MySQL 预装准备

## 硬件标准

选择 x86_64 架构的 Linux 服务器。

如果条件允许，选择更多核心数的高速 CPU。

内存一般来说越大越好，最好所有热点数据都在内存中。条件不允许就遵循 20% 原则。

预估数据量的增长选择合适的磁盘空间，使用更高 IOPS 的 SSD 磁盘，配置 RAID10。

配置双网卡绑定 bond，建议选择主备模式，交换机要做堆叠。

## 操作系统标准

为了操作系统的稳定性，一般采用 Centos 发行版。但因为某些原因，现在 Ubuntu 也被更多人使用。推荐使用 Centos 的 [CentOS-7-x86_64-DVD-2009.iso](http://mirror.aktkn.sg/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-DVD-2009.iso) 和 Ubuntu 的 [ubuntu-22.04.2-live-server-amd64.iso](https://releases.ubuntu.com/22.04.2/ubuntu-22.04.2-live-server-amd64.iso) 镜像。

## 操作系统配置

NUMA（Non-Uniform Memory Access，非一致性内存访问）是一种内存架构，内存被分成多个区域（或节点），每个节点与一个或多个处理器物理绑定。其中不同的处理器节点可以访问不同的物理内存，这是为了支持大规模多处理器系统。但是，这种访问可能会导致延迟和性能问题。

处理器更快地访问与自己直接相连的本地内存，而访问其他节点的内存（远程内存）时，会导致访问延迟增加，从而影响性能。

在 NUMA 系统中，每个处理器节点都有自己的内存控制器和内存通道。如果多个处理器节点尝试访问同一块内存，会导致内存带宽限制，从而影响性能。

```bash
# 关闭NUMA
vim /etc/default/grub
GRUB_CMDLINE_LINUX="numa=off"
grub2-mkconfig -o /etc/grub2.cfg
reboot

# 输出结果显示numa=off
dmesg | grep -i numa
```



THP（Transparent Huge Pages）是一种 Linux 内核中的特性，用于提高系统性能，它会将内存页面（page）合并成更大的页面（huge page）来减少页表的数量和页表操作的次数，从而降低了 CPU 的开销。

但是 THP 在 MySQL 服务器上可能会引起性能问题，因为 MySQL 的负载访问特征通常是离散的，并不是连续的内存访问模式。THP 可能会导致 MySQL 分配大块内存时变慢，因为大块内存需要被分割成更小的块，这可能会导致额外的内存分配和释放操作，影响性能。还会导致 MySQL 无法将大块内存分配给需要使用大量内存的操作，如排序、临时表等。

为了获得最佳的 MySQL 性能，建议在运行 MySQL 的服务器上禁用 THP。

```bash
# 关闭THP
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# 输出为[never]则禁用成功
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag

# [never] 表示禁用
# [always] 表示启用
# [madvise] 表示在MADV_HUGEPAGE标志的VMA中启用
```



Linux 内核在系统内存不足时会进行交换内存，但对于 MySQL 服务器来说这并不是好事，因为交换分区的速度比内存慢得多。所以在 MySQL 服务器上 vm.swappiness 参数一般设置为较低的值，如果条件允许也可以设置为 0（表示不进行交换内存），但如果内存不足时会有 OOM 的风险。

```bash
vm.swappiness = 5
```

Linux 系统中的脏页（dirty pages）也影响着 MySQL 的性能，脏页是指已经被修改但尚未写入磁盘的内存页面。

vm.dirty_ratio 参数控制系统中允许脏页（已被修改但未写入磁盘的内存页）占用的最大内存比例。当脏页的比例达到该值时，内核会启动一个后台进程（即pdflush或bdflush），将脏页写入磁盘，从而释放内存。

vm.dirty_background_ratio 参数控制系统中脏页的后台写入进程（pdflush或bdflush）启动的阈值。当脏页的比例达到该值时，内核会启动后台写入进程将脏页写入磁盘。

在脏页写入磁盘的过程中脏页也在不断的产生。当脏页的比例达到 vm.dirty_background_ratio 参数值时，内核会启动后台写入进程，将一部分脏页写入磁盘。当脏页的比例达到 vm.dirty_ratio 参数值时，内核会启动更多的后台写入进程，将更多的脏页写入磁盘，直到脏页的比例降到 vm.dirty_background_ratio 参数值以下。

vm.dirty_background_ratio 参数的值应该小于 vm.dirty_ratio 的值，以确保系统中始终有一定数量的脏页可以被写入磁盘，从而保证系统的稳定性和可用性。

```bash
vm.dirty_ratio = 20
vm.dirty_background_ratio = 10
```



在 MySQL 有大量客户端连接请求时，网络栈的参数对 MySQL 的性能也有一定影响。

当有大量的连接请求同时到达系统时，内核将无法处理所有的请求，因此需要对这些请求进行排队处理。该参数用于设置系统中未完成（半连接）连接请求的最大数量。

```bash
net.ipv4.tcp_max_syn_backlog = 196605
```

当数据包到达一个网络接口时，内核将把它们加入该接口的接收队列中，等待进一步处理。如果该队列已满，则新到达的数据包将被丢弃。该参数用于设置系统中每个网络接口接收数据包的最大队列长度。

```bash
net.core.netdev_max_backlog = 10000
```

当一个客户端向服务器发送连接请求时，服务器会将该请求加入该套接字的未完成连接队列中，等待进一步处理。如果该队列已满，则新到达的连接请求将被拒绝。该参数用于设置系统中每个套接字（Socket）上的未完成连接队列的最大长度。

```bash
net.core.somaxconn = 4096
```

在默认情况下，Linux 内核会在 TIME_WAIT 状态下保持 2MSL 时间，以确保所有的报文都被完全传递。

这里我们设置内核将允许重用处于 TIME_WAIT 状态的连接。

```bash
net.ipv4.tcp_tw_reuse = 1
```

启用 TCP 连接的快速回收机制，可以更快地释放处于 TIME_WAIT 状态的连接资源。

```bash
net.ipv4.tcp_tw_recycle = 1
```

对修改的内核参数配置永久生效。

```bash
sysctl --system
```



我们在挂载文件系统的时候，可以加上 noatime 和 nodirtime 参数。表示当访问文件和目录时不更新文件和目录的时间戳（修改还是会更新时间戳），可以减少磁盘的读写操作提高系统的性能。

```bash
/dev/sdb /data xfs defaults,noatime,nodiratime 0 1
```

## 压力测试

使用 stress-ng 工具对 CPU 和内存进行压测。

```bash
yum install -y stress

# 启动两个worker进程执行socket调用
stress-ng --sock 2

# 启动两个worker进程每个进程分配1G内存
stress-ng --vm 2 --vm-bytes 1G --timeout 10
```

使用 fio 工具对磁盘的 IO 性能做压测。

```bash
yum install libaio libaio-devel fio

dd if=/dev/zero of=/test.file bs=16k count=512000

# 随机写
fio --filename=/test.file --iodepth=4 --ioengine=libaio -direct=1 --rw=randwrite --bs=16k --size=2G --numjobs=64 --runtime=20 --group_reporting --name=test-rand-write

# 顺序读
fio --filename=test.file -iodepth=64 -ioengine=libaio --direct=1 --rw=read --bs=1m --size=2g --numjobs=4 --runtime=10 --group_reporting --name=test-read

# 70读取，30写入
fio --filename=/test.file --direct=1 --rw=randrw --refill_buffers --norandommap --randrepeat=0 --ioengine=libaio --bs=4k --rwmixread=70 --iodepth=16 --numjobs=16 --runtime=60 --group_reporting --name=73test

--filename 需要压测的磁盘或者测试文件
--direct=1 绕过文件系统缓存
-ioengine=libaio 采用异步或者同步 IO
-iodepth=64 IO 一次发起多少个 IO 请求
--numjobs=16 测试并发线程数
--rwmixread=70 混合读写中 read 的比例
--group_reporting 统计汇总结果展示
--rw=randrw 压测的类型
```



# 安装生产级 MySQL

> https://dev.mysql.com/downloads/mysql/

```bash
# 卸载mariadb
rpm -qa | grep mariadb
yum remove -y

# 确定服务器的glibc版本，下载与服务器glibc版本匹配的mysql软件包，可以确保在安装和运行mysql时获得最佳的兼容性和稳定性
Ubuntu/Debian使用 `ldd --version` 命令查看glibc版本
CentOS/RHEL使用 `rpm -q glibc` 命令查看glibc版本

# 下载
wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.32-linux-glibc2.12-x86_64.tar.xz

# 解压软件
xz -d mysql-8.0.32-linux-glibc2.12-x86_64.tar.xz && tar xf mysql-8.0.32-linux-glibc2.12-x86_64.tar

# 添加环境变量
mv mysql-8.0.32-linux-glibc2.12-x86_64 /usr/local/mysql
vim /etc/profile
export PATH=/usr/local/mysql/bin:$PATH
source /etc/profile

# 创建组和用户
groupadd mysql
useradd -g mysql -s /sbin/nologin -d /usr/local/mysql -MN mysql

# 创建数据目录
mkdir /data/mysql/{data,logs,log-bin,pid,tmp} -p

# 创建配置文件（服务器配置8c16g，mysql version 8.0.32）
<<------
################--< 客户端参数配置 >--################
[client]
# mysql命令的连接端口，仅对本机mysql命令生效
port = 3306

# mysql命令的socket路径，仅对本机mysql命令生效
socket = /data/mysql/tmp/mysql.sock

[mysql]
# 客户端默认字符集
default-character-set = 'utf8mb4'

# 定义命令提示符，格式为(用户@主机名) [当前数据库名]>
prompt = "(\u@\h) [\d]> "

# 关闭sql自动补全
no-auto-rehash

################--< 服务端参数配置 >--################
[mysqld]
# 使用mysql用户运行
user = mysql

# mysql服务器的监听端口，对客户端生效
port = 3306

# mysql服务器监听的IP地址，下面表示监听所有可用IP
bind-address = 0.0.0.0

# mysql服务器的唯一标识符
server-id = 1

# mysql服务器监听的socket，对客户端生效
socket = /data/mysql/tmp/mysql.sock

# mysql服务进程id的文件路径
pid_file = /data/mysql/pid/mysql.pid

# mysql安装的基础目录
basedir = /usr/local/mysql

# mysql存储数据文件的目录
datadir = /data/mysql/data

# mysql存储临时文件的目录
tmpdir = /data/mysql/tmp

# 关闭客户端字符集校对握手，始终使用默认字符集
character-set-client-handshake = 0

# 设置默认字符集
character-set-server = utf8mb4

# 设置默认字符集校对规则
collation-server = utf8mb4_general_ci

# 初始化连接的字符集
init_connect = 'SET NAMES utf8mb4'

# 使用系统本地时间戳来记录日志
log_timestamps = system

# 开启通用查询日志
general_log = 1

# 定义通用查询日志的路径
general_log_file  = /data/mysql/logs/mysql-general.log

# 定义错误日志路径
log_error = /data/mysql/logs/mysql-err.log

# 开启慢查询日志
slow_query_log = 1

# 超过30秒的查询语句会被记录到慢查询日志
long_query_time  = 30

# 慢查询日志文件路径
slow_query_log_file = /data/mysql/logs/mysql-slow.log

# 开启全局事务标识符(gtid)功能
# 我们习惯将参数结果ON写成1，但是gtid_mode参数的NO并不等于1
# OFF=0，OFF_PERMISSIVE=1，ON_PERMISSIVE=2，ON=3 
gtid_mode = 3

# 开启强制执行gtid一致性
enforce_gtid_consistency = 1

# 允许从服务器记录复制的事务到其二进制日志中
log_slave_updates = 1

# 启动时会执行中继日志的恢复操作
relay_log_recovery = 1

# 自动删除已经应用到从服务器上的中继日志
relay-log-purge = 1

# 定义二进制日志的路径和文件名前缀
log-bin = /data/mysql/log-bin/mysql-bin

# 指定二进制日志的格式，记录每行受影响的数据
binlog_format = row

# 在二进制日志为row格式下，full表示mysql会记录完整的行数据并包括所有列
binlog_row_image = full

# 指定单个二进制日志文件的大小
max_binlog_size = 1G

# 指定二进制日志文件的自动删除时间，单位是秒
binlog_expire_logs_seconds = 604800

# 每提交1000个事务就把binlog刷到磁盘，1最安全但性能最低，0是由系统决定何时刷到磁盘，性能最好但风险最大
sync_binlog = 1000

# group commit时每个事务延迟100ms后才开始同步，让多个事务一起写入二进制日志提高写入效率
binlog_group_commit_sync_delay = 100

# 没有等待时间的情况下，group commit中的事务数量达到100就会直接提交
binlog_group_commit_sync_no_delay_count = 100

# 0 事务提交时不将事务日志写入磁盘，而是每秒钟将事务日志缓冲区中的数据写入磁盘(即以"最多丢失1秒数据"为代价换取更好的性能)
# 1 每次提交事务时都将事务日志写入磁盘，这样可以确保数据完全不会丢失，但写入磁盘的操作会带来很大的性能开销
# 2 每次提交事务时将事务日志写入系统缓存但并不立即写入磁盘，直到日志缓存区达到一定大小或者时间到达指定的时间间隔时才将日志写入磁盘
# mysql常说的双1策略就是将sync_binlog和innodb_flush_log_at_trx_commit都设置为1，这是数据最安全的情况但却会带来很大的性能开销
innodb_flush_log_at_trx_commit = 1

# 1为大小写不敏感，可以避免sql因为大小写带来的问题，但需要确保表和数据库名称的唯一性
lower_case_table_names = 1

# 指定服务器默认时区为东八区
default-time-zone = '+8:00'

# 关闭DNS解析以加快访问速度
skip_name_resolve = 1

# 指定mysql服务器缓存可以打开多少张表
table_open_cache = 8000

# 指定表缓存实例的个数，每个实例可以缓存(table_open_cache / table_open_cache_instances)张表
table_open_cache_instances = 64

# 表示线程栈的大小，如果应用需要使用很多线程则增大该参数的值
thread_stack = 512K

# 内存临时表的最大值
max_heap_table_size = 64M

# sql进行排序的缓冲区大小，当执行order by、group by等操作时会使用这个缓冲区来暂存排序数据，越大性能越好
sort_buffer_size = 8M

# 指定mysql用于处理join操作时使用的缓冲区大小
join_buffer_size = 8M

# 指定内存中存储临时表的大小
tmp_table_size = 64M

# 指定所有使用内存存储的临时表的最大大小，通常设置成tmp_table_size一样的值
max_heap_table_size = 64M

# 每个客户端连接错误的最大次数，超出则禁止连接
max_connect_errors = 1000

# 允许的最大并发连接数，包括所有客户端和各种系统线程连接
max_connections = 2000

# 一个非交互式连接在无任何活动状态下被关闭之前的秒数
wait_timeout = 300

# 一个交互式连接在无任何活动状态下被关闭之前的秒数
interactive_timeout = 1800

# 连接到mysql服务器的超时时间
connect_timeout = 30

# 当mysql到达最大连接数时，新的连接请求将被放入这个队列
back_log = 1024

# 指定默认的身份验证插件，8.0之后默认是caching_sha2_password
default_authentication_plugin = mysql_native_password

# innodb存储引擎数据文件的目录
innodb_data_home_dir = /data/mysql/data

# innodb存储引擎日志文件的目录
innodb_log_group_home_dir = /data/mysql/data

# innodb存储引擎数据文件的路径和大小，可以自动增加
innodb_data_file_path = /data/mysql/data/ibdata1:1G:autoextend

# innodb存储引擎临时数据文件的路径和大小
innodb_temp_data_file_path = ibtmp1:512M:autoextend

# 指定缓冲池的大小，innodb用于缓存表的数据和索引，一般设置为内存的60%~80%，增大缓冲池可以减少磁盘的io提高性能
innodb_buffer_pool_size = 200M

# innodb将缓冲池分成指定数量的实例以进行并发控制，通常设置为CPU核心数
innodb_buffer_pool_instances = 8

# innodb可用于处理查询的并发线程数
innodb_thread_concurrency = 8

# innodb用于写入redo log的缓冲区大小
innodb_log_buffer_size = 128M

# innodb_log_file_size和innodb_log_files_in_group已经在8.0.30被弃用
# innodb会在#innodb_redo目录下创建32个redo log文件，每个文件大小等于innodb_redo_log_capacity / 32，#ib_redoXXX是活跃的，#ib_redoXXX是备用的
innodb_redo_log_capacity = 4G

# 查询期间排序数据的缓冲区的大小
innodb_sort_buffer_size = 8M

# innodb可以用于脏页面(即已修改但尚未写入磁盘的页面)的缓冲池百分比
innodb_max_dirty_pages_pct = 50

# innodb获取被锁定资源的最大等待时间
innodb_lock_wait_timeout = 50

# innodb可以执行的最大io操作次数，根据磁盘iops能力调整
innodb_io_capacity = 4000

# innodb在高峰工作负载期间可以执行的最大io操作次数，根据磁盘iops能力调整
innodb_io_capacity_max = 8000

# innodb用于将数据写入磁盘的io线程数
innodb_write_io_threads = 8

# innodb用于从磁盘读取数据的io线程数
innodb_read_io_threads = 8

# innodb用于从缓冲池清除旧数据的线程数
innodb_purge_threads = 4

# innodb在后台执行页清理操作的线程数，负责从缓冲池中将脏页(已修改但尚未写入磁盘的页)写回到磁盘
innodb_page_cleaners = 4

# 可能用到而且对myisam表起作用的参数
key_buffer_size = 32M
read_buffer_size = 8M
read_rnd_buffer_size = 4M
bulk_insert_buffer_size = 64M

[mysqldump]
# 在转储大的表时，强制mysqldump一次一行检索表中的行，而不是检索所有行并在输出前将它缓存到内存中
quick
------>>

# 目录授权
chown -R mysql:mysql /usr/local/mysql/ # 二进制安装文件
chown -R mysql:mysql /data/mysql # 数据目录

# 初始化MySQL
/usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf --initialize-insecure
```

# MySQL 体系结构

## MySQL 实例组成

一个 MySQL 实例主要由以下几部分组成。一个物理服务器上可以运行多个 MySQL 实例，每个实例可以管理多个数据库。每个实例拥有独立的端口号和配置，使得它们可以独立地响应客户端连接和查询请求。通常，每个 MySQL 实例都有自己的数据目录，这样不同的实例之间的数据可以相互隔离。

<img src="https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/Mysql-Instance.png" alt=" " style="zoom:50%;" />

## MySQL 内存结构

Buffer Pool 是 MySQL 最重要的内存结构之一，它是用于缓存磁盘上的数据页的内存区域。当 MySQL 读取或修改数据时，数据页被加载到 Buffer Pool 中，以便后续的查询可以更快地访问相同的数据。Buffer Pool 的大小是通过配置`innodb_buffer_pool_size`参数来控制的。较大的 Buffer Pool 通常可以提供更好的性能，因为更多的数据可以驻留在内存中，减少了对磁盘的访问。

Change Buffer 是 InnoDB 存储引擎的一个组成部分。它用于延迟执行对非唯一辅助索引的插入、更新和删除操作，直到有查询需要使用这些索引时。这些更改会先被缓存在 Change Buffer 中，然后在后台异步地合并到实际的索引页中。通过使用 Change Buffer，可以减少直接对索引页的磁盘 I/O 操作，从而提高写入性能。

Log Buffer 是用于缓存事务日志的内存区域。当执行事务时，MySQL 会将事务的修改操作记录到日志缓冲区中，然后异步地将日志写入到磁盘的事务日志文件。这种异步写入方式可以减少事务提交的响应时间，因为事务不必等待日志写入完成才能完成提交。

以上的内存结构都属于 Global Buffer，针对整个 MySQL 实例，对于所有连接都是共享的。另外 MySQL 还有 Session Buffer，例如 read_buffer、sort_buffer、join_buffer 等，这些都是独立于会话级别的缓冲区，用于保证会话数据隔离或提供会话特定的功能。

## MySQL 线程

Main Thread 在 MySQL 启动时创建。主线程负责监听网络连接，接受客户端连接请求，并将连接分配给其他线程进行处理。主线程也负责处理一些全局的任务，例如日志记录、定时器和一些全局变量的维护。

当一个客户端与 MySQL 服务器建立连接时，服务器会为该连接创建一个独立的 Connection Thread。每个连接线程负责处理特定客户端的请求。它会读取客户端发送的查询请求，将查询传递给查询处理引擎，然后将结果返回给客户端。连接线程之间是相互独立的，它们不共享状态。

Query Thread 也称为工作者线程（Worker Threads）。MySQL 使用线程池来管理这些线程。查询处理线程从连接线程中获取查询任务，并在独立的线程中执行这些查询。一旦查询完成，结果将被返回给连接线程，连接线程再将结果返回给客户端。查询处理线程的数量可以通过配置`thread_pool_size`参数来调整。

IO Thread 是在 MySQL 复制（replication）中使用的线程类型。它主要用于实现主从复制功能。MySQL 的复制机制允许从主服务器复制二进制日志（binary log）中的更改操作到从服务器，以保持主从数据的一致性。

Purge Thread 是在 MySQL 的复制中使用的线程类型。它的主要目标是清理从服务器上不再需要的二进制日志文件。一旦从服务器成功地应用了二进制日志中的更改操作，就没有必要再保留这些日志文件。清理线程负责定期检查并删除不再需要的二进制日志文件，从而节省磁盘空间。

Page Cleaner 是 InnoDB 存储引擎中的一个后台线程类型。它负责管理 Buffer Pool 中的脏页。当数据在 Buffer Pool 中被修改时，相应的数据页被标记为“脏页”，表示需要刷新回磁盘以保持数据的持久性。页清理线程定期检查 Buffer Pool 中的脏页，并将其异步刷新回磁盘，从而确保数据的持久性，并维护 Buffer Pool 的可用空间。

##  SQL 语句处理逻辑

MySQL 是一个 CS 架构的软件。客户端可以是终端工具、脚本、API 等，客户端会通过数据库驱动（如 JDBC、ODBC）与数据库建立连接，使用数据库提供的接口与服务器通信。数据库服务器接收到 SQL 语句后会先进入连接层，然后确认连接协议，验证用户权限以及为这个 SQL 语句提供连接线程。

当连接建立后，客户端发送的 SQL 语句会被传递给 SQL 层。SQL 层是数据库系统的核心部分，它负责解析、优化和执行 SQL 语句。它也负责管理存储引擎层与上层应用之间的交互。

SQL 解析包括语法解析和语义检查，数据库检查 SQL 语法是否正确（如关键词是否拼写正确），并将 SQL 语句转化为一个解析树。在语法解析后，系统会进行语义检查，确保表名、字段名、函数等是否存在，并检查用户的权限是否允许执行这条查询。

接着优化器会对 SQL 语句进行逻辑优化和物理优化，逻辑优化包括查询重写、JOIN 顺序调整、子查询优化等。物理优化则会生成具体的执行计划（Execution Plan），决定如何执行 SQL 语句。优化器还会基于统计信息、索引可用性、表大小等因素选择最优的执行路径。

执行器是 SQL 层中的实际操作部分，它按照执行计划去执行查询。执行器会逐步读取数据，并处理过滤、排序、聚合等操作，执行器需要与存储引擎层打交道，来获取具体的数据。最后，执行器从存储引擎中取回结果集，返回结果给客户端。

存储引擎负责处理数据的实际读写操作。执行器会根据执行计划发出数据读写请求，存储引擎层根据数据表结构、索引等信息，从磁盘或缓存中读取相应的数据块。存储引擎通过使用索引（如 B+树、哈希索引等）来加速数据检索。对于支持事务的存储引擎（如 InnoDB），存储引擎还负责事务管理，包括 ACID 特性的保证。存储引擎还使用了各种缓存机制来提高性能，比如 InnoDB 的缓冲池（Buffer Pool）。

最后，存储引擎层将读取的数据块或查询结果返回给 SQL 层的执行器。

<img src="https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/mysql-run-process.png" style="zoom:50%;" />

## InnoDB 体系结构

InnoDB 是 MySQL 的默认存储引擎，专门为高并发、高事务处理能力以及高可靠性场景设计。InnoDB 体系结构主要由内存结构和磁盘结构两部分组成。

其中 InnoDB 的内存结构包括多个组件，在这些组件的共同作用，提升数据库的性能和效率。

<img src="https://hercules-gitbook-image.oss-cn-shenzhen.aliyuncs.com/gitbook/innodb-architecture.png" style="zoom:70%;" />

> 从 MySQL 8.0.19 版本开始，doublewrite buffer 被移到了一个独立的文件中，这个文件通常命名为 ib_doublewrite

# MySQL 基础管理

## 用户管理

在 MySQL 中，用户是指一个能登录数据库并执行操作的账号。每个用户都绑定了访问来源（host）、认证插件（如 mysql_native_password、caching_sha2_password）和权限信息，这些信息都存储在 `mysql.user`  表中。

MySQL 的用户类型大概分为两种。一种是 MySQL 安装后自带的系统用户（例如 root），另一种是我们创建供应用程序和开发人员连接数据库的用户。在做主从复制的时候，还可以创建复制用户（只授予 REPLICATION SLAVE 权限）。有些低版本的数据库，默认安装后可能存在匿名用户，即没有用户名（user 为空字符串），建议删除。

MySQL 创建用户在 5.7 和 8.0 的区别

```mysql
# 5.7 可以用 GRANT 同时创建用户和授权
grant all privileges on dbname.* to 'user'@'%' identified by 'password';

# 8.0 之后必须先创建用户再用 GRANT 授权
create user 'user'@'%' identified by 'password';
grant all privileges on dbname.* to 'user'@'%';
```

在创建用户的时候，还可以指定用户的认证插件，5.7 版本使用的是 mysql_native_password，8.0 默认使用了新的认证插件 caching_sha2_password。

mysql_native_password 插件使用 `SHA1` 加密，安全性较低，在弱密码的情况下有可能被破解，但是兼容好，几乎所有的客户端和驱动都支持。

caching_sha2_password 插件使用 `SHA256` 加密，安全性更高，

```mysql
CREATE USER 'user'@'%' IDENTIFIED WITH mysql_native_password BY 'password';

```



## 权限管理



## 授权管理





# MySQL 的连接方式



# MySQL 的启动和关闭



















# MySQL 日志配置管理



# MySQL 的升级和降级







