# 安装 MySQL

>  https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.32-linux-glibc2.12-x86_64.tar.xz

```bash
# 卸载 mariadb
rpm -qa | grep mariadb
yum remove -y 

# 解压软件
xz -d mysql-8.0.32-linux-glibc2.12-x86_64.tar.xz
tar xf mysql-8.0.32-linux-glibc2.12-x86_64.tar

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

# 创建配置文件
vim /etc/my.cnf

# 目录授权
chown -R mysql:mysql /usr/local/mysql/ # 二进制安装文件
chown -R mysql:mysql /data/mysql # 数据目录

# 初始化 MySQL
/usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf --initialize-insecure

# 启动 MySQL 的方式
/usr/local/mysql/bin/mysqld --defaults-file=/etc/my.cnf --user=mysql &

cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld
systemctl enable mysqld
systemctl start mysqld
```

# 搭建主从复制

| 服务器              | 系统版本                      | MySQL 版本 |
| ------------------- | ----------------------------- | ---------- |
| 10.10.110.11-master | CentOS Linux release 7.9.2009 | 8.0.32     |
| 10.10.110.12-slave  | CentOS Linux release 7.9.2009 | 8.0.32     |
| 10.10.110.13-slave  | CentOS Linux release 7.9.2009 | 8.0.32     |

```bash
# master 节点创建复制用户和远程管理用户
create user repl@'10.10.110.%' identified with mysql_native_password by '123456';
grant replication slave on *.* to repl@'10.10.110.%';

create user root@'10.10.110.%' identified with mysql_native_password by '123456';
grant all on *.* to root@'10.10.110.%';

# 生成测试数据
create table t1(id int primary key not null auto_increment,content varchar(128),num int,create_time datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',update_time datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最后修改时间');

mysqlslap -u'root' -p'123456' -h'10.10.110.11' --number-of-queries=100000 --create-schema=t1 --concurrency=10 --query="insert into t(content,num) values(uuid(),rand()*1000);"

# 在从库上备份主库的数据
mysqldump -u'root' -p'123456' -h'10.10.110.11' -P'3306' -A --source-data=2 --single-transaction -R -E --triggers > /tmp/full.sql

# 将主库的数据导入到从库
source /tmp/full.sql; # 此刻从库上的数据和主库一致（主库不再有数据写入的前提）

# 在从库上配置主从信息
change master to \
master_host='10.10.110.11', \
master_user='repl', \
master_password='123456', \
master_port=3306, \
master_auto_position=1; # 基于 GTID 复制

# 在从库上启动主从复制并查看复制情况
start slave;
show slave status\G
```

# 安装 ProxySQL

```bash
# 下载 ProxySQL
https://github.com/sysown/proxysql/releases

# 在主库上安装 ProxySQL
rpm -ivh proxysql-2.5.3-1-centos7.x86_64.rpm
yum install -y proxysql-2.5.3-1-centos7.x86_64.rpm # 解决依赖
```

# ProxySQL 管理数据库的结构

```bash
# ProxySQL 的 6032 端口是管理接口
# 自带的五个数据库分别是main、disk、stats、monitor、stats_history

# main（表名以 runtime_ 开头的表示 ProxySQL 当前运行的配置内容，不能直接修改）
mysql_servers: 后端可以连接 MySQL 服务器的列表
mysql_users: 配置后端数据库的账号和监控的账号
mysql_query_rules: 指定 Query 路由到后端不同服务器的规则列表
mysql_replication_hostgroups: 节点分组配置信息

# disk
持久化的磁盘的配置

# stats
统计信息的汇总

# monitor
监控的收集信息(比如数据库的健康状态)

# stats_history
ProxySQL 收集的有关其内部功能的历史指标
```

# ProxySQL 各配置层的关系

```bash
# RUNTIME
代表 ProxySQL 当前正在使用的配置，无法直接修改此配置，必须要从下一层(MEM层)"load"进来

# MEMORY
MEMORY 层上面是 RUNTIME 层，下面是 DISK 层。这层可以在线修改 ProxySQL 的配置，不会影响正在使用的配置。
修改好并确认没问题后，可以"load"到 RUNTIME 层，也可以"save"到 DISK 层。

# DISK / CFG FILE
持久化配置信息。ProxySQL 重启后可以从磁盘加载之前持久化的配置

# 注意
只有"load"到 runtime 状态时才会验证配置。在"save"到 MEM 或 disk 时，都不会发生任何警告或错误
如果"load"到 runtime 出现错误，会恢复到之前的状态
```

# ProxySQL 基于 SQL 读写分离

```sql
# 登录 ProxySQL 管理接口
mysql -uadmin -padmin -h127.0.0.1 -P6032

# web 界面管理
update global_variables set variable_value='true' where variable_name='admin-web_enabled';
load admin variables to runtime;
save admin variables to disk;
select * from global_variables where variable_name like 'admin-web%' or variable_name like 'admin-stats%';
需要使用 https 才能访问，https://10.10.110.11:6080

# 配置读写组的信息
insert into mysql_replication_hostgroups (writer_hostgroup, reader_hostgroup, comment) values (1,2,'proxy');
load mysql servers to runtime;

# 查看
(admin@127.0.0.1) [(none)]> select * from mysql_replication_hostgroups;
+------------------+------------------+------------+---------+
| writer_hostgroup | reader_hostgroup | check_type | comment |
+------------------+------------------+------------+---------+
| 1                | 2                | read_only  | proxy   |
+------------------+------------------+------------+---------+
1 row in set (0.00 sec)

# 配置后端节点
# ProxySQL 根据 read_only 的值对服务器进行分组
# read_only = 0 会被分到编号为 1 的写组，read_only = 1 会被分到编号为 2 的读组
# 为了保证数据的一致性（只在主库写入），所以从库必须设置 read_only = 1，super_read_only = 1
# 还可以根据 mysql 节点的配置性能，合理定义 weight 权重值（权重值越高会接收更多的请求）
insert into mysql_servers(hostgroup_id,hostname,port) values (1,'10.10.110.11',3306);
insert into mysql_servers(hostgroup_id,hostname,port) values (2,'10.10.110.12',3306);
insert into mysql_servers(hostgroup_id,hostname,port) values (2,'10.10.110.13',3306);
load mysql servers to runtime;
save mysql servers to disk;

(admin@127.0.0.1) [(none)]> select * from mysql_servers;

# 创建监控用户（在 MySQL 主库创建），用于检测 MySQL 服务器的健康状态
create user monitor@'10.10.110.%' identified with mysql_native_password by '123456';
grant usage, replication client on *.* to monitor@'10.10.110.%';

# 将监控用户的凭据添加到 ProxySQL
update global_variables set variable_value='monitor' where variable_name='mysql-monitor_username';
update global_variables set variable_value='123456' where variable_name='mysql-monitor_password';
load mysql variables to runtime;
save mysql variables to disk;

# 查询监控日志情况
select * from mysql_server_connect_log;
select * from mysql_server_ping_log;
select * from mysql_server_read_only_log;
select * from mysql_server_replication_lag_log;

# 配置程序连接用户（在 MySQL 主库创建）
create user 'app'@'10.10.110.%' identified with mysql_native_password by '123456';
grant all on *.* to 'app'@'10.10.110.%';

# 将程序用户的凭据添加到 ProxySQL
# 通过定义 default_hostgroup 我们指定用户应该默认连接到哪些后端服务器
# default_hostgroup 字段与 mysql_servers 表的 hostgroup_id 字段关联
insert into mysql_users(username,password,default_hostgroup) values('app','123456',1);
load mysql users to runtime;
save mysql users to disk;

# 配置读写规则
# ProxySQL 会根据 rule_id 的顺序去进行规则匹配
# 所以 ^select.*for update$ 规则的 rule_id 要小于 ^select 才能被优先匹配
# destination_hostgroup 表示要将匹配成功的 sql 转发到那些 mysql 主机组
insert into mysql_query_rules(rule_id,active,match_digest,destination_hostgroup,apply) values(1,1,'^select.*for update$',1,1);
insert into mysql_query_rules(rule_id,active,match_digest,destination_hostgroup,apply) values (2,1,'^select',2,1);

# 通过规则匹配屏蔽 drop 语句（路由到不存在的主机组）
insert into mysql_query_rules(rule_id,active,match_digest,destination_hostgroup,apply) values (3,1,'^drop',3,1);

load mysql query rules to runtime;
save mysql query rules to disk;

# 测试读写分离
mysql -uapp -p123456 -h10.10.110.11 -P6033 -e "select @@server_id"
mysql -uapp -p123456 -h10.10.110.11 -P6033 -e "begin;select @@server_id;commit"

# 查看 SQL 的规则匹配和执行情况
select * from stats_mysql_query_digest;
```

# MHA 高可用搭建

| 服务器              | 安装          | MHA 版本             |
| ------------------- | ------------- | -------------------- |
| 10.10.110.11-master | node          | 0.58（对应mysql8.0） |
| 10.10.110.12-slave  | node          | 0.58（对应mysql8.0） |
| 10.10.110.13-slave  | node，manager | 0.58（对应mysql8.0） |

所有节点都需要安装 node，manager 只在 10.10.110.13-slave 安装

> https://github.com/yoshinorim/mha4mysql-manager
>
> https://github.com/yoshinorim/mha4mysql-node

配置所有节点间的 ssh 互信

```bash
ssh-keygen -t rsa -b 4096

vim .ssh/authorized_keys
```

所有节点安装 node

```bash
yum install -y perl-DBD-MySQL
rpm -ivh mha4mysql-node-0.58-0.el7.centos.noarch.rpm
```

在主库创建 MHA 监控用户（已配置主从的情况下会同步到从库）

```sql
create user 'mha'@'10.10.110.%' identified with mysql_native_password by '123456';
grant all on *.* to 'mha'@'10.10.110.%';
```

安装 manager

```bash
yum install -y perl-Config-Tiny epel-release perl-Log-Dispatch perl-Parallel-ForkManager perl-Time-HiRes
rpm -ivh mha4mysql-manager-0.58-0.el7.centos.noarch.rpm
```

创建 manager 配置文件目录

```bash
mkdir /etc/mha
mkdir -p /data/mha/app1/manager

vim /etc/mha/app1.cnf
[server default]
manager_log=/data/mha/app1/manager/manager.log
manager_workdir=/data/mha/app1
master_binlog_dir=/data/mysql/log-bin/
user=mha
password=123456
ping_interval=2
repl_user=repl
repl_password=123456
ssh_user=root

[server1]
hostname=10.10.110.11
port=3306

[server2]
hostname=10.10.110.12
candidate_master=1
port=3306

[server3]
hostname=10.10.110.13
port=3306
```

MHA 启动前互信检查和主从状态检查

```
masterha_check_ssh --conf=/etc/mha/app1.cnf
masterha_check_repl --conf=/etc/mha/app1.cnf
```

启动 MHA

```bash
nohup masterha_manager --conf=/etc/mha/app1.cnf --remove_dead_master_conf --ignore_last_failover < /dev/null> /data/mha/app1/manager/manager.log 2>&1 &
```

