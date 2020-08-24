# elasticsearch 笔记
版本7.8.1

## 基本操作

---

### **创建索引**

结构
- settings
- index
    - number_of_shards:数据分片数
    - number_of_replicas:数据备份数
- mappings: 
- _all 
- _source:
    - 1.enabled:false 不保存
    - 2.includes:[f1,f2]
    - 3.excludes:[f1,f2]

```
PUT operation_log
{
  "settings" : {
    "index" : {
      "number_of_shards" : 1,
      "number_of_replicas" : 1
    }
  },
  "mappings" : {
    "properties" : {
      "event" : {
        "type" : "keyword",
        "fields" : {
          "keyword" : {
            "type" : "keyword",
            "ignore_above" : 256
          }
        }
      },
      "desc" : {
        "type" : "text",
        "analyzer" : "ik_max_word",
        "search_analyzer" : "ik_max_word",
        "fields" : {
          "raw" : {
            "type" : "keyword"
          },
          "ik_smart_analyzer" : {
            "type" : "text",
            "analyzer" : "ik_smart"
          }
        }
      },
      "user_name" : {
        "type" : "text",
        "fields" : {
          "raw" : {
            "type" : "keyword"
          }
        }
      },
      "user_id" : {
        "type" : "long"
      },
      "log_time" : {
        "type" : "date",
        "format" : "yyyy-MM-dd HH:mm:ss||strict_date_optional_time||epoch_millis"
      }
    }
  }
}
```

### **删除索引、文档**

```
DELETE operation_log(/_doc/id)
```

### **插入文档**

- 指定id，增加版本号
  ```
  PUT/POST operation_log/_doc/1
  {
    "event" : "create_order",
    "desc" : "提交订单：123456",
    "user_name" : "小张",
    "user_id" : "1",
    "log_time" : "2020-08-08 14:00:00"
  }
  ```
- post随机文档id
  ```
  POST operation_log/_doc
  {
    "event" : "create_order",
    "desc" : "提交订单：123456",
    "user_name" : "小张",
    "user_id" : "1",
    "log_time" : "2020-08-08 14:00:00"
  }
  ```

### **批量插入**

  - create:如果存在则失败
  - index:总是成功

```
POST _bulk
{"create":{"_index":"operation_log","_id":1}}
{"event":"create_order","desc":"提交订单：123456","user_name":"小张","user_id":"1","log_time":"2020-08-08 14:00:00"}
{"index":{"_index":"operation_log","_id":2}}
{"event":"handle_order","desc":"处理订单：123456","user_name":"小李","user_id":"2","log_time":"2020-08-08 14:05:30"}
{"index":{"_index":"operation_log","_id":3}}
{"event":"delivery_order","desc":"订单已经发货：123456","user_name":"小明","user_id":"3", "log_time":"2020-08-08 14:15:45"}
{"index":{"_index":"operation_log","_id":4}}
{"event":"receive_package","desc":"收取包裹，订单：123456","user_name":"小快","user_id":"4", "log_time":"2020-08-08 18:20:45"}
```

### **更新**

1. 更新整个文档，同插入
2. 更新指定字段`POST`，文档不存在则不操作
   ```
    POST operation_log/_update/1
    {
      "doc" : {
        "user_name" : "小张"
       }
    }
    ```
3. 指定字段更新或插入
    ```
    POST operation_log/_update/4
    {
      "doc" : {
        "not_exist_field" : "ignore"
      },
      "upsert" : {
        "event" : "receive_package",
        "desc" : "收取包裹，订单：123456",
        "user_name" : "小快",
        "user_id" : "4",
        "log_time" : "2020-08-08 18:25:00"
      }
    }
    ```
4. 全部更新或插入
    ```
    POST /operation_log/_update/3
    {
      "doc" : {
        "event" : "delivery_order",
        "desc" : "订单已经发货：123456",
        "user_name" : "小明",
        "user_id" : "3",
        "log_time" : "2020-08-08 14:15:47"
      },
      "doc_as_upsert" : true
    }
    ```

### **批量更新**

```
POST _bulk
{"update":{"_index":"operation_log","_id":3}}
{"doc":{"log_time":"2020-08-08 14:15:46"}}
```
---

## **`查询`**

两种上下文：
1. Query context，关注“此文档与该查询子句的匹配程度如何？”，除了确定文档是否匹配之外，查询子句还计算_score元字段中的相关性得分 。
2. Filter context，关注“此文档是否与此查询子句匹配？"，答案很简单，是或否，不打分。过滤器上下文主要用于过滤结构化数据。


### **source filter**

```
GET operation_log/_search
{
  "_source" : ["event", "user_id"],
  "query" : {
    "match_all" : {}
  }
}
```

### **查询数量**

```
GET operation_log/_count
{
  "query" : {
    "match_all" : {}
  }
}
```

---

## **`词语级搜索`**

`不会分析检索词`

### **`term`**

```
GET operation_log/_search
{
  "query" : {
    "term" : {
      "desc.raw" : "提交订单：123456"
    }
  }
}
```

### **`terms`**

```
GET operation_log/_search
{
  "query" : {
    "terms" : {
      "desc" : ["提交","处理"]
    }
  }
}
```

### **`terms set`**

同terms，需要指定匹配多少个term
- minimum_should_match_field 指定字段表示需要匹配的个数
- minimum_should_match_script 自定义脚本表示需要匹配的个数
```
GET operation_log/_search
{
  "query" : {
    "terms_set" : {
      "desc" : {
        "terms" : ["处理","订单"],
        // "minimum_should_match_field" : "user_id"
        "minimum_should_match_script" : {
          "source" : "1"
        }
      }
    }
  }
}
```

### **`range`**

- gte : >=
- gt : >
- lte : <=
- lt : <
- format : 日期格式，默认同mapping
- relation : 对类型为 range 字段的查询
- time_zone : UTC时区
- boost : 设置查询的提升值，默认为 1.0

数字/日期，类型为 NumericRangeQuery
```
GET operation_log/_search
{
  "query" : {
    "range" : {
      "user_id" : {
        "gte" : 1,
        "lte" : 2,
        "boost" : 2.0
      }
    }
  }
}
```

#### **日期**

日期格式：
1. 以固定的日期开头，可以是 now 或者是以“||”结尾的时间字符串
2. 固定日期后面可接一个或多个数学表达式
    - +1h 加一小时
    - -1d 减一天
    - /M  四舍五入到最近一月
    - 支持单位: y-Years、M-Months、w-Weeks、d-Days、h-Hours、H-Hours、m-Minutes、s-Seconds

例子：
- now + 1h   ： now的毫秒值 + 1小时
- now - 1h/d ： now的毫秒值 + 1小时，再四舍五入到最近的一天的起始：2020-08-08 00:00:00 或者 结束：2020-08-08 23:59:59.999
- 2020-07-07||-1M/M：2020-07-7 的毫秒值 - 1个月，再根据情况四舍五入到最近的一月的起始：2020-06-01 00:00:00 或者 结束：2020-06-30 23:59:59.999

1. **`gt:  2020-08-08||/M 向上舍入 2020-09-01T00:00:00.000，不包含整个8月`**
2. **`gte: 2020-08-08||/M 向下舍入 2020-08-01T00:00:00.000，包含当月`**
3. **`lt:  2020-08-08||/M 向下舍入 2020-07-31T23:59:59.999，不包含整个8月`**
4. **`lte: 2020-08-08||/M 向上舍入 2020-08-30T23:59:59.999，包含当月`**

```
GET operation_log/_search
{
  "query" : {
    "range" : {
      "log_time" : {
        "time_zone" : "+08:00",
        "gte" : "2020-08-07||/d",
        "lte" : "now-1d/d"
      }
    }
  }
}
```

#### **relation**

准备数据
```
PUT aggregate
{
  "mappings" : {
    "properties" : {
      "interval" : {
        "type" : "integer_range"
      }
    }
  }
}

POST _bulk
{"index":{"_index":"aggregate","_id":"1"}}
{"interval":{"gte":10,"lte":15}}
{"index":{"_index":"aggregate","_id":"2"}}
{"interval":{"gte":10,"lte":20}}
{"index":{"_index":"aggregate","_id":"3"}}
{"interval":{"gte":15,"lte":18}}
{"index":{"_index":"aggregate","_id":"4"}}
{"interval":{"gte":15,"lt":18}}
{"index":{"_index":"aggregate","_id":"5"}}
{"interval":{"gt":15,"lt":18}}
```

- INTERSECTS (Default) 有交集
    ```
    GET aggregate/_search
    {
      "query" : {
        "range" : {
          "interval" : {
            "gte" : 12,
            "lte" : 17,
            "relation" : "intersects"
          }
        }
      }
    }
    ```
- CONTAINS 文档的范围字段完全包含检索关键词的范围
    ```
    GET aggregate/_search
    {
      "query" : {
        "range" : {
          "interval" : {
            "gte" : 12,
            "lte" : 17,
            "relation" : "contains"
          }
        }
      }
    }
    ```
- WITHIN 文档的范围字段要完全在检索关键词的范围
    ```
    GET aggregate/_search
    {
      "query" : {
        "range" : {
          "interval" : {
            "gte" : 12,
            "lte" : 17,
            "relation" : "within"
          }
        }
      }
    }
    ```

### **`模糊查询`**

- wildcard
- prefix
- fuzzy

#### **`wildcard`**

检索包含通配符表达式（未分析）字段的文档
- \* 通配符
- ? 占位符 
```
GET operation_log/_search
{
  "query" : {
    "prefix" : { 
      "desc" : "处*"
    }
  }
}
```

#### **`fuzzy`**

基于Levenshtein编辑距离的相似度，模糊搜索
```
GET operation_log/_search
{
  "query" : {
    "fuzzy" : { 
      "desc" : "处*"
    }
  }
}
```

#### **`prefix`**

查找指定字段包含以指定前缀的词语的文档
- fuzziness：最大编辑距离(一个字符串要与另一个字符串相同必须更改的一个字符数)，默认：AUTO
- prefix_length：不会被“模糊化”的初始字符数。这有助于减少必须检查的术语数量，默认：0
- max_expansions：fuzzy查询将扩展到的最大词语数，默认：50。
- transpositions：是否支持模糊转置(ab->ba)，：默认：false
```
GET operation_log/_search
{
  "query" : {
    "fuzzy" : { 
      "desc" : {
        "value" : "订旦",
        "fuzziness" : 1,
        "prefix_length" : 1,
        "max_expansions" : 2
      }
    }
  }
}
```

#### **`exists`**

查找指定字段包含任何非空值，不包括：
- 空字符串，如""或"-"
- 包含null和另一个值的数组，如[null, "foo"]
- 自定义null-value，在字段映射中定义

可能为not exist的几个场景
- null or []
- mapping中设置"index" : false
- field长度超过mapping中设置的ignore_above
- mapping中设置了ignore_malformed，字段是格式不正确的

```
GET operation_log/_search
{
  "query" : {
    "exists" : { 
      "field" : "desc"
    }
  }
}
```

查询为null的字段，应该使用：must_not + exists
```
GET operation_log/_search
{
  "query" : {
    "bool" : {
      "must_not" : [
        {
          "exists" : {
            "field": "user"
          }
        }
      ]
    }
  }
}
```

### **`regexp`**

```
GET operation_log/_search
{
  "query" : {
    "regexp" : {
      "desc": "处.*"
    }
  }
}
```

### **`ids`**

```
GET operation_log/_search
{
  "query" : {
    "ids" : {
      "values" : ["1", "4"]
    }
  }
}
```

---

## **`全文搜索`**

### **`match`**

match分词，比较倒排索引。

```
GET operation_log/_search
{
  "query" : {
    "match" : {
      "desc" : "发货"
    }
  }
}
```

### **`match_phrase`**

match_phrase的分词结果必须在被检索字段的分词中都包含，而且顺序必须相同，而且默认必须都是连续的。

slop:Token之间的位置距离容差值

```
GET operation_log/_search
{
  "query" : {
    "match_phrase" : {
      "desc" : "订单已经"
    }
  }
}
```
```
GET operation_log/_search
{
  "query" : {
      "match_phrase" : {
      "desc" : {
        "query" :"订单发货",
        "slop" : 1
      }
    }
  }
}
```

### **`match_phrase_prefix`**

类似match_phrase，但会对最后一个Token在倒排索引列表中进行`通配符搜索`

max_expansions:模糊匹配数

```
GET operation_log/_search
{
  "query" : {
    "match_phrase_prefix" : {
      "desc" : "订单已经发"
    }
  }
}
```
```
GET operation_log/_search
{
  "query" : {
    "match_phrase_prefix" : {
      "desc" : {
        "query" : "订单已经发",
        "max_expansions" : 1
      }
    }
  }
}
```

### **`multi_match`**

查询可以在多个字段上执行相同的 match 查询

```
GET operation_log/_search
{
  "query" : {
    "multi_match" : {
      "query" : "发货",
      "fields" : ["desc", "desc.ik_smart_analyzer"]
    }
  }
}
```

### **`query_string`**

允许单个查询字符串中指定 AND|OR|NOT 条件((发货) OR (提交))，和 multi_match 一样，支持多字段搜索

```
GET operation_log/_search
{
  "query" : {
    "query_string" : {
      "query" : "发货 OR 提交",
      "fields" : ["desc", "desc.ik_smart_analyzer"]
    }
  }
}
```

### **`simple_query_string`**

类似query_string，忽略错误的语法，丢弃查询的无效部分。分词("发货 AND 提交" )保留AND...

- \+ AND operation
- | OR operation
- \- NOT
- " 对检索词进行 match_phrase query
- \* at the end of a term signifies a prefix query
- ( and ) 优先级
- ~N after a word signifies edit distance (fuzziness)
- ~N after a phrase signifies slop amount

```
GET operation_log/_search
{
  "query" : {
    "simple_query_string" : {
      "query" : "发货 + 提交",
      "fields" : ["desc"],
      "default_operator" : "AND"
    }
  }
}
```

### **`match_bool_prefix`**

输入文本通过分词器处理为多个term，然后基于这些term进行bool query，除了最后一个term使用前缀查询 其它都是term query
```
GET operation_log/_search
{
  "query" : {
    "match_bool_prefix" : {
      "desc" : "已经 发"
    }
  }
}
```
类似于：
```
GET operation_log/_search
{
  "query" : {
    "bool" : {
      "should" : [
        { "term" : { "desc" : "已经"}},
        { "prefix" : { "desc" : "发"}}
      ]
    }
  }
}
```

### **`intervals`**

根据匹配项的顺序和邻近程度(proximity)返回文档

出现“订单”、“123456”，中间不包括“已经”
```
GET operation_log/_search
{
  "query" : {
    "intervals" :{
      "desc" : {
          "match" : {
          "query" : "订单 123456",
          "filter" : {
            "not_containing" : {
              "any_of" : {
                "intervals" : [
                  { "match" : { "query" : "已经" } }
                ]
              }
            }
          }
        }
      }
    }
  }
}
```

---

## **`组合查询`**

### **`bool`**

4种子句类型：
1. must 必须出现在匹配的文档中，并将增加得分
2. filter 必须匹配，子句在过滤器上下文中执行，不像must，`忽略打分，子句用于缓存`。
3. should 或出现在匹配的文档中，有最小匹配数(minimum_should_match)
4. must_not 不得出现在匹配的文档中。子句在过滤器上下文中执行，`忽略打分，子句用于缓存`。
子句只支持 Full text queries、Term-level queries、Bool query 

```
POST operation_log/_search
{
  "query" : {
    "bool" : {
      "must" : {
        "match" : { "desc" : "123456" }
      },
      "filter" : {
        "match" : { "desc" : "订单已经发货" }
      },
      "must_not" : {
        "range" : {
          "user_id" : { "gte" : 3, "lte" : 2 }
        }
      },
      "should" : [
        { "term" : { "desc" : "收取" } },
        { "term" : { "desc" : "包裹" } }
      ],
      "minimum_should_match" : 2,
      "boost" : 1.0
    }
  }
}
```

minimum_should_match：

(标记：N-应该匹配的子句数，S-子句总数，X-用户给定的参数值)

1. 正数：N = X
2. 复数：N = S - |X|
3. 百分数：N = floor(S*X)
4. 负百分：N = S - floor(|S*X|)
5. 组合：如3<90%  S <= 3，则全部都是必需；S > 3，需要90％
6. 多组合：2<-25% 9<-3<br>
   空格分隔，每个条件规范仅对大于其前一个的数字有效。

**bool.filter**
1. filter下的查询不影响得分
    ```
    POST operation_log/_search
    {
      "query": {
        "bool": {
          "filter": {
            "term": { "desc": "发货" }
          }
        }
      }
    }
    ```
2. match_all query查询得分全为1
    ```
    POST operation_log/_search
    {
      "query": {
        "bool": {
          "must": {
            "match_all": {}
          },
          "filter": {
            "term": { "desc": "订单" }
          },
          "boost": 2
        }
      }
    }
    ```
3. constant_score同第2点

1. **should 仅影响得分**：bool查询在Query context中并且bool查询具有must或filter子句，那么bool的should查询即使没有匹配到，文档也将与查询匹配。
    ```
    POST operation_log/_search
    {
      "query" : {
        "bool" : {
          "must" : {
            "bool" : {
                "must" : [
                  { "match" : { "desc" : "包裹" } }
                ],
                "should": [
                  { "term" : { "desc" : "找不到" } }
                ]
              }
            }
          }  
        }
      }
    }
    ```

2. **should 至少匹配一个**：如果bool 查询是 Filter context或 既没有must也没filter，则文档至少与一个should的查询相匹配。
    1. bool 查询是 Filter context
    2. 既没有must也没filter，should 至少匹配一个 
        ```
        POST operation_log/_search
        {
          "query" : {
            "bool" : {
              "filter" : {
                "bool" : {
                    "should": [
                      { "term" : { "desc" : "不存在" } }
                    ]
                  }
                }
              }  
            }
          }
        }
        ```

## **`聚合`**

- size：返回top size的文档
- shard_size：设置协调节点向各个分片请求的词根个数，然后在协调节点进行聚合，最后只返回size个词根给到客户端，shard_size >= size
- "missing": "缺失时的值，如果文档不包含，默认忽略"

## **`度量 Metrics`**

一组文档的统计分析

1. avg max min sum 
    ```
    POST operation_log/_search
    {
      "size" : 0,
      "aggs" : {
          "avg_log_time" : { 
            "avg" : {
              "field" : "log_time" 
              "missing": "xxx"   
            }
          }
        }
    }
    ```
2. stats 统计 count max min avg sum
    ```
    POST operation_log/_search?size=0
    {
      "aggs" : {
        "demo_stats" : {
          "stats" : {
            "field" : "user_id"
          }
        }
      }
    }
    ```
3. extended_stats 比stats多4个统计结果： 平方和、方差、标准差、平均值加/减两个标准差的区间
4. percentiles
5. percentile_ranks user_id小于2、3占百分比
    ```
    POST operation_log/_search?size=0
    {
      "aggs": {
        "user_id_rank": {
          "percentile_ranks": {
            "field": "user_id",
            "values": [
              2,
              3
            ]
          }
        }
      }
    }
    ```
6. weighted_avg 加权平均
    ```
    ...
        "weighted_avg" : {
          "value": {
            "field" : "grade"
          },
          "weight" : {
            "field" : "weight"
          }
        }
    ```
7. value_count field有值的文档数
    ```
    POST operation_log/_search?size=0
    {
      "aggs" : {
        "desc_count" : {
          "value_count" : {
            "field": "desc.raw"
          }
        }
      }
    }
    ```
8. cardinality  值去重计数
    ```
    ...
      "cardinality" : {
        "field" : "user_id"
      }
    ```

## **`桶 Bucketing`**

符合条件的文档的集合

